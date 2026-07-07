# GENeSYS-MOD.jl — Multi-Objective (Acceptance) Port — Working Log

> Living document: the GAMS→Julia port of the bi-objective (cost `z` vs. social
> acceptance/resistance `zAcc`) AUGMECON method + the DE data pipeline.
> **Read §0 first for a new-session handoff.** Last updated: **2026-07-06** (run 12, potential caps).

---

## 0. Status (start here)

**Where it stands:** port VALIDATED. The DE acceptance frontier reproduces GAMS in shape and level
after the CO₂-penalty data fix + peaking parity + FIX_Import guard + realistic potential caps
(latest = run 12, 2026-07-06, §6.1). nth=484/K=10 numbers:

| Metric | Julia (run 12) | GAMS ref |
|---|---|---|
| cost-opt `z` | **2.2808e6 (99.9 % of GAMS)** | 2.2832e6 |
| **CO₂ 2050** | **0.0 Mt (exact match)** | 0 |
| total trade-off cost-opt→acc-opt | **+2.26 %** | **+2.13 %** |
| zAcc range | 57.5–64.0 | 52.9–64.1 |
| slope | 0.366 %/unit | 0.201 (bug-shaped, see §7) |
| base-year slack | **0** (hard) | 0 |

**The headline trade-off (+2.26 % vs +2.13 %) now matches GAMS.** Julia's zAcc range is narrower and
the per-unit slope steeper because GAMS's acceptance end escapes into its two storage bugs (dead E2P +
S5b, §8 2026-07-06b) — Julia is the corrected reference. Realistic caps (P_CSP≈0, D_CAES 1 GW DE_NI)
closed the last two loopholes the user spotted; the acceptance end now correctly re-sites into
PV_Rooftop (most accepted tech, 89–99 GW new).

**Root causes fixed this session** (all DATA except the two clear value/guard port bugs):
- **CO₂ penalty reached only 1/16 regions** — `Par_EmissionsPenalty`/`…TagTech` stored under `DE_BY`,
  GAMS inherits from `data_base_region=DE_BY`, Julia from `World` → 15 regions unpenalised → dirty
  industry. **Fixed data-only** (relabel DE_BY→World). See GAMS_COMPARISON §5. **THE big lever.**
- D_SCS_H2 phantom H2 (data), biomass free-trade (data), hard BYB=1 (config), PhaseIn value (settings).

**All fixes are in place and validated** (§5): D_SCS_H2 phantom-H2 (data), biomass
free-trade (data), hard `base_year_bounds=1` (config), and the **PhaseIn port bug**
(code, `genesysmod_settings.jl`). Config to run is in §3.

**What's still open:** see **§7** (ranked) — mostly housekeeping (converter in scratchpad,
diagnostics) + deferred port items (`CA3b` `*AvailabilityFactor`; `TagTradeMonoDirectional`).
Next phase = the scenario/sensitivity program (memory `acceptance-scenario-proposals`): knee
analysis, wind_plus10 (+GAMS validation), acceptance-value screening, grid-vs-generation,
outsourcing (FIX_Import on/off), sector scope.

---

## 1. Goal

Port **only the multi-objective aspects** of the GAMS model in `DE_Acceptance_2026/`
into the Julia model (`MultObj_Julia/`). The Julia cost model stays untouched except for
genuine port bugs; the acceptance layer **docks on as an option**. Reference target
(GAMS paper, DE): cost-opt `z ≈ 2,283,198`, acc-opt `zAcc ≈ 53.44`, trade-off ≈ **+2.13 %**.

Method: **AUGMECON** (augmented ε-constraint).
- anchors: min `z`, min `zAcc`
- ε-grid over `zAcc`; constraint `zAcc + sAcc == epsAcc`
- augmented objective `zAug == z − rho·(sAcc/rangeAcc)` (the **minus** sign is load-bearing)
- dispatch guard + base-year lock so non-opt sectors stay frozen across the frontier

---

## 2. Code added (the dockable layer)

All in `MultObj_Julia/src/`, included + exported from `GENeSYSMOD.jl`:

| File | Role |
|---|---|
| `genesysmod_acceptance.jl` | `AcceptanceData` struct; reads Justice resistance/powerline data; builds the `zAcc` affine expression over `NewCapacity` + `NewTradeCapacity` (only `y > acc_baseyear_cutoff`); resistance = `100 − acceptance` with mean-fill. Also `acc_write_decomposition!` (GAMS Acceptance tables). |
| `genesysmod_augmecon.jl` | `genesysmod_augmecon(...)` driver: forwards kwargs to `genesysmod_build_model`, computes anchors, ε-grid, k-loop, writes `pareto_augmecon_*.csv` + full `output_*` per point. `acc_configure_solver!` sets Gurobi (Method=2 barrier, BarHomogeneous=1, Crossover). Anchor 1 is always crossover (clean guard vertex). |
| `genesysmod_scenariodata_de.jl` | DE policy constraints (module `ScenarioDataDe`, auto-dispatched for `model_region="de"`). See Changelog 2026-07-01. |
| `GENeSYSMOD.jl` | adds the `include`s + `export genesysmod_augmecon`. |

The cost model files are unchanged **except** the correctness fixes in §5.

---

## 3. How to run (DE acceptance frontier)

- Run script: `MultObj_Julia_Development_2026/Run_Model_Acceptance.jl`.
- Env: `AUG_K=10 AUG_NTH=484 AUG_CROSSOVER=0 julia --project=<MultObj_Julia> Run_Model_Acceptance.jl`
  (`AUG_K=3 AUG_NTH=2920` for a ~10 min smoke test).
- Solver: **Gurobi** (barrier). Sweep points barrier-only (`AUG_CROSSOVER=0`); anchors crossover.
- **Current validated config** (in the run script):
  - `model_region="de"`, `data_base_region="World"`,
    `data_file="input_Germany_H2_v25_julia"` (biomass-fixed, D_SCS_H2-tagged),
    `hourly_data_file="input_timeseries_DE_v04_nim_18-06-2024"`,
    `emissionPathway="GradualDevelopment"`, `emissionScenario="globalLimit"`.
  - **`switch_base_year_bounds=1`, `switch_base_year_bounds_debugging=0`** (HARD calibration; feasible after the PhaseIn fix — §5.4).
  - `switch_hydrogen_blending_share=0`, `switch_ccs=0`,
    `switch_endogenous_specifieddemandforecasting=0`, `switch_errorcheck=1`.
  - `solver_attr = Dict("NumericFocus"=>2, "DualReductions"=>0)`.
  - AUGMECON: `augmecon_points=K`, `acc_guard_mode=1`, `acc_fix_baseyear=1`, `acc_baseyear_cutoff=2020`.
- Resolution via `elmod_nthhour` (484 = fine/paper, 2920 = coarse for quick checks).
- **Debugging infeasibility:** run once with `switch_iis=1` (Gurobi) — the IIS is the fastest
  localizer (see [[iis-first-for-infeasibility]]; it cracked the PhaseIn bug in one step). For a
  Julia-vs-GAMS mismatch, read GAMS's actual solution from a result GDX with
  `/c/GAMS/36/gdxdump FILE symb=SYM format=csv` before hypothesizing.

---

## 4. Data pipeline GAMS-DE → Julia

Converter: **scratchpad** `convert_de_to_julia.py` (still not in the data repo — see §7).
Source (user-maintained): `Inputdata/input_Germany_H2_v25_joh_02_03_2026.xlsx`
→ output `input_Germany_H2_v25_julia.xlsx` (+ `Justice_Factor_v07_julia.xlsx`).

### 4.1 Data differences the converter handles

**A — Tech/Fuel rename** (`REN` map, ~30 names) — touches every tech/fuel-indexed sheet:

| old (GAMS) | new (Julia code-expected) |
|---|---|
| `RES_PV_Utility_*` / `RES_Wind_*` | `P_PV_Utility_*` / `P_Wind_*` |
| `RES_PV_Rooftop_*` | `P_PV_Rooftop_*` |
| `RES_CSP` | `P_CSP` |
| `RES_Hydro_Large` / `_Small` | `P_Hydro_Reservoir` / `P_Hydro_RoR` |
| `RES_Biogas/Grass/Wood/…` | `R_Biogas/R_Grass/R_Wood/…` |
| `Heat_Low_Residential` | `Heat_Buildings` |
| `Heat_Medium_Industrial` | `Heat_MediumHigh_Industrial` |

Reason: connects PV/Wind/Rooftop/CSP to the hardcoded `keys_mapping`/`capf_list` in the
timeseries reduction → real CapacityFactor profiles from hourly data.

**B — Added sheets / changed defaults / port-bug workarounds (data-side):**

| Parameter | Change | Why |
|---|---|---|
| `AvailabilityFactor` | World-AF=1 for every tech lacking a row | GAMS default 1.0; Julia `create_daa` default 0 → can't produce |
| `AnnualMaxNewCapacity` | added | 999999 = no limit |
| `TagModalTypeToModalGroups`, `TagCanFuelBeTraded` | added (from testdata, DE subset) | real |
| `TagTech/FuelToSubsets` | flat → long-format + placeholders | real + 0 placeholders |
| `Par_TradeCostFactor` | **derived** from `Par_TradeCosts/Par_TradeRoute` | §5.2 |
| `Par_TagTechnologyToSubsets` | adds `(D_SCS_H2, StorageDummies, 1)` | §5.3 — else phantom H2 |
| `Par_TradeCapacityGrowthCosts` | **drops** all `Biomass` rows | §5.3 — else base-year biomass infeasible |
| `SpecifiedDemandDevelopment`, `AnnualMinNewCapacity`, `DistrictHeatDemand/Split`, `NewCapacityExpansionStop` | added empty | 0 |

**C — Run switches** (config, not data): `switch_base_year_bounds=1`/`debugging=0`,
`switch_hydrogen_blending_share=0`, `switch_endogenous_specifieddemandforecasting=0`,
`switch_ccs=0`.

### 4.2 Clarifications
- **CapacityFactor**: `Par_CapacityFactor` sheet is **not read** (`genesysmod_dataload.jl:377-378`
  commented → default `ones(1.0)`), then overwritten by the hourly timeseries reduction for
  `capf_list` techs. Rooftop-PV/CSP get a solar profile via `bounds.jl:357-368` (not CF=1).
- **ResidualCapacity**: **real DE data** (renamed only); the `derive_residual.jl` hack is disabled.

---

## 5. Key fixes

### 5.1 `genesysmod_bounds.jl` base-year construction — the original showstopper
The Julia port wrongly fixed base-year `NewCapacity=0` for CHP **and Transport** and dropped
GAMS's re-allowances. GAMS (`bounds.gms:135-159`) fixes only
`Transformation/PowerSupply/SectorCoupling/StorageDummies` and re-allows CHP/HHI_*/boilers/
`CHP_Biomass_Solid`. Aligned Julia to GAMS → DE model feasible on real data.

### 5.2 Trade costs — factor derived in the DATA (2026-06-26)
Julia never reads `Par_TradeCosts`; it builds `TradeCosts = TradeCostFactor·TradeRoute` from
`Par_TradeCostFactor`. The converter back-derives `factor[f] = mean_routes(TradeCosts/TradeRoute)`
(exactly constant per fuel for 14/15; `Power` mean-fit) and writes the sheet. **Trade no longer
free.** Data-only, code unchanged (the principle: data fits Julia, not code fits GAMS).

### 5.3 `D_SCS_H2` phantom H2 + biomass base-year trade (2026-07-02, data-side)
- **`D_SCS_H2`** is the charge/discharge dummy of the H2 cavern storage `S_SCS_H2`. GAMS declares
  `TechnologyTo/FromStorage` over the full tech set and leaves `D_SCS_H2` untagged; **Julia reads
  those sheets over the `StorageDummies` axis** (`dataload.jl:442-443`) and `create_daa`
  (`utils.jl:138`) silently drops rows outside it. The converted workbook mirrored the GAMS tag
  sheet → no tag → all 14 linkage rows dropped → `D_SCS_H2` in no storage constraint → **mode 2
  became a free H2 source** (28,451 PJ phantom H2; 2050: 3,744 PJ). **Fix:** converter derives the
  `StorageDummies` tag for `D_SCS_H2`. Verified gone; electrolysis returns (§6.1).
- **Biomass base-year trade:** GAMS `TrC2a` (`equ.gms:333`) lets biomass build trade capacity in
  the start year (`+ NewTradeCapacity$(sameas(f,'Biomass'))`); Julia's `TrC2a` (`equ.jl:494`) omits
  it and fixes `NewTradeCapacity=0` in 2018. With empty `Par_TradeCapacity` biomass, 2018 biomass
  trade froze at 0 → biomass-poor city-states (DE_BE/HB/HH/SL) couldn't import → base-year biomass
  floors infeasible. **Fix (data):** drop biomass from `Par_TradeCapacityGrowthCosts` → no `TrC7`
  cap → biomass trades freely, which is Julia's own documented convention (`dispatch.jl:365`).

### 5.4 `base_year_bounds=1` + the PhaseIn port bug — THE recent root cause (2026-07-03)
`switch_base_year_bounds=1` activates BYB1/BYB2 (`equ.jl:1325-1347`): pins 2018
`ProductionByTechnologyAnnual` into `[0.965·RBP, RBP]` per `(r,t,f)` with nonzero
`RegionalBaseYearProduction`. GAMS ran it by default; Julia's `=0` was a bring-up relic. It
calibrates the 2018 production MIX (not capacity). Enabling it exposed the biomass bug (5.3) and,
after that, a residual 12.77 PJ short on two floors (DE_BB/DE_ST onshore).

**A hard-mode IIS localized it in one step** (7 constraints, purely intertemporal — no trade):
`BYB1[2018] → SC3_SmoothingRenewableIntegration[2025] → SC3[2030] → CA5[2030] × TCC1[2030]`.
`SC3` forces `Prod[y] ≥ Prod[y-1]·PhaseIn[y]·(demand[y]/demand[y-1])`, so the 2018 floor propagates
forward; the DE_ST onshore 2030 capacity cap (`TotalAnnualMaxCapacity` = 2.4667 GW → `Prod ≤ 16.40`)
could not carry what Julia's PhaseIn demanded (`≥ 17.94`) → infeasible.

**Root cause: `PhaseIn` in `genesysmod_settings.jl` did not match GAMS.** Julia had `0.8` flat for
2030–2045; GAMS `genesysmod_settings.gms` has `2030=.7, 2035=.7, 2040=.7, 2045=.6, 2050=.5`.
Confirmed from the GAMS result GDX (DE_ST onshore 2018=30, 2025=23.69, **2030=16.405** — exactly at
the cap — with **zero** BaseYearBounds slack). **Fix: corrected Julia PhaseIn to the GAMS values**
(genuine port bug → code fix, the allowed exception to the data-first principle). Test (nth=484,
hard BYB=1): BYB1 slack 0.0, BYB2 slack 0.0, OPTIMAL. So `debugging=0` (hard) — no elastic slack,
no 9999 penalty, no z-offset, no RBP trimming.

> Detour honesty: the earlier "12.77 PJ = data over-specification / GAMS rides the same slack"
> reasoning was WRONG (never verified against GAMS). Hours were also spent on AvailabilityFactor,
> storage, and the trade network — all refuted. The IIS + the GAMS GDX should have been step 1.

---

## 6. Results

### 6.1 Authoritative frontier — nth=484, K=10, run 12 "realistic potential caps" (2026-07-06)
`pareto_augmecon_de_k10_nth484.csv` — ALL fixes active (CO₂-penalty data fix, peaking parity,
FIX_*Import guard, P_CSP/D_CAES potential caps). All 10 points **OPTIMAL** (crossover Anchor 1,
TimeLimit-5400 fallback), 87 min.

| k | zAcc | z | | k | zAcc | z |
|---|---|---|---|---|---|---|
| 1 (acc-opt) | 57.80 | 2.33231e6 | | 6 | 61.23 | 2.28370e6 |
| 2 | 58.49 | 2.30177e6 | | 7 | 61.92 | 2.28213e6 |
| 3 | 59.17 | 2.29380e6 | | 8 | 62.61 | 2.28118e6 |
| 4 | 59.86 | 2.28884e6 | | 9 | 63.29 | 2.28081e6 |
| 5 | 60.55 | 2.28584e6 | | 10 (cost-opt) | 63.96 | 2.28077e6 |

`zStar=2.28077e6`, `zAccAtCost=63.98`, `zAccMin=57.47`. Monotone. **z cost-opt = 99.9 % of GAMS
2.2832e6. CO₂ 2050 = 0 Mt (match). Total trade-off cost-opt→acc-opt = +2.26 % (GAMS paper +2.13 %) —
the headline number now matches.** Slope 0.366 %/unit vs GAMS 0.201 / range 57.5–64.0 vs 52.9–64.1:
Julia's range is narrower/steeper because GAMS's acceptance end re-sites into its two storage bugs
(dead E2P + S5b, changelog 2026-07-06b) — GAMS's flat slope is bug-shaped; Julia is the corrected
reference. Frontier shape: k10→k8 is near-free (−1.37 resistance for +0.02 % z), knee at ~k2–k3,
k2→k1 costs +1.33 %.

Mix checks (why this run is the plausible one): D_CAES 98.4→**1.0 GW** (cap, DE_NI = Huntorf),
P_CSP 34.4 GW phantom→**0**; the freed storage role is NOT taken by batteries but by OCGT/H2 flex +
trade. NB `D_Battery_Li-Ion` DOES exist in the dataset (full parameters, uncapped — an earlier note
here claimed otherwise; `output_capacity` just omits zero rows). It builds 0 because at nth=484
(18 slices à ~480 h) intraday cycling is invisible: E2P=3 h shifts 3 GWh/GW between ~480-h blocks —
worthless. Bulk energy was CAES's job (0.5 €/kWh storage vs Li-Ion ~75 €/kWh); after the cap
D_Battery_Redox (E2P=42.7 h) takes a 1.0 GW niche in 2045 and the rest goes to flex. GAMS's 85 GW
battery exists only via its S5b/E2P storage bugs. Expect Li-Ion to build at finer time resolution.
Acceptance end now builds
**P_PV_Rooftop_Residential 89–99 GW** (the most-accepted power tech, ~88) — previously crowded out
by the phantom CSP; the §7 "rooftop area-supply empty" suspicion is REFUTED (it builds fine).

Config note: `Run_Model_Acceptance.jl` = hard BYB=1, 5 GAMS peaking kwargs, `AUG_CROSSOVER=0`
(k-points barrier), Anchor 1 crossover=true; workbook = emission-fix + potential-caps
(`.prepotentialcaps` backup).

### 6.2 Earlier frontiers (superseded, for reference)
- **07-06b, FIX_Import, no potential caps:** z 2.2769e6 (99.7 %), zAcc 56.7–65.4, slope 0.562 —
  but cost end rode 98 GW uncapped D_CAES, acc end 34 GW phantom P_CSP (user-spotted, both data holes).
- **07-03, pre-peaking/pre-FIX_Import:** z 2.2274e6 (97.6 %), zAcc 49.6–68.0, slope 0.313
  (LOCALLY_SOLVED barrier points; import-dodging open).
- **07-01, nth=484, BYB=0, D_SCS_H2 bug present:** zAcc 39.2–60.2, z 1.520–1.609e6 (67 % of GAMS).
- **06-26, nth=484, free-trade/old config:** slope 0.203 (matched GAMS) but z 1.438e6, zAcc 30–44.
  NB that slope matched by coincidence of a different (buggy) configuration; §6.1 is authoritative.

### 6.3 Per-point output files
The driver writes, per Pareto point + both anchors (`switch_processed_results=1`): the 11
`output_*` energy-system CSVs, plus the ported acceptance decomposition (`acc_write_decomposition!`):
`AcceptanceByTech_…` (per tech: NewCapacity, Resistance, wAccSector, zAccContribution),
`AcceptancePowerlines_…`, `AcceptanceSummary_…` (+ the `z`/`zAcc` output_z rows).

---

## 7. Open problems (remaining Julia-vs-GAMS differences)

The big blockers are fixed. This is the decomposition of the **residual 16 % z-gap (358k MEUR),
the Power-capacity gap (394 vs 638 GW), and the steeper slope (0.312 vs 0.201)**.
**→ The VERIFIED, high-confidence side-by-side (with primary GDX/CSV/code evidence and corrections
to the medium-confidence first pass) is `GAMS_COMPARISON.md` — read that first; this §7 is the
narrative.** Note the first pass REFUTED three of its own guesses (see GAMS_COMPARISON §6): the CO₂
price is identical (not lower), the H₂-tech data is identical (not missing), and **Reserve Margin is
OFF in GAMS too** — so `switch_reserve=1` is NOT a fix (item 3 below is struck).

### 7.1 Where the gap sits
- **z-gap = 358k MEUR.** GAMS z = Operating 70.5 % + Capital 22.8 % + Emission-penalty 10.9 % −
  Salvage. Split: **26 % (92.8k) = missing-tech capital** — techs GAMS builds and Julia builds ~0:
  `CHP_Hydrogen_FuelCell` (33.7k) + `X_Fuel_Cell` (29.5k) = the **H2 re-electrification fleet**
  (63.2k), plus `PV_Rooftop_Residential`, `HLR_Heatpump_Geo_Deep`, H2/methane storage. **74 % (265k)
  = Julia reaches a genuinely lower-cost, lower-buildout optimum** on shared techs (≈103k less capital
  from ~950 GW less new build; lower CO2-penalty exposure — though Julia's physical emissions are
  HIGHER, 117 vs 0 Mt). Julia is NOT mis-accounting; it decarbonises less and builds less.
- **Power capacity gap 244 GW = 83 % PV, 11 % onshore, 6 % gas** (offshore is bound-limited both
  sides, not the gap). Two causes: **(A, dominant ~300 GW) demand-pull** — Julia has ~1525 PJ less
  electricity demand because the H2-utilization fleet and industrial/heat electrification are absent
  (electrolysis 395 vs 1337 PJ), so it rationally builds less; **(B) supply-side under-credit** —
  Reserve Margin OFF, Peaking weaker, CA3b AF omission let Julia meet demand with less firm capacity.
- **Slope steeper = mostly a BUG.** Primary driver: **`RE3_RETargetPath` never generates in Julia**
  (item 2). Without the RE monotonicity ratchet, the acc-opt end freely sheds renewables to cut
  wind/PV resistance → large zAcc swing per unit cost → steeper slope. GAMS's RE3 pins that end.

### 7.2 Ranked open problems

1. **[RESOLVED 2026-07-03 · data] Industry didn't decarbonise → dirty steel, no H2 demand.**
   ROOT CAUSE: the CO₂ penalty (`Par_EmissionsPenalty`/`…TagTech`) was stored under `DE_BY` and only
   reached DE_BY in Julia (World-inheritance), leaving 15/16 regions unpenalised. **Fixed data-only**
   (DE_BY→World): CO₂ 117→0 Mt, z 84.3%→97.6% of GAMS, steel switches to clean Scrap_EAF. See §0 +
   GAMS_COMPARISON §5. The "H2-utilization fleet absent" symptom below was downstream of this; recheck
   after a full frontier rerun whether the residual Power-capacity gap (462 vs 638) needs the H2 fleet
   (net-zero-route difference) — likely minor.

   ~~Original framing (superseded):~~ **[was HIGH · data] H2-utilization fleet builds ZERO in Julia.**
   `CHP_Hydrogen_FuelCell`, `X_Fuel_Cell`, `D_Gas_H2`, `HLR/HLI_H2_Boiler`, `HHI_H2_DRI`, `HMI_H2`
   all build/produce 0 (they EXIST in the tech set — they appear in EB2 — but are never selected).
   Removes ~1191 PJ H2 offtake, ~942 PJ electrolysis + ~493 PJ industry-elec demand, and blocks
   net-zero (117 vs 0 Mt). GAMS invests 80 GW `CHP_Hydrogen_FuelCell` + 80 GW `D_Gas_H2` + 168 GW
   electrolysis. **Why Julia doesn't build them is the key unknown** — likely the emission
   constraint not biting as hard (117 Mt residual) so no push to expensive H2 re-electrification, or
   a cost/efficiency/availability data difference. *Next:* check whether non-power sectors
   (industry/buildings) are emission-constrained like GAMS; compare `CapitalCost`/`InputActivityRatio`
   /`AvailabilityFactor` for these H2 techs GAMS↔Julia. Feeds items 5, 6, 9.
2. **[TRIED + REVERTED 2026-07-05 · julia-code] RE1/RE3 guard bug — real, but does NOT move the slope.**
   `equ.jl` wrapped the WHOLE RE1/RE2/RE3 block in `if REMinProductionTarget>0` (empty sheet, 0 in
   GAMS too). Since **RE1 defines `TotalREProductionAnnual`**, that variable was FREE — making RE3
   dead AND the **DE 80 % power-RE / 50 % heat-RE mandates** (`scenariodata_de.jl:284,343`)
   **toothless**. The fix (RE1 unconditional for RE-fuels, RE3 own guard) was applied and run:
   full frontier nth=484 → mandates bite (83 % power RE) but **slope 0.313→0.317 (unchanged), z/CO₂
   unchanged**. Per the user's criterion ("keep only if it brings the result closer to GAMS") it was
   **reverted** — the DE mandates are left toothless (documented). **The slope gap (Julia 0.31 vs
   GAMS 0.20) is NOT in the RE constraints — it is in the `zAcc` acceptance formulation** (Julia's
   zAcc range 49.7–67.9 is WIDER than GAMS 52.9–64.1: a level/scale difference from the resistance
   inversion baseline / `mean_acceptance=63.2` mean-fill / `wAccSector` weighting in
   `genesysmod_acceptance.jl`). That is the real remaining slope item (see §7.2 item 5 / §6.3).
3. ~~**[Reserve Margin OFF → switch_reserve=1]**~~ **STRUCK / REFUTED by verification.** GAMS zeroes
   `ReserveMargin` in `scenariodata_de.gms:135` and its RM3 generates 0 rows — RM is dead on BOTH
   sides. Enabling `switch_reserve=1` would make Julia *stricter* than GAMS. Do NOT do this.

   **[HIGH · investigate] NEW #1 — the dirty-steel / emission-penalty crux.** Julia keeps
   `HHI_BF_BOF` (50 Mt) + `HMI_HardCoal` (27 Mt) although the clean substitute `HHI_Scrap_EAF` is
   CHEAPER (capex 184 vs 442, MaxCap 999999 both) at the IDENTICAL 722 EUR/t penalty. A cost-min
   would never do this ⇒ either the penalty is not actually charged to these industry techs in
   Julia's objective (accounting/tag bug), or a hidden constraint forces the dirty route. Data +
   penalty already ruled out (byte-identical). This likely drives most of the residual gap AND the
   missing H₂ demand. *Next:* inspect solved `DiscountedTechnologyEmissionsPenalty` /
   `AnnualTechnologyEmission` / `EmissionActivityRatio`+`EmissionPenaltyTagTech` routing on
   `HHI_BF_BOF` in the built Julia model (GAMS_COMPARISON §5).
4. **[MEDIUM · settings] Peaking (PC3/PC4) weaker via 4 switch-default mismatches** — GAMS
   minrun=1/with_trade=0/with_storages=0/startyear=2025/min_thermal=0.5; Julia defaults
   0/1/1/2030/0.25. Plus Julia's PC4 guard (`equ.jl:1391`) drops GAMS's CHP branch (`equ.gms:832`).
   *Fix:* pass GAMS-matching peaking switches; port the PC4 CHP branch.
5. **[MEDIUM · data] `PV_Rooftop_Residential` builds ZERO (−90 GW PV)** — its area-supply tech
   `A_Rooftop_Residential` produces 0 PJ (only `A_Rooftop_Commercial` supplies area). Tech + costs
   exist (`bounds.jl:163,367`); it's a missing residential-rooftop-AREA supply in the data. *Fix:*
   populate `A_Rooftop_Residential` availability/area-supply in the converter/data.
6. **[MEDIUM · data] Industry/heat decarbonisation stalls** — Julia keeps coal steel
   (`HHI_BF_BOF` 288 PJ/50 Mt), hardcoal medium-heat (`HMI_HardCoal` 202 PJ/27 Mt), fossil buildings
   boilers where GAMS goes EAF/H2/heat-pump (~77 Mt of the 117 Mt residual). Heat TOTALS match <1 %,
   so it's the abatement-tech MIX. Partly downstream of item 1 (no H2-DRI/boilers). *Fix:* after
   item 1, check EAF + `HLR_Heatpump_Geo_Deep` cost/availability bounds vs GAMS.
7. **[MEDIUM · julia-code] `CA3b`/`CA3a` omit `*AvailabilityFactor`** (`equ.jl:363/347` vs
   `equ.gms:266/258`). Over-credits activity per GW → less capacity needed. Tested: doesn't change
   the base-year slack, but widens the capacity gap and is a real port bug. *Fix:* add
   `*AvailabilityFactor(r,t,y)` to the CA3b RHS; needs a DE+Europe+MiddleEarth regression.
8. **[MEDIUM · julia-code] `SC4` phase-in growth limit is per-region in Julia, region-POOLED in GAMS**
   (`equ.jl:694-697` inside the r-loop vs `equ.gms:447-448` indexed `(y,f)` summed over t,r). Tighter
   RE ramp across 18 DE regions → throttles RE, steepens slope (secondary to RE3). *Fix:* re-index
   SC4a to `(y,f)` summing over t and r. Do after item 2.
9. **[LOW · data] Storage tech selection diverges** — GAMS 228 GW (Battery-Li-Ion 85 + Gas_H2 80 +
   Gas_Methane 43) vs Julia 91 GW (mostly `D_CAES` 85). Gas_H2/Gas_Methane storage need H2 → mostly
   resolves with item 1; separately check Battery-Li-Ion cost/bound data.
10. **[LOW · data] `TagTradeMonoDirectional` not ported** (`equ.gms:280` skips EB1 for offshore hubs;
    zero matches in Julia). 2050-only in GAMS's solution, 0 in base year. *Fix:* guard the EB1 loop
    (`equ.jl:406-410`) with `r ∉ ["DE_Nord","DE_Baltic"]`.
11. **[LOW · data] Verify hardcoded settings vs GAMS** (PhaseIn was one such bug): dump
    `Par_ProductionGrowthLimit` (GAMS hardcodes Power/Heat/Transport 0.05, Air 0.025);
    `StorageLevelYearStart` (GAMS 0.75); `set_symmetric_transmission` (0.9 vs GAMS 0.85). Fix in data
    /config if different.

### 7.2b Input-data completeness (audited 2026-07-03, high confidence — see GAMS_COMPARISON §6b)
The DE Julia workbook is **complete**: all 13 “missing” + 16 “empty” sheets are empty/absent in GAMS
too (employment module off, storage/emission/min params guarded-off both sides, CapacityFactor from
the Timeseries file). The critical **discount rate matches (0.05 both) — z is not skewed**. The only
behavioural defect is the RE3 code guard (item 2), a port bug not a data gap. **Two NEW storage
run-switch mismatches** (config, GAMS-parity): `set_storagelevelstart_down` 0.25→**0.75**,
`E2P_ratio_deviation_factor` 2→**3**. Minor: check `ProductionGrowthLimit` fuel-taxonomy coverage.

### 7.2c Visualization convention (user request 2026-07-06)
**Every generated visualization carries its generation DATE** as a footer stamp in the image
(`generated YYYY-MM-DD`, bottom-right). Implemented in all 6 viz scripts (scratchpad:
`visualize.py`, `polar_acceptance.py`, `polar_regions.py`, `polar_tech.py`, `polar_capacity.py`,
`heatmap_acceptance.py` — each stamps `_STAMP = date.today()` before `savefig`). Keep this when the
scripts move to a maintained location; any NEW viz script must include the same stamp. Filenames stay
stable (`1_…_nth484.png` etc.) so references don't break — the date lives inside the image.

### 7.3 Housekeeping
- **Converter still in scratchpad** (`convert_de_to_julia.py`) → move to `GENeSYS_MOD.data`; preserve
  the 3 data fixes (TradeCostFactor, D_SCS_H2 tag, biomass growth-cost drop).
- **Diagnostic hardening**: `create_daa` warn-on-skipped-rows; errorcheck #13 flag storages with
  zero links both directions / linkage-sheet tech missing the StorageDummies tag (the D_SCS_H2 bug
  produced 28,451 PJ phantom H2 with no warning).

### 7.4 Suggested order of attack (post-verification)
1. **Dirty-steel / emission-penalty crux** (§7.2 NEW #1) — the load-bearing question; resolve first,
   as it likely explains most of the gap + the whole H2-demand chain. Read the solved Julia industry
   emission-penalty accounting.
2. **RE3** (item 2, one guard change → flattens slope) — cheap, high-value, independent.
3. **Peaking** switches + PC4 CHP branch (item 4).
4. **CA3b AF + SC4 pooling** (items 7–8, port fixes with a DE+Europe+MiddleEarth regression).
5. Data items (PV rooftop-residential, `set_symmetric_transmission` 0.9→0.85, StorageLevelStart).

Do NOT enable `switch_reserve=1` (refuted). Each fix is independently testable via a cost-min
nth=2920 smoke run before a full nth=484 frontier. Verified numbers/evidence: `GAMS_COMPARISON.md`.

---

## 8. Changelog
- **2026-07-06c** — **Realistic potential caps (run 12) — new authoritative frontier (§6.1).** User
  spotted two implausible results: storage = ONLY D_CAES (98.4 GW; real DE ≈ 0.3 GW Huntorf) and
  P_CSP appearing at k1 (34.4 GW; no DNI in DE — PV-copied acceptance 74.0 + PV-proxy CF + NO
  `Par_TotalAnnualMaxCapacity` row = phantom PV). Both are missing-cap DATA holes (every PV_Utility
  variant is regionally capped; P_CSP/D_CAES were not). **Fix data-only:** P_CSP=0.0001 everywhere,
  D_CAES DE_NI=1.0 / others 0.0001 (0.0001 not 0 — bounds.jl:122 converts 0→999999 = unlimited);
  workbook backup `.prepotentialcaps.xlsx`; converter `_potential_cap_override()`. **Result: all 10
  OPTIMAL, 87 min. z cost-opt 2.28077e6 = 99.9 % of GAMS (was 99.7 — honest storage costs move z
  TOWARD GAMS), total trade-off +2.26 % vs GAMS +2.13 %, zAcc 57.5–64.0, slope 0.562→0.366.**
  Acc-end re-sites into PV_Rooftop_Residential 89–99 GW (rooftop area-supply suspicion refuted).
  Viz (dated) + Tableau merge regenerated from run 12.
- **2026-07-06b** — **FIX_*Import guard ported + storage-formulation verdict.** Investigation of the
  H2-import gap (Julia 1992 vs GAMS 676 PJ) found: (1) the GDX's 93 PJ/2050 is a HARD guard equality
  `FIX_H2Import` (baseline_guard.gms:99-117) pinning model-period imports to GAMS's own free Anchor-1
  value — **ported to genesysmod_augmecon.jl** (5 fuels, pinned to Julia's OWN Anchor 1, applied
  AFTER the free cost-opt anchor per user requirement — so acceptance points cannot dodge resistance
  via imports). NB: refs must be read BEFORE any `fix()` call (OptimizeNotCalled trap). (2) The
  import price is byte-identical (4+ decimals) — no Julia bug; Julia's anchor is 0.27 % CHEAPER.
  (3) **Storage verdict: GAMS, not Julia, has two storage defects** — its E2P coupling is dead code
  (`StorageUpperLimit` bound but used nowhere) and S5b has a y-index bug giving 7× free storage
  headroom (GDX-verified: S_Gas_H2 level 588.5 = 7×84.1 new). That makes bulk H2/battery storage
  near-free in GAMS → domestic electrolysis + 80 GW D_Gas_H2 + Battery; Julia's CORRECT constraints
  price that out → imports + CAES. GAMS's mix is INFEASIBLE in Julia's formulation — not solver
  degeneracy. Julia kept as-is (corrected reference). Also fixed: S_CAES daily-reset 24h→48h
  (GAMS bounds.gms:107) + added S_Heat_HLR/S_Heat_HLI to the reset list (DE names; they never reset).
  **Frontier with FIX_Import (nth=484/K=10, 3.7 h): zAcc range 56.7–65.4 (was 49.7–65.2; GAMS
  52.9–64.1 — import-dodging closed, range now GAMS-like), z cost-opt unchanged 99.7 %. Slope
  0.562 %/unit (GAMS 0.201): STEEPER — see §7 note: GAMS's flat slope is plausibly bug-shaped
  (its acceptance end re-sites into bug-cheap free storage; Julia pays true re-siting costs).**
- **2026-07-06** — **Peaking GAMS-parity + crossover anchors: z now 99.7 % of GAMS.** Audit found the
  H2-fleet divergence was the PEAKING regime, not missing H2 data/targets (only ONE H2 target exists
  in GAMS — Osterpaket 10 GW electrolysis 2030 — and BOTH models hit exactly 10.000 GW; post-2030 H2
  targets do not exist; H2 data 100 % parity). 5 peaking defaults differed (with_storages/with_trade/
  minrun/min_thermal/startyear); GAMS's regime (storage+trade don't count toward peak, 50 % thermal,
  minrun, from 2025) forces the fuel-cell fleet. **Fix = run-config only** (5 kwargs in
  Run_Model_Acceptance.jl). Also: D_CAES double sector tag (Storages+Transportation, inherited from
  GAMS source, reporting-only) removed from workbook+converter; Anchor 1 back on CROSSOVER with a
  TimeLimit-5400 fallback (run kwargs) — and with peaking active the crossover no longer thrashes.
  **Result (nth=484/K=10): all 10 OPTIMAL (clean vertices), 80 min. z cost-opt 2.2769e6 = 99.7 % of
  GAMS; CO₂ 0; CHP_Hydrogen_FuelCell 0→87.7 GW (GAMS 80.2); zAcc range 49.7–65.2 (GAMS 52.9–64.1,
  upper end now matches).** Residual: electrolysis 11.6 vs 97.4 GW (Julia imports H2 — 620 PJ — where
  GAMS produces domestically; why GAMS's import stays at 93 PJ is the open question), X_Fuel_Cell 0
  vs 31, Battery 0 vs 85 with CAES 95 persisting (audit's flagged secondary suspect: S7a/S7b storage
  E2P block), Power 466 vs 638 (largely downstream of electrolysis demand + rooftop-residential PV),
  slope 0.334 vs 0.201.
- **2026-07-03** — **Full nth=484/K=10 frontier with ALL fixes**, hard BYB=1, all 10 OPTIMAL, 88 min
  (§6.1). z-gap to GAMS 67 %→**84.3 %**; H2 sector matches GAMS (electrolysis 1101 PJ); base year
  hard (zero slack). Slope steepened to 0.312 (§7 item 2). **Root-caused the residual 12.77 PJ to the
  `PhaseIn` port bug** via a hard-mode IIS (§5.4); corrected `genesysmod_settings.jl`; reverted all
  workarounds (RBP trim, barrier-only Anchor 1, elastic debugging). Also found 2 side port bugs
  (§7 items 3–4).
- **2026-07-02** — Enabled `base_year_bounds=1`; fixed the D_SCS_H2 phantom-H2 (converter tag) and
  biomass base-year trade (converter drops biomass growth costs) — §5.3. *(NB: this day's intermediate
  conclusion that the residual 12.77 PJ was "data over-specification / GAMS rides a slack" and that the
  CA3b AF omission "keeps Julia correct" was WRONG — both superseded by §5.4 on 07-03: it was the
  PhaseIn port bug, and CA3b AF is a real if low-impact port bug.)*
- **2026-07-01** — Ported the 3 heat-sector constraints into `genesysmod_scenariodata_de.jl`
  (HeatREProduction 50 % RES, BuildingsInertia renovation floor, DistrictHeatingShare). And ported
  the **DE scenario data** itself → `genesysmod_scenariodata_de.jl` (module `ScenarioDataDe`,
  auto-dispatched for `model_region="de"`): phase-outs, H2-import price/availability, offshore limits,
  Osterpaket + FEP corridors, power net-zero, 80 % power-RE, E13a. This closed most of the original
  gap (Power 89→361 GW). NB: adding a new `scenariodata_*.jl` needs a GENeSYSMOD recompile
  (readdir-include isn't staleness-tracked) — noted at `GENeSYSMOD.jl:50`.
- **2026-06-28** — nth=244 barrier-only solves all 10 cleanly (`AUG_CROSSOVER=0`+`DualReductions=0`).
  Robustness: `acc_solve!` sets solver attrs **before** optimize! (else `JuMP.value()` throws
  `OptimizeNotCalled`); ε-sweep guards on `has_values`; `DualReductions=0` fixes spurious
  `INFEASIBLE_OR_UNBOUNDED`. Crossover on the guard-degenerate model is a bottleneck + failure source.
- **2026-06-26** — Fixed a pre-existing bug in `genesysmod_results.jl:238` (`output_capacity`
  TotalCapacity used a stale `tmp_techs`, wrote CHP-only). Now covers all techs. Affects every run.
- **2026-06-26** — Result visualizations (`Results/viz/`): Pareto frontier, capacity-mix, resistance
  decomposition, GoRES-style polar charts. Per-point results output (§6.3) + acceptance decomposition.
- **2026-06-26** — Trade costs data-only (§5.2). Full paper frontier (crossover). Created this doc.
- **2026-06-25** — Found + fixed `bounds.jl` base-year root cause (§5.1); DE feasible; free-trade
  frontier in GAMS ballpark.
- earlier — MO add-on proven on europe testdata; DE pipeline + converter; ~10 format-fix layers.
