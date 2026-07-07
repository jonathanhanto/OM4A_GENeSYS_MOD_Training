# =====================================================================
#  Multi-objective add-on (2/2): AUGMECON driver
# =====================================================================
# Port of `genesysmod_augmecon_driver.gms` + `genesysmod_augmecon.gms`.
# Traces a Pareto frontier between total system cost `z` and the social
# resistance metric `zAcc` (built in genesysmod_acceptance.jl) using the
# augmented epsilon-constraint method (AUGMECON).
#
# Docking: `genesysmod_augmecon(...)` is a self-contained alternative entry
# point. It calls the unchanged `genesysmod_build_model(...)`, then runs the
# anchors + epsilon sweep on the SAME mutable JuMP model (no rebuild between
# points). Forward every normal `genesysmod` keyword through `kwargs...`; the
# acceptance/AUGMECON-specific options are the named keywords below.
#
#   model, out = genesysmod_augmecon(; solver = HiGHS.Optimizer, DNLPsolver = …,
#       elmod_nthhour = 484, model_region = "de", inputdir = "…", resultdir = "…",
#       acceptance_file = ".../Justice_Factor_v07.xlsx",
#       augmecon_points = 10, acc_guard_mode = 1, acc_fix_baseyear = 1,
#       acc_sensitivity = "")               # baseline frontier
#
# `out["pareto"]` is the frontier DataFrame; the same is written to
# `Results/pareto_augmecon_<run_tag>.csv`.
# =====================================================================

# ---------------------------------------------------------------------
#  Guard / lock helpers (operate on the persistent model with fix(...))
# ---------------------------------------------------------------------

"""
    acc_guard_fixable_techs(Sets, Params, accOptSector) -> Vector{String}

Technologies whose DISPATCH the guard freezes: belong to a non-opt sector
(`accOptSector == 0`) and are NOT a Storage technology (storage dispatch is left
free so the sequential storage-level balance stays feasible).
"""
function acc_guard_fixable_techs(Sets, Params, accOptSector)
  fixable = String[]
  for t ∈ Sets.Technology
    in_nonopt  = any(Params.Tags.TagTechnologyToSector[t,se] != 0 &&
                     get(accOptSector, se, 1) == 0 && se != "Storages" for se ∈ Sets.Sector)
    in_storage = any(Params.Tags.TagTechnologyToSector[t,se] != 0 &&
                     se == "Storages" for se ∈ Sets.Sector)
    (in_nonopt && !in_storage) && push!(fixable, t)
  end
  return fixable
end

"""
    acc_nonopt_techs(Sets, Params, accOptSector) -> Vector{String}

Technologies in any non-opt sector (their new capacity is frozen by the guard,
port of `FIX_NewCapacity_NonOpt`).
"""
function acc_nonopt_techs(Sets, Params, accOptSector)
  [t for t ∈ Sets.Technology if any(Params.Tags.TagTechnologyToSector[t,se] != 0 &&
                                     get(accOptSector, se, 1) == 0 for se ∈ Sets.Sector)]
end

"""
    acc_apply_baseyear_lock!(Vars, Sets, newcap_val, cutoff) -> Int

Base-year lock (`switch_fix_baseyear`): fix `NewCapacity[y,t,r]` for every
technology/region in years `y ≤ cutoff` to the Anchor-1 value. Kills the
base-year retiming artifact. Returns the number of fixed variables.
"""
function acc_apply_baseyear_lock!(Vars, Sets, newcap_val, cutoff::Integer)
  n = 0
  for y ∈ Sets.Year
    y <= cutoff || continue
    for t ∈ Sets.Technology, r ∈ Sets.Region_full
      JuMP.fix(Vars.NewCapacity[y,t,r], newcap_val[y,t,r]; force=true)
      n += 1
    end
  end
  return n
end

"""
    acc_fix_nonopt_newcap!(Vars, Sets, newcap_val, nonopt_techs) -> Int

Freeze non-opt-sector new capacity to its Anchor-1 value, across all years
(port of `FIX_NewCapacity_NonOpt`).
"""
function acc_fix_nonopt_newcap!(Vars, Sets, newcap_val, nonopt_techs)
  n = 0
  for y ∈ Sets.Year, t ∈ nonopt_techs, r ∈ Sets.Region_full
    JuMP.fix(Vars.NewCapacity[y,t,r], newcap_val[y,t,r]; force=true)
    n += 1
  end
  return n
end

"""
    acc_apply_dispatch_guard!(Vars, Sets, Maps, roa_val, fixable_techs) -> Int

Dispatch guard (`switch_guard_mode == 1`): fix `RateOfActivity` of the fixable
(non-opt, non-Storage) technologies to their exact Anchor-1 values across all
years / timeslices / regions / modes. EXACT fix, no epsilon band (the band in
the GAMS comments was tried and abandoned — it wrecked barrier numerics).
NB: this is a large number of `fix` calls (years × timeslices × techs × modes ×
regions); it runs once.
"""
function acc_apply_dispatch_guard!(Vars, Sets, Maps, roa_val, fixable_techs)
  n = 0
  for y ∈ Sets.Year, l ∈ Sets.Timeslice, r ∈ Sets.Region_full, t ∈ fixable_techs
    for m ∈ Maps.Tech_MO[t]
      JuMP.fix(Vars.RateOfActivity[y,l,t,m,r], roa_val[y,l,t,m,r]; force=true)
      n += 1
    end
  end
  return n
end

# ---------------------------------------------------------------------
#  epsilon grid + solver config + solve wrapper
# ---------------------------------------------------------------------

"""
    acc_eps_grid(zlo, zhi, K) -> Vector{Float64}

Port of the GAMS `epsGrid`: K points spanning `[zlo + 0.05·range, zhi]`, where
`range = max(1e-6, zhi - zlo)`. `k=1` sits 5 % of the range above `zlo`
(acceptance-optimal end), `k=K` is at `zhi` (cost-optimal end).
"""
function acc_eps_grid(zlo::Float64, zhi::Float64, K::Integer)
  rng = max(1e-6, zhi - zlo)
  K <= 1 && return [zlo + 0.05 * rng]
  return [zlo + 0.05 * rng + (k - 1) / (K - 1) * rng * 0.95 for k ∈ 1:K]
end

"""
    acc_configure_solver!(model, solver, threads, resultdir; crossover, solver_log, extra)

Attach and configure the optimizer for AUGMECON. Crossover defaults to ON to get
clean (vertex) Pareto solutions. Mirrors the solver block in `genesysmod_main.jl`
but with crossover configurable.
"""
function acc_configure_solver!(model, solver, threads, resultdir;
                               crossover::Bool=true, solver_log::Bool=false, extra=Dict())
  set_optimizer(model, solver)
  sn = solver_name(model)
  if sn == "Gurobi"
    set_optimizer_attribute(model, "Threads", threads)
    set_optimizer_attribute(model, "Method", 2)
    set_optimizer_attribute(model, "BarHomogeneous", 1)
    set_optimizer_attribute(model, "Crossover", crossover ? -1 : 0)
    solver_log && set_optimizer_attribute(model, "LogFile", joinpath(resultdir, "Augmecon_$(today()).log"))
  elseif sn == "CPLEX"
    set_optimizer_attribute(model, "CPX_PARAM_THREADS", threads)
    set_optimizer_attribute(model, "CPX_PARAM_PARALLELMODE", -1)
    set_optimizer_attribute(model, "CPX_PARAM_LPMETHOD", 4)
    set_optimizer_attribute(model, "CPX_PARAM_SOLUTIONTYPE", crossover ? 1 : 2)
  elseif sn == "HiGHS"
    set_optimizer_attribute(model, "solver", "ipm")
    set_optimizer_attribute(model, "run_crossover", crossover ? "on" : "off")
    solver_log && set_optimizer_attribute(model, "log_file", joinpath(resultdir, "Augmecon_$(today()).log"))
  end
  for (k, v) ∈ extra
    try
      set_optimizer_attribute(model, k, v)
    catch e
      @warn "AUGMECON: could not set solver attribute $k = $v ($e)"
    end
  end
  return model
end

"""
    acc_solve!(model, label; crossover=true) -> termination status

Solve and, if the result is neither OPTIMAL nor LOCALLY_SOLVED, retry once with a more
robust configuration: crossover OFF + NumericFocus=3. On the degenerate AUGMECON points
(the dispatch guard fixes a huge number of variables) Gurobi's crossover can hit numerical
trouble and report a spurious `INFEASIBLE` even though a looser-epsilon neighbour is
feasible; barrier-only then returns a valid interior solution. Crossover is restored to
`crossover` afterwards so the next point still aims for a clean vertex.
"""
function acc_solve!(model, label::AbstractString; crossover::Bool=true)
  is_gurobi = solver_name(model) == "Gurobi"
  # IMPORTANT: only ever change solver attributes BEFORE optimize!. Changing an attribute
  # AFTER optimize! marks the model dirty, so a later JuMP.value() throws OptimizeNotCalled.
  is_gurobi && set_optimizer_attribute(model, "Crossover", crossover ? -1 : 0)
  optimize!(model)
  st = termination_status(model)
  if st ∉ (MOI.OPTIMAL, MOI.LOCALLY_SOLVED) && is_gurobi
    @warn "AUGMECON $label: $st — retrying barrier-only (Crossover=0, NumericFocus=3)"
    set_optimizer_attribute(model, "Crossover", 0)
    set_optimizer_attribute(model, "NumericFocus", 3)
    optimize!(model)
    st = termination_status(model)
  end
  st ∉ (MOI.OPTIMAL, MOI.LOCALLY_SOLVED) && @warn "AUGMECON $label: termination_status = $st (expected OPTIMAL)"
  return st
end

"""
    acc_write_results!(model, case, elapsed, extr_str)

Write the full GENeSYS-MOD model results for the CURRENT (already-solved) model state,
tagged with `extr_str` so each Pareto point gets its own set of files. Computes the
post-solve `Variable_Parameters`, then calls the unchanged result writers:
- `genesysmod_results` → processed output_* CSVs (capacity, production, emissions,
  trade, costs, …); internally gated by `switch_processed_results == 1`.
- `genesysmod_results_raw` → raw per-variable CSVs; dispatched on `switch_raw_results`
  (`NoRawResult` = skipped, the default).
Wrapped in try/catch so a results failure on one point never aborts the frontier sweep.
"""
function acc_write_results!(model, case, elapsed, extr_str::AbstractString)
  Sets, Params, Vars, Maps = case["Sets"], case["Params"], case["Vars"], case["Maps"]
  switch, Settings = case["Switch"], case["Settings"]
  try
    VarPar = genesysmod_variable_parameter(model, Sets, Params, Vars, Maps)
    genesysmod_results(model, Sets, Params, VarPar, Vars, switch, Settings, Maps, elapsed, extr_str)
    genesysmod_results_raw(model, VarPar, Params, Sets, switch, extr_str, switch.switch_raw_results)
    println("AUGMECON: wrote model results for '$extr_str'")
  catch e
    @warn "AUGMECON: writing results for '$extr_str' failed ($e)"
  end
  return nothing
end

# ---------------------------------------------------------------------
#  Driver
# ---------------------------------------------------------------------

"""
    genesysmod_augmecon(; solver, DNLPsolver, <genesysmod kwargs…>,
                          augmecon_points = 10, acc_guard_mode = 1,
                          acc_fix_baseyear = 1, acc_sensitivity = "",
                          acceptance_file = "…", run_tag = "augmecon", …)

Bi-objective AUGMECON entry point. Builds the model once, solves the two
anchors (min cost, min resistance), applies the dispatch-guard + base-year lock,
then sweeps an epsilon grid producing a cost-vs-resistance Pareto frontier.

Returns `(model, out)` where `out["pareto"]` is the frontier `DataFrame` (also
written to `Results/pareto_augmecon_<run_tag>.csv`) and `out` additionally holds
`zStar`, `zAccAtCost`, `zAccMin`, `wacc`, `grid`, the `AcceptanceData`, and the
build `case`.

Acceptance/AUGMECON keywords:
- `augmecon_points`        number of Pareto points K (GAMS `augmecon_points`)
- `acc_sector_select`      1 ⇒ restrict zAcc to `acc_opt_sectors` (Power+Resources)
- `acc_opt_sectors`        sectors that enter zAcc when `acc_sector_select==1`
- `acc_guard_mode`         1 ⇒ freeze non-opt dispatch + new capacity to Anchor-1
- `acc_fix_baseyear`       1 ⇒ lock base-year (`y ≤ acc_baseyear_cutoff`) new capacity
- `acc_baseyear_cutoff`    last exempt/locked year (default 2020)
- `acc_sensitivity`        ""/"wind_plus10"/"h2boiler_low"/"h2boiler_mean"/"wind_plus10_h2boiler_low"
- `acceptance_file`        path to the Justice_Factor workbook (the data seam)
- `acceptance_sheet` / `powerlines_sheet` / `power_fuel` / `invert_powerlines`
- `mean_acceptance`        missing-cell fill (default 63.2)
- `acc_crossover`          crossover for the LP solves (default true)
- `run_tag`                suffix of the output CSV
All other keywords are forwarded verbatim to `genesysmod_build_model`.
"""
function genesysmod_augmecon(; solver, DNLPsolver=nothing, threads::Integer=4,
    augmecon_points::Integer=10,
    acc_sector_select::Integer=1,
    acc_opt_sectors=["Power","Resources"],
    acc_guard_mode::Integer=1,
    acc_fix_baseyear::Integer=1,
    acc_baseyear_cutoff::Integer=2020,
    acc_sensitivity::String="",
    acceptance_file::Union{Nothing,String}=nothing,
    acceptance_sheet::String="Par_Acceptance_Factor_final",
    powerlines_sheet::Union{Nothing,String}="Par_Acceptance_Powerlines_final",
    power_fuel::String="Power",
    mean_acceptance::Float64=63.2,
    invert_powerlines::Bool=false,
    wind_pattern::AbstractString="Wind_Onshore",
    h2boiler_pattern::AbstractString="H2_Boiler",
    acc_crossover::Bool=true,
    write_point_results::Bool=true,
    run_tag::String="augmecon",
    solver_log::Bool=false,
    solver_attr=Dict(),
    kwargs...)

  starttime = Dates.now()

  # ---- 1. Build the model ONCE (unchanged single-objective build) ----
  model, case = genesysmod_build_model(; solver=solver, DNLPsolver=DNLPsolver, threads=threads, kwargs...)
  Sets   = case["Sets"]
  Params = case["Params"]
  Vars   = case["Vars"]
  Maps   = case["Maps"]
  switch = case["Switch"]
  resultdir = switch.resultdir[]

  # Capture the cost objective expression BEFORE we ever swap @objective.
  zexpr = JuMP.objective_function(model)

  # ---- 2. Configure the solver (crossover ON for clean Pareto vertices) ----
  acc_configure_solver!(model, solver, threads, resultdir;
                        crossover=acc_crossover, solver_log=solver_log, extra=solver_attr)

  # ---- 3. Acceptance data + sector bookkeeping (data-layout seam) ----
  ad = acc_load_data(Sets;
        acceptance_file=acceptance_file, acceptance_sheet=acceptance_sheet,
        powerlines_sheet=powerlines_sheet, power_fuel=power_fuel, mean_acceptance=mean_acceptance,
        sector_select=acc_sector_select, opt_sectors=acc_opt_sectors, sensitivity=acc_sensitivity,
        invert_powerlines=invert_powerlines, wind_pattern=wind_pattern, h2boiler_pattern=h2boiler_pattern)
  techs_by_sector = acc_techs_by_sector(Sets, Params)
  accOptSector = ad.accOptSector

  # ===================== ANCHOR 1 : min cost =====================
  @objective(model, MOI.MIN_SENSE, zexpr)
  println("AUGMECON: solving Anchor 1 (min cost) …")
  # Anchor 1 with CROSSOVER (user decision 2026-07-05): a clean vertex for the guard fix-values.
  # NB the CAES-vs-Battery/H2-storage mix difference vs GAMS is NOT solver degeneracy: GAMS's
  # storage formulation has two defects (dead E2P coupling — StorageUpperLimit bound but never used;
  # S5b y-index bug giving 7× free storage headroom) that make bulk H2/battery storage near-free
  # there; Julia's corrected constraints price that out, so the feasible sets genuinely differ
  # (audit 2026-07-06, GAMS_COMPARISON). Crossover's dual-push can thrash on this model, so pass a
  # Gurobi TimeLimit via solver_attr in the run script: on TIME_LIMIT the acc_solve! retry below
  # falls back to barrier-only automatically instead of hanging forever.
  acc_solve!(model, "Anchor 1"; crossover=true)
  if !JuMP.has_values(model)
    error("AUGMECON: Anchor 1 (min cost) returned no solution — cannot build the frontier.")
  end
  zStar = JuMP.objective_value(model)

  # Reference quantities from the Anchor-1 solution (read all .l values now,
  # before any further solve overwrites them).
  tca_val    = JuMP.value.(Vars.TotalCapacityAnnual)
  newcap_val = JuMP.value.(Vars.NewCapacity)
  roa_val    = acc_guard_mode == 1 ? JuMP.value.(Vars.RateOfActivity) : nothing
  # Model-period import totals from the FREE Anchor-1 solution, for the FIX_*Import guard below.
  # MUST be read here: any JuMP.fix() later (base-year lock / dispatch guard) marks the model
  # dirty and a subsequent JuMP.value() throws OptimizeNotCalled.
  import_refs = Dict{Tuple{String,String},Float64}()
  if acc_guard_mode == 1
    for (t, f) ∈ [("Z_Import_H2","H2"), ("Z_Import_Gas","Gas_Natural"),
                  ("Z_Import_Hardcoal","Hardcoal"), ("Z_Import_LNG","LNG"), ("Z_Import_Oil","Oil")]
      (t ∈ Sets.Technology && f ∈ Sets.Fuel && (t, f) ∈ Maps.Set_Tech_FuelOut) || continue
      import_refs[(t, f)] = sum(JuMP.value(Vars.ProductionByTechnologyAnnual[y, t, f, r])
                                for y ∈ Sets.Year, r ∈ Sets.Region_full)
    end
  end

  # wAccSector from Anchor-1 stock → zAcc expression → zAccAtCost on the
  # still-current Anchor-1 solution (matches the GAMS recompute, not zAcc.l).
  wacc = acc_compute_wacc(tca_val, techs_by_sector, ad.SectorAcceptanceWeight, Sets)
  zAccExpr = acc_build_zacc_expr(Vars, Sets, Maps, ad, wacc, techs_by_sector;
                                 baseyear_cutoff=acc_baseyear_cutoff)
  zAccAtCost = JuMP.value(zAccExpr)
  println("AUGMECON: zStar = $(round(zStar; digits=2)), zAccAtCost = $(round(zAccAtCost; digits=4))")
  # cost-optimal anchor: full model results (the unconstrained min-cost energy system)
  write_point_results && acc_write_results!(model, case, Dates.now() - starttime, "$(run_tag)_costopt")
  write_point_results && acc_write_decomposition!(Vars, Sets, Maps, ad, wacc, techs_by_sector, switch,
      "$(run_tag)_costopt"; baseyear_cutoff=acc_baseyear_cutoff, z_value=zStar, zacc_value=zAccAtCost)

  # Anchor-only mode: augmecon_points=0 stops after the FREE cost-opt anchor (resolution
  # tests etc.) — no base-year lock, no guard, no Anchor 2, no epsilon sweep.
  if augmecon_points <= 0
    println("AUGMECON: augmecon_points=$(augmecon_points) — cost-opt anchor only, done.")
    println("AUGMECON: total time $(round(Dates.value(Dates.now()-starttime)/1000; digits=1)) s")
    return model, Dict("case" => case, "pareto" => DataFrame(),
                       "zStar" => zStar, "zAccAtCost" => zAccAtCost, "zAccMin" => NaN,
                       "wacc" => wacc, "grid" => Float64[], "AcceptanceData" => ad)
  end

  # ---- 4. Scope the trade-off: base-year lock + dispatch/capacity guard ----
  if acc_fix_baseyear == 1
    nb = acc_apply_baseyear_lock!(Vars, Sets, newcap_val, acc_baseyear_cutoff)
    println("AUGMECON: base-year lock fixed $nb NewCapacity vars (y ≤ $acc_baseyear_cutoff)")
  end
  if acc_guard_mode == 1
    fixable = acc_guard_fixable_techs(Sets, Params, accOptSector)
    nd = acc_apply_dispatch_guard!(Vars, Sets, Maps, roa_val, fixable)
    nonopt = acc_nonopt_techs(Sets, Params, accOptSector)
    nc = acc_fix_nonopt_newcap!(Vars, Sets, newcap_val, nonopt)
    println("AUGMECON: dispatch-guard fixed $nd RateOfActivity + $nc non-opt NewCapacity vars")
    # Port of the FIX_*Import guard equalities (genesysmod_augmecon_baseline_guard.gms:99-117,
    # active with runAug/runGuard in GAMS): pin each fuel's MODEL-PERIOD import total to the value
    # this run's own FREE Anchor 1 chose (GAMS driver:169-183 captures RefTotal* the same way), so
    # acceptance points cannot buy extra imports instead of re-siting capacity. The ref values were
    # read into `import_refs` BEFORE any fix() call (value() would throw OptimizeNotCalled after).
    for ((t, f), ref) ∈ import_refs
      JuMP.@constraint(model,
        sum(Vars.ProductionByTechnologyAnnual[y, t, f, r] for y ∈ Sets.Year, r ∈ Sets.Region_full) == ref,
        base_name = "FIX_Import|$(t)")
      println("AUGMECON: FIX_Import pins $t model-period total to $(round(ref; digits=2)) PJ")
    end
  end

  # ===================== ANCHOR 2 : min zAcc =====================
  @objective(model, MOI.MIN_SENSE, zAccExpr)
  println("AUGMECON: solving Anchor 2 (min resistance) …")
  acc_solve!(model, "Anchor 2"; crossover=acc_crossover)
  if JuMP.has_values(model)
    zAccMin = JuMP.value(zAccExpr)
    println("AUGMECON: zAccMin = $(round(zAccMin; digits=4))")
    if write_point_results
      acc_write_results!(model, case, Dates.now() - starttime, "$(run_tag)_accopt")
      acc_write_decomposition!(Vars, Sets, Maps, ad, wacc, techs_by_sector, switch,
          "$(run_tag)_accopt"; baseyear_cutoff=acc_baseyear_cutoff, z_value=JuMP.value(zexpr), zacc_value=zAccMin)
    end
  else
    @warn "AUGMECON: Anchor 2 (min resistance) returned no solution — falling back to zAccMin = zAccAtCost (degenerate frontier)."
    zAccMin = zAccAtCost
  end

  # ---- 5. AUGMECON scaffold: slack + epsilon constraint + augmented objective ----
  sAcc = @variable(model, lower_bound = 0.0, base_name = "sAcc")
  accEps = @constraint(model, zAccExpr + sAcc == zAccAtCost)   # RHS set per point

  zlo = min(zAccMin, zAccAtCost)
  zhi = max(zAccMin, zAccAtCost)
  rng = max(1e-6, zhi - zlo)
  rho = 1e-6 * max(1.0, abs(zStar))
  grid = acc_eps_grid(zlo, zhi, augmecon_points)

  # augObj: minimize z − rho·(sAcc / range)  — MINUS sign rewards slack so that,
  # among cost-equal solutions, the lowest-zAcc (best acceptance) point is chosen.
  @objective(model, MOI.MIN_SENSE, zexpr - rho * (sAcc / rng))

  # ===================== epsilon sweep =====================
  rows = NamedTuple[]
  for (k, eps) ∈ enumerate(grid)
    set_normalized_rhs(accEps, eps)
    st = acc_solve!(model, "point k=$k"; crossover=acc_crossover)
    # guard: only read a solution if one exists (a point with no primal solution must not
    # abort the whole sweep — record NaN and move on)
    ok = JuMP.has_values(model)
    zv  = ok ? JuMP.value(zexpr)    : NaN
    zav = ok ? JuMP.value(zAccExpr) : NaN
    sv  = ok ? JuMP.value(sAcc)     : NaN
    push!(rows, (k=k, epsAcc=eps, z=zv, zAcc=zav, sAcc=sv,
                 status=string(st), optimal=(st == MOI.OPTIMAL)))
    println("AUGMECON: k=$k  eps=$(round(eps;digits=4))  z=$(round(zv;digits=2))  zAcc=$(round(zav;digits=4))  [$st]")
    # full model results for this Pareto point (energy system at this resistance level)
    if ok && write_point_results
      acc_write_results!(model, case, Dates.now() - starttime, "$(run_tag)_k$(k)")
      acc_write_decomposition!(Vars, Sets, Maps, ad, wacc, techs_by_sector, switch,
          "$(run_tag)_k$(k)"; baseyear_cutoff=acc_baseyear_cutoff, z_value=zv, zacc_value=zav)
    end
  end

  # ---- 6. write the Pareto CSV ----
  df = DataFrame(rows)
  outpath = joinpath(resultdir, "pareto_augmecon_$(run_tag).csv")
  CSV.write(outpath, df)
  println("AUGMECON: wrote $outpath")
  println("AUGMECON: total time $(round(Dates.value(Dates.now()-starttime)/1000; digits=1)) s")

  return model, Dict("case" => case, "pareto" => df,
                     "zStar" => zStar, "zAccAtCost" => zAccAtCost, "zAccMin" => zAccMin,
                     "wacc" => wacc, "grid" => grid, "AcceptanceData" => ad)
end
