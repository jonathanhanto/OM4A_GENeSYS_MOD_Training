# =====================================================================
#  Multi-objective add-on (1/2): Social-acceptance layer
# =====================================================================
# Self-contained extension that builds the capacity-weighted social
# RESISTANCE objective `zAcc` consumed by the bi-objective AUGMECON driver
# (genesysmod_augmecon.jl). This is a port of the GAMS files
# `genesysmod_acceptance_factor.gms` / `accObj` (in `genesysmod_equ.gms`).
#
# Design: this file adds NO fields to the core `Switch` or `Parameters`
# structs. It owns its own data container (`AcceptanceData`) and is only ever
# exercised when `genesysmod_augmecon(...)` is called — the existing single-
# objective `genesysmod(...)` path is byte-for-byte unaffected.
#
# Sign convention (read once):
#   The survey gives an ACCEPTANCE percentage (higher = more accepted). We
#   derive RESISTANCE = 100 - acceptance once, up front, and store ONLY the
#   resistance in `AcceptanceData.Resistance`. `zAcc` is total weighted
#   resistance, so MINIMIZING zAcc == MAXIMIZING acceptance. We never
#   overwrite an "acceptance" array in place with resistance values (the GAMS
#   source did, which is what flipped the sensitivity overrides — see
#   `acc_apply_sensitivity!`, which therefore runs BEFORE inversion).
# =====================================================================

"""
    AcceptanceData

Everything the acceptance objective `zAcc` needs. Built once, before the first
solve, by [`acc_load_data`](@ref).

- `Resistance::DenseAxisArray` `[r,t,y]` — social resistance (`100 - acceptance`,
  missing filled with `mean_acceptance`) for generation / resources technologies.
- `ResistancePowerLines::Dict{Tuple{String,String,Int},Float64}` keyed `(r,rr,y)`
  — per transmission-line resistance for the `power_fuel` trade term.
- `accOptSector::Dict{String,Int}` — sector => {0,1}; only sectors flagged `1`
  contribute to `zAcc`.
- `SectorAcceptanceWeight::Dict{String,Float64}` — per-sector numerator weight
  (GAMS `SectorAcceptanceWeight`, default `1.0`).
- `power_fuel::String` — fuel name used for electricity trade (default `"Power"`).
- `mean_acceptance::Float64` — fill value for missing survey cells (default `63.2`).
"""
struct AcceptanceData
  Resistance ::JuMP.Containers.DenseAxisArray
  ResistancePowerLines ::Dict{Tuple{String,String,Int},Float64}
  accOptSector ::Dict{String,Int}
  SectorAcceptanceWeight ::Dict{String,Float64}
  power_fuel ::String
  mean_acceptance ::Float64
end

# ---------------------------------------------------------------------
#  Sector helpers
# ---------------------------------------------------------------------

"""
    acc_techs_by_sector(Sets, Params) -> Dict{String,Vector{String}}

Technologies belonging to each sector (`TagTechnologyToSector != 0`). Mirrors
the `techs_by_sector` helper already built in `genesysmod_equ.jl`.
"""
function acc_techs_by_sector(Sets, Params)
  Dict(se => [t for t ∈ Sets.Technology if Params.Tags.TagTechnologyToSector[t,se] != 0]
       for se ∈ Sets.Sector)
end

"""
    acc_build_optsector(Sets; sector_select=1, opt_sectors=["Power","Resources"])

Port of the GAMS `accOptSector` selection in `genesysmod_augmecon_driver.gms`.
Default: all sectors 1, Transportation 0; if `sector_select == 1` then exactly
`opt_sectors` (Power + Resources) are 1 and everything else 0.
"""
function acc_build_optsector(Sets; sector_select::Integer=1,
                             opt_sectors=["Power","Resources"])
  d = Dict{String,Int}(se => 1 for se ∈ Sets.Sector)
  haskey(d, "Transportation") && (d["Transportation"] = 0)
  if sector_select == 1
    for se ∈ Sets.Sector
      d[se] = (se ∈ opt_sectors) ? 1 : 0
    end
  end
  return d
end

# ---------------------------------------------------------------------
#  Resistance inversion & sensitivity (both operate on the ACCEPTANCE scale)
# ---------------------------------------------------------------------

"""
    acc_apply_sensitivity!(A, Sets, scenario; wind_pattern, h2boiler_pattern)

Apply a named sensitivity override to the raw ACCEPTANCE array `A[r,t,y]`,
**before** inversion (so the direction is unambiguous: `wind_plus10` literally
raises acceptance by 10 pp). This is the [PORT BETTER] fix for the GAMS
sign bug, where overrides ran after the in-place inversion and so moved
resistance the wrong way.

Scenarios (technology match by substring, configurable):
- `"wind_plus10"`            : wind-onshore acceptance + 10 pp
- `"h2boiler_low"`           : H2 boiler acceptance = 45
- `"h2boiler_mean"`          : H2 boiler acceptance = `meanAcceptance` (63.2)
- `"wind_plus10_h2boiler_low"`: both
- `""`                       : baseline, no change
"""
function acc_apply_sensitivity!(A, Sets, scenario::AbstractString;
                                wind_pattern::AbstractString="Wind_Onshore",
                                h2boiler_pattern::AbstractString="H2_Boiler",
                                h2boiler_mean::Float64=63.2)
  scenario == "" && return A
  wind_techs = [t for t ∈ Sets.Technology if occursin(wind_pattern, t)]
  h2_techs   = [t for t ∈ Sets.Technology if occursin(h2boiler_pattern, t)]

  bump_wind!(Δ) = for r ∈ Sets.Region_full, t ∈ wind_techs, y ∈ Sets.Year
    A[r,t,y] = min(100.0, A[r,t,y] + Δ)
  end
  set_h2!(v) = for r ∈ Sets.Region_full, t ∈ h2_techs, y ∈ Sets.Year
    A[r,t,y] = v
  end

  if scenario == "wind_plus10"
    isempty(wind_techs) && @warn "acc sensitivity '$scenario': no tech matched '$wind_pattern'"
    bump_wind!(10.0)
  elseif scenario == "h2boiler_low"
    isempty(h2_techs) && @warn "acc sensitivity '$scenario': no tech matched '$h2boiler_pattern'"
    set_h2!(45.0)
  elseif scenario == "h2boiler_mean"
    set_h2!(h2boiler_mean)
  elseif scenario == "wind_plus10_h2boiler_low"
    bump_wind!(10.0); set_h2!(45.0)
  else
    @warn "Unknown acceptance sensitivity scenario '$scenario' — ignoring (baseline)."
  end
  return A
end

"""
    acc_invert_to_resistance!(A; mean_acceptance=63.2) -> A

In-place port of the two GAMS lines that turn ACCEPTANCE into RESISTANCE:

    A(r,t,y)\$(A == 0) = meanAcceptance        # fill missing
    A(r,t,y)\$(A  > 0) = 100 - A               # invert

After this, `A` holds resistance. Order matters: a just-filled `meanAcceptance`
must also be inverted (→ `100 - meanAcceptance`).
"""
function acc_invert_to_resistance!(A::JuMP.Containers.DenseAxisArray; mean_acceptance::Float64=63.2)
  d = A.data
  @inbounds for i ∈ eachindex(d)
    d[i] == 0.0 && (d[i] = mean_acceptance)
    d[i] = 100.0 - d[i]
  end
  return A
end

# ---------------------------------------------------------------------
#  Normalisation weight wAccSector (computed once from the Anchor-1 solution)
# ---------------------------------------------------------------------

"""
    acc_compute_wacc(tca_val, techs_by_sector, SectorAcceptanceWeight, Sets)
        -> Dict{Tuple{String,Int},Float64}

Port of `wAccSector(se,y) = SectorAcceptanceWeight(se) / RefTotalCapYearSector(se,y)`
where `RefTotalCapYearSector(se,y) = sum_{r,t∈se} TotalCapacityAnnual.l(y,t,r)` is
taken from the **Anchor-1 (cost-optimal) solution** and then held constant.
`tca_val` is `value.(Vars.TotalCapacityAnnual)` after the Anchor-1 solve.
"""
function acc_compute_wacc(tca_val, techs_by_sector, SectorAcceptanceWeight::Dict, Sets)
  wacc = Dict{Tuple{String,Int},Float64}()
  for (se, ts) ∈ techs_by_sector, y ∈ Sets.Year
    tot = 0.0
    for t ∈ ts, r ∈ Sets.Region_full
      tot += tca_val[y,t,r]
    end
    wacc[(se,y)] = tot > 0 ? get(SectorAcceptanceWeight, se, 1.0) / tot : 0.0
  end
  return wacc
end

# ---------------------------------------------------------------------
#  zAcc objective expression
# ---------------------------------------------------------------------

"""
    acc_build_zacc_expr(Vars, Sets, Maps, ad, wacc, techs_by_sector; baseyear_cutoff=2020)
        -> JuMP.AffExpr

Build `zAcc` directly as an affine expression over the decision variables
`NewCapacity` and `NewTradeCapacity` ([PORT BETTER]: no intermediate
`Acceptance` variables/equations). Port of the GAMS `accObj`:

    zAcc = Σ_{r,y>cut, se:accOpt=1, t∈se}  NewCapacity[y,t,r]·Resistance[r,t,y]·wAcc[se,y]
         + Σ_{r,rr,y>cut}                  (NewTradeCapacity[y,pf,r,rr] + …[rr,r])·Resistance_PL[r,rr,y]·wAcc[Power,y]
"""
function acc_build_zacc_expr(Vars, Sets, Maps, ad::AcceptanceData, wacc::Dict,
                             techs_by_sector::Dict; baseyear_cutoff::Int=2020)
  𝓡 = Sets.Region_full
  𝓨 = Sets.Year
  expr = JuMP.AffExpr(0.0)

  # --- generation / resources term ---
  for (se, optflag) ∈ ad.accOptSector
    optflag == 1 || continue
    haskey(techs_by_sector, se) || continue
    for t ∈ techs_by_sector[se], r ∈ 𝓡, y ∈ 𝓨
      y > baseyear_cutoff || continue
      w = get(wacc, (se,y), 0.0)
      w == 0.0 && continue
      res = ad.Resistance[r,t,y]
      res == 0.0 && continue
      JuMP.add_to_expression!(expr, res * w, Vars.NewCapacity[y,t,r])
    end
  end

  # --- transmission (power-lines) term ---
  if get(ad.accOptSector, "Power", 0) == 1
    pf = ad.power_fuel
    for ((r, rr, y), res) ∈ ad.ResistancePowerLines
      y > baseyear_cutoff || continue
      res == 0.0 && continue
      w = get(wacc, ("Power", y), 0.0)
      w == 0.0 && continue
      if (pf, r, rr) ∈ Maps.Set_Fuel_Regions
        JuMP.add_to_expression!(expr, res * w, Vars.NewTradeCapacity[y, pf, r, rr])
      end
      if (pf, rr, r) ∈ Maps.Set_Fuel_Regions
        JuMP.add_to_expression!(expr, res * w, Vars.NewTradeCapacity[y, pf, rr, r])
      end
    end
  end
  return expr
end

# ---------------------------------------------------------------------
#  Acceptance / resistance decomposition output (per AUGMECON point)
# ---------------------------------------------------------------------

"""
    acc_write_decomposition!(Vars, Sets, Maps, ad, wacc, techs_by_sector, switch, extr_str;
                             baseyear_cutoff=2020, z_value=NaN, zacc_value=NaN)

Write the acceptance/resistance decomposition for the CURRENT solved model, mirroring
the GAMS Acceptance result tables (which the base Julia results pipeline does not port).
Reconstructs each `zAcc` term from `acc_build_zacc_expr` on the solved variable values.
Three CSVs, tagged with `extr_str` exactly like the other per-point result files:

- `AcceptanceByTech_…`  — per (Region, Sector, Technology, Year) the new capacity, its
  `Resistance` (= 100 − acceptance), the GAMS-unweighted `Acceptance = NewCapacity·Resistance`,
  the sector weight `wAccSector`, and the weighted `zAccContribution = Resistance·wAccSector·
  NewCapacity` that actually enters `zAcc`. Only the technologies that enter `zAcc`
  (opt sectors, y>cutoff) appear — i.e. "which techs cause how much resistance".
- `AcceptancePowerlines_…` — same for the transmission (power-line) term.
- `AcceptanceSummary_…` — per-region and total aggregates (TotalAcceptance, TotalNewCapacity,
  AverageResistance = capacity-weighted mean, zAccContribution) plus the `z` and `zAcc`
  objective values (the GAMS `output_z`).

Wrapped in try/catch so a failure never aborts the frontier sweep.
"""
function acc_write_decomposition!(Vars, Sets, Maps, ad::AcceptanceData, wacc::Dict,
        techs_by_sector::Dict, switch, extr_str::AbstractString;
        baseyear_cutoff::Int=2020, z_value=NaN, zacc_value=NaN)
  try
    𝓡, 𝓨 = Sets.Region_full, Sets.Year

    # ---- Block A: generation / resources, term-for-term as acc_build_zacc_expr ----
    gen = DataFrame(Region=String[], Sector=String[], Technology=String[], Year=Int[],
                    NewCapacity=Float64[], Resistance=Float64[], Acceptance=Float64[],
                    wAccSector=Float64[], zAccContribution=Float64[])
    for (se, optflag) ∈ ad.accOptSector
      optflag == 1 || continue
      haskey(techs_by_sector, se) || continue
      for t ∈ techs_by_sector[se], r ∈ 𝓡, y ∈ 𝓨
        y > baseyear_cutoff || continue
        w = get(wacc, (se,y), 0.0); w == 0.0 && continue
        res = ad.Resistance[r,t,y]; res == 0.0 && continue
        cap = JuMP.value(Vars.NewCapacity[y,t,r]); cap == 0.0 && continue
        push!(gen, (r, se, t, y, cap, res, cap*res, w, res*w*cap))
      end
    end

    # ---- Block B: transmission (power-lines), term-for-term ----
    pl = DataFrame(Region=String[], Region2=String[], Year=Int[],
                   NewTradeCapacity=Float64[], Resistance=Float64[], Acceptance=Float64[],
                   wAccSector=Float64[], zAccContribution=Float64[])
    if get(ad.accOptSector, "Power", 0) == 1
      pf = ad.power_fuel
      for ((r, rr, y), res) ∈ ad.ResistancePowerLines
        y > baseyear_cutoff || continue
        res == 0.0 && continue
        w = get(wacc, ("Power", y), 0.0); w == 0.0 && continue
        cap = 0.0
        (pf, r, rr) ∈ Maps.Set_Fuel_Regions && (cap += JuMP.value(Vars.NewTradeCapacity[y, pf, r, rr]))
        (pf, rr, r) ∈ Maps.Set_Fuel_Regions && (cap += JuMP.value(Vars.NewTradeCapacity[y, pf, rr, r]))
        cap == 0.0 && continue
        push!(pl, (r, rr, y, cap, res, cap*res, w, res*w*cap))
      end
    end

    # ---- Summary: per (region, year) + per-year totals, then z / zAcc (output_z) ----
    agg = Dict{Tuple{String,Int},NTuple{3,Float64}}()   # (r,y) -> (acceptance, capacity, zAccContrib)
    addagg!(r, y, a, c, z) = (p = get(agg, (r,y), (0.0,0.0,0.0)); agg[(r,y)] = (p[1]+a, p[2]+c, p[3]+z))
    for row ∈ eachrow(gen); addagg!(row.Region, row.Year, row.Acceptance, row.NewCapacity, row.zAccContribution); end
    for row ∈ eachrow(pl);  addagg!(row.Region, row.Year, row.Acceptance, row.NewTradeCapacity, row.zAccContribution); end

    summ = DataFrame(Region=String[], Year=String[], Type=String[], Value=Float64[])
    yeartot = Dict{Int,NTuple{3,Float64}}()
    for ((r,y),(a,c,z)) ∈ sort(collect(agg))
      push!(summ, (r, string(y), "TotalAcceptance", a))
      push!(summ, (r, string(y), "TotalNewCapacity", c))
      push!(summ, (r, string(y), "AverageResistance", c > 0 ? a/c : 0.0))
      push!(summ, (r, string(y), "zAccContribution", z))
      p = get(yeartot, y, (0.0,0.0,0.0)); yeartot[y] = (p[1]+a, p[2]+c, p[3]+z)
    end
    for (y,(a,c,z)) ∈ sort(collect(yeartot))
      push!(summ, ("Total", string(y), "TotalAcceptance", a))
      push!(summ, ("Total", string(y), "TotalNewCapacity", c))
      push!(summ, ("Total", string(y), "AverageResistance", c > 0 ? a/c : 0.0))
      push!(summ, ("Total", string(y), "zAccContribution", z))
    end
    push!(summ, ("All", "All", "z_system_costs", Float64(z_value)))
    push!(summ, ("All", "All", "zAcc_acceptance_objective", Float64(zacc_value)))

    rd  = switch.resultdir[]
    tag = "$(switch.model_region)_$(switch.emissionPathway)_$(switch.emissionScenario)_$(extr_str)"
    CSV.write(joinpath(rd, "AcceptanceByTech_$(tag).csv"), gen)
    CSV.write(joinpath(rd, "AcceptancePowerlines_$(tag).csv"), pl)
    CSV.write(joinpath(rd, "AcceptanceSummary_$(tag).csv"), summ)
    println("AUGMECON: wrote acceptance decomposition for '$extr_str' ($(nrow(gen)) tech rows, $(nrow(pl)) line rows)")
  catch e
    @warn "AUGMECON: writing acceptance decomposition for '$extr_str' failed ($e)"
  end
  return nothing
end

# ---------------------------------------------------------------------
#  Data ingestion  ── THE SEAM ──
# ---------------------------------------------------------------------
# This is the single part of the add-on that is coupled to the input-data
# layout. The default reads the wide Justice_Factor workbook (years across
# columns: Region | Technology | 2018 … 2050 | … ). If your run folder instead
# ships long-format `Par_AcceptanceFactor` sheets inside the main
# RegularParameters workbook, replace `acc_read_wide`/`acc_read_powerlines`
# with a `create_daa(...)` call — nothing else in the add-on changes.

_acc_as_year(h::Integer) = Int(h)
_acc_as_year(h::Real)    = isinteger(h) ? Int(h) : nothing
_acc_as_year(h::AbstractString) = tryparse(Int, strip(h))
_acc_as_year(::Any) = nothing

"""
    acc_read_wide(path, sheet, 𝓡, 𝓣, 𝓨) -> DenseAxisArray[r,t,y]

Read a wide-format acceptance sheet (key columns Region, Technology in cols 1-2;
one column per model year) into a `[r,t,y]` array of RAW acceptance (not yet
inverted). Rows whose region/technology are outside the model sets are dropped.
"""
function acc_read_wide(path::String, sheet::String, 𝓡, 𝓣, 𝓨)
  xf = XLSX.readxlsx(path)
  sheet ∈ XLSX.sheetnames(xf) || error("acc_read_wide: sheet '$sheet' not found in $path")
  mat = xf[sheet][:]
  header = mat[1, :]
  ycol = Dict{Int,Int}()
  for (ci, h) ∈ enumerate(header)
    yy = _acc_as_year(h)
    (yy !== nothing && yy ∈ 𝓨) && (ycol[yy] = ci)
  end
  isempty(ycol) && @warn "acc_read_wide: no year columns in '$sheet' matched model years $𝓨"
  A = JuMP.Containers.DenseAxisArray(zeros(length(𝓡), length(𝓣), length(𝓨)), 𝓡, 𝓣, 𝓨)
  rset = Set(𝓡); tset = Set(𝓣)
  for ri ∈ 2:size(mat, 1)
    r = mat[ri, 1]; t = mat[ri, 2]
    (r isa AbstractString && t isa AbstractString) || continue
    (r ∈ rset && t ∈ tset) || continue
    for (y, ci) ∈ ycol
      v = mat[ri, ci]
      v isa Number && (A[r, t, y] = Float64(v))
    end
  end
  return A
end

"""
    acc_read_powerlines(path, sheet, 𝓡, 𝓨; invert=false)
        -> Dict{Tuple{String,String,Int},Float64}

Read the wide power-lines sheet (Region | Region2 | Fuel | years…) into a
`(r,rr,y) => value` dict. By default the value is used RAW (the GAMS source
does not invert the power-lines factor); set `invert=true` to apply the
`100 - x` resistance inversion for consistency with the generation factor.
"""
function acc_read_powerlines(path::String, sheet::String, 𝓡, 𝓨;
                             invert::Bool=false)
  xf = XLSX.readxlsx(path)
  sheet ∈ XLSX.sheetnames(xf) || error("acc_read_powerlines: sheet '$sheet' not found in $path")
  mat = xf[sheet][:]
  header = mat[1, :]
  ycol = Dict{Int,Int}()
  for (ci, h) ∈ enumerate(header)
    yy = _acc_as_year(h)
    (yy !== nothing && yy ∈ 𝓨) && (ycol[yy] = ci)
  end
  rset = Set(𝓡)
  d = Dict{Tuple{String,String,Int},Float64}()
  for ri ∈ 2:size(mat, 1)
    r = mat[ri, 1]; rr = mat[ri, 2]
    (r isa AbstractString && rr isa AbstractString) || continue
    (r ∈ rset && rr ∈ rset) || continue
    for (y, ci) ∈ ycol
      v = mat[ri, ci]
      v isa Number || continue
      val = Float64(v)
      invert && (val = 100.0 - val)
      d[(r, rr, y)] = val
    end
  end
  return d
end

"""
    acc_load_data(Sets; kwargs...) -> AcceptanceData

Build the full [`AcceptanceData`](@ref): read raw acceptance, apply the
sensitivity override (acceptance scale), invert to resistance, read the
power-lines factor, and build `accOptSector` / `SectorAcceptanceWeight`.
`wAccSector` is NOT computed here — it depends on the Anchor-1 solution and is
filled later via [`acc_compute_wacc`](@ref).
"""
function acc_load_data(Sets;
    acceptance_file::Union{Nothing,String}=nothing,
    acceptance_sheet::String="Par_Acceptance_Factor_final",
    powerlines_sheet::Union{Nothing,String}="Par_Acceptance_Powerlines_final",
    power_fuel::String="Power",
    mean_acceptance::Float64=63.2,
    sector_select::Integer=1,
    opt_sectors=["Power","Resources"],
    sensitivity::String="",
    invert_powerlines::Bool=false,
    wind_pattern::AbstractString="Wind_Onshore",
    h2boiler_pattern::AbstractString="H2_Boiler")

  𝓡 = Sets.Region_full; 𝓣 = Sets.Technology; 𝓨 = Sets.Year

  acceptance_file === nothing && error(
    "acc_load_data: no `acceptance_file` provided. Acceptance-data ingestion is " *
    "the one part of the multi-objective add-on that must be wired to the run-folder " *
    "input. Pass the Justice_Factor workbook path (wide layout) or adapt acc_read_wide " *
    "to your RegularParameters layout.")

  acc = acc_read_wide(acceptance_file, acceptance_sheet, 𝓡, 𝓣, 𝓨)   # raw acceptance
  acc_apply_sensitivity!(acc, Sets, sensitivity;
                         wind_pattern=wind_pattern, h2boiler_pattern=h2boiler_pattern,
                         h2boiler_mean=mean_acceptance)
  acc_invert_to_resistance!(acc; mean_acceptance=mean_acceptance)     # now resistance

  plines = Dict{Tuple{String,String,Int},Float64}()
  if powerlines_sheet !== nothing
    plines = acc_read_powerlines(acceptance_file, powerlines_sheet, 𝓡, 𝓨;
                                 invert=invert_powerlines)
  end

  optsec = acc_build_optsector(Sets; sector_select=sector_select, opt_sectors=opt_sectors)
  saw = Dict{String,Float64}(se => 1.0 for se ∈ Sets.Sector)

  return AcceptanceData(acc, plines, optsec, saw, power_fuel, mean_acceptance)
end
