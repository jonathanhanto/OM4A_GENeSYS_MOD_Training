# Julia ↔ GAMS — Verified Side-by-Side Comparison (DE acceptance, cost-opt point)

> Primary-evidence verification of the residual Julia-vs-GAMS gap, 2026-07-03.
> **Confidence: high.** GAMS read from result GDX `Acc_PO_RE_DGuard_AP_10_484_nth_18_06.gdx`
> (`/c/GAMS/36/gdxdump`); Julia from `de_k10_nth484_costopt` CSVs; both input workbooks diffed
> cell-by-cell. The stored GDX solution IS the cost-opt point (top-level `zAcc=64.05=zAccAtCost=zAccHi`,
> `zAug=2,283,198`, `ΣTotalDiscountedCost=2.28e6`) — directly comparable to Julia's costopt.
> Companion to `ACCEPTANCE_MO_PORT.md` (§7 = the actionable ranked list).

## TL;DR

Julia cost = **1.925e6 = 84.3 %** of GAMS 2.283e6. Demand-side sectors match within ~2 %; the
**entire divergence is supply/conversion/storage**. GAMS decarbonises to **0 Mt** CO₂ by 2050; Julia
plateaus at **116.7 Mt**. The chain: Julia does not decarbonise industry → no H₂ demand-pull → the
whole H₂-utilisation fleet (fuel cells, H₂-CHP, H₂ storage) is skipped → ~300 GW less Power → lower
capital → lower z. **The load-bearing open question is why Julia keeps DIRTY steel when the CLEAN
substitute is CHEAPER at the identical CO₂ penalty (see “Crux” below) — likely a real bug.**

## 1. Capacity 2050 by sector (GW)

| Sector | GAMS | Julia | J/G | Status | Note |
|---|---|---|---|---|---|
| Power | 638.0 | 394.3 | 0.62 | gap | −244 GW: 83 % PV, 11 % onshore, 6 % gas |
| Storages | 228.4 | 91.4 | 0.40 | gap | Julia: CAES 85 replaces Li-Ion 85; **all** H₂/methane storage → 0 |
| Transformation | 174.6 | 37.7 | 0.22 | gap | electrolysis 97→18, X_Fuel_Cell 31→0, methanation 23→7 |
| CHP | 90.5 | 17.1 | 0.19 | gap | CHP_Hydrogen_FuelCell 80→0; biomass-CHP 1.3→16.7 substitutes |
| Resources | 1241 | 1040 | 0.84 | gap | downstream of reduced Power/H₂ demand |
| Buildings | 1848 | 1843 | 1.00 | **match** | demand-side, exogenous |
| Industry | 366 | 358 | 0.98 | **match** | demand-side supply |
| Transport | 6626 | 6523 | 0.98 | **match** | demand-side |

**Power gap −244 GW composition** (J−G): PV −202.7 (rooftop-residential 90→**0**, rooftop-commercial
92.5→19.3, utility −45), Wind_Onshore −26.3, Gas −15.3 (CCGT 21→5.6), Offshore ±0 (70→70,
bound-limited both), Coal/Hydro ≈0.

## 2. H₂ sector 2050 (the electrolysis inconsistency, RESOLVED)

Three distinct quantities were conflated in the earlier (medium-confidence) pass. Verified:

| Quantity | GAMS | Julia | note |
|---|---|---|---|
| electrolysis (X_Alkaline) capacity | 97.4 GW | 17.6 GW (0.18) | |
| electrolysis **H₂ output 2050** | 1069.7 PJ | **278.2 PJ** (0.26) | the “1101 PJ” earlier was the **all-year 2018–2050 sum**, not 2050 |
| electrolysis **Power input 2050** | 1337.2 PJ | **394.9 PJ** (0.30) | the “395 vs 1337” pair = power consumption, correctly |
| total H₂ **production** 2050 | 1934.5 PJ | 559.4 PJ (0.29) | Julia has **no H₂ storage discharge** (D_Gas_H2/D_SCS_H2 = 0) |
| total H₂ **use** 2050 | 1502.5 PJ | 127.4 PJ (0.08) | Julia H₂ use is only synth-fuel transport + methanation |
| H₂-utilisation fleet (fuel cells, H₂-CHP, H₂ storage) | 80/31/80 GW built | **all 0** | absent in Julia |

> Correction to prior notes: electrolysis is NOT “barely built” — it builds 17.6 GW and produces
> 278 PJ in 2050 (≈¼ of GAMS). The `1101` was an all-year output sum.

## 3. Emissions

| | GAMS | Julia | Status |
|---|---|---|---|
| total CO₂ 2050 | **0 Mt** | **116.7 Mt** | gap: Industry 83 (BF_BOF 50 + HardCoal-heat 27), Buildings 16, X_SMR 11, Transport 6 |
| trajectory 2018→2050 (Mt) | 706/550/297/144/52/0/0 | 720/594/364/204/165/140/117 | Julia decarbonises slower, plateaus |
| CO₂ price `Par_EmissionsPenalty` | 722 EUR/t (2045-50) | **identical** 722 | **match** — byte-identical; NOT the differentiator |
| emission LIMITS | all 999999 (non-binding) | same | **match** — decarb driven only by the price, both sides |
| E13a sectoral ratchet | ported (Power→0 after 2030) | ported verbatim (`scenariodata_de.jl:264-272`) | **match** — only forbids increases, permits a positive plateau |

## 4. Constraints & settings

| Item | GAMS | Julia | Status |
|---|---|---|---|
| **RE3_RETargetPath** | binds 15× — pins the 2050 RE floor (`equ.gms:592-599`, guard `SpecifiedAnnualDemand>0`) | **never generates** — whole RE1/2/3 block nested under `if REMinProductionTarget>0` (`equ.jl:955`), sheet EMPTY | **bug (data/guard)** |
| **Reserve Margin RM1-3** | data-zeroed (`scenariodata_de.gms:135`), RM3 = 0 rows | off via `switch_reserve=0` | **match** — RM dead BOTH sides |
| **Peaking PC1-4** | minrun=1, with_trade=0, with_storages=0, startyear=2025, min_thermal=0.5; PC3 binds 45, PC4 468 (incl CHP) | minrun=0, with_trade=1, with_storages=1, 2030, 0.25; PC4 never generates; **PC4 guard omits CHP branch** (`equ.jl:1391` vs `equ.gms:832`) | **bug + config** — binds softer in Julia |
| **CA3b** per-timeslice availability | RHS `×AvailabilityFactor` (`equ.gms:266`) | AF term **absent** (`equ.jl:363`); AF<1 for 1039/1782 rows | **bug** — partly compensated by CA5 (which DOES carry AF) |
| **SC4** rel. phase-in growth | pooled `(y,f)` over all t,r (`equ.gms:447`) — national cap | per-region `(y,r,f)` (`equ.jl:694`) — tighter per region | **bug (index)** |
| `ProductionGrowthLimit` | Power/Heat/Transport 0.05, Air 0.025 | identical values | **match** |
| `StorageLevelYearStart` | pinned 0.75/0.75 | band 0.25–0.75 (sheet empty) | **data** — Julia has more start-level freedom |
| `set_symmetric_transmission` | 0.85 | 0.90 | **data/config** — divergent |
| H₂-tech DATA (capex/IAR/OAR/OpLife/AF/MaxCap) | — | **byte-identical** to GAMS | **match** — “data missing/worse” REFUTED |
| PV_Rooftop_Residential | 90 GW (fed by A_Rooftop_Residential 63 GW area) | **0** — `A_Rooftop_Residential` supplies 0 PJ area | **data** — missing residential-rooftop area supply |

## 5. Crux — RESOLVED (2026-07-03): the CO₂ penalty reached only 1 of 16 regions (a DATA bug)

**The load-bearing question — why Julia kept dirty steel — was a DATA/inheritance issue, not code.**
`Par_EmissionsPenalty` and `Par_EmissionPenaltyTagTech` are stored under region **`DE_BY`** as the
global default. GAMS inherits them from `data_base_region=DE_BY` to every region
(`genesysmod_dataload_long.gms:159-164`). The Julia run uses `data_base_region="World"` with a single
World-inheritance step, so a DE_BY-stored default reached **only DE_BY** — the other 15 regions got
**CO₂ penalty = 0**, making dirty steel/fossil free there. Power still decarbonised (hard net-zero
mandate), but INDUSTRY had no price signal in 15/16 regions → the 117 Mt residual + the whole missing
H₂/clean-fleet chain. (All other DE_BY-labelled sheets carry full per-region data, so only these two
were affected — verified by scanning every sheet for DE_BY-without-World.)

**Fix (data-only, per principle):** relabel these two sheets `DE_BY → World` (converter +
`convert_de_to_julia.py`; live workbook patched, backup `…preemispenaltyfix.xlsx`). **Result
(cost-min nth=484): CO₂ 2050 117→0 Mt (exact GAMS match), z 1.925e6→2.227e6 = 84.3%→97.6% of GAMS,
steel switches BF_BOF 17.7→3.0 GW / Scrap_EAF 8.8→25.2 GW (GAMS 26.6).** The z-gap collapsed from
16% to ~2.4% with a single data relabel. This supersedes the whole "instrumented emission-accounting
run" plan below — the penalty WAS correctly formulated in the objective; it just wasn't reaching 15
regions because of the missing DE_BY-inheritance.

<details><summary>Original crux write-up (kept for context — now resolved above)</summary>

GAMS switches steel to clean routes; Julia keeps **`HHI_BF_BOF` 17.7 GW emitting 50 Mt** and
**`HMI_HardCoal` 20.5 GW / 27 Mt**. But the clean substitute is **CHEAPER** and unbounded in BOTH
models: `HHI_Scrap_EAF` capex **184** vs `BF_BOF` **442**, `MaxCapacity=999999` both; and the CO₂
penalty on the dirty route is the **identical 722 EUR/t**. A cost-minimiser paying ~36 BEUR/yr of
avoidable CO₂ penalty when the clean route is cheaper is **economically irrational** — so either the
penalty is **not actually charged** to `HHI_BF_BOF`/`HMI_HardCoal` in Julia's objective (an
emission-accounting/tagging bug), or a hidden constraint forces the dirty tech / caps EAF (e.g. a
base-year lock, scrap-supply limit, or min-production). **Data and the penalty parameter are already
ruled out (byte-identical).** This single question likely explains the bulk of the 74 % “lower-cost
optimum” portion of the z-gap and the entire missing H₂-demand chain.

**Sharpened (2026-07-03, direct checks):**
- 2050 steel: GAMS `HHI_Scrap_EAF` **26.6 GW** + `BF_BOF` 0.2 (fully clean); Julia `Scrap_EAF`
  **8.8 GW** + `BF_BOF` **17.7 GW** (kept dirty).
- `HHI_Scrap_EAF` consumes **only Power** (InputActivityRatio), capex 184 (< BF_BOF 442),
  `TotalAnnualMaxCapacity=999999` — no capacity limit.
- **No modal-split cap on steel:** `Par_ModalSplitByFuel` / `TagModalTypeToModalGroups` /
  `TagTechnologyToModalType` have **zero** steel rows → the scrap-EAF share is NOT constraint-capped.
- `HHI_BF_BOF` **does** emit in the Julia solution (`output_emission` = 50 Mt, so
  `EmissionActivityRatio` is active) — but `output_technology_costs_detailed` has **no
  emission-penalty line type at all** and **no industry-tech rows**, so the per-tech penalty
  magnitude can't be read from results.

So the clean route is cheaper, unbounded, uncapped, and Power-only, with the identical 722 EUR/t
penalty on the dirty route — yet Julia keeps `BF_BOF`. That is not a cost-min outcome unless the
penalty is not actually charged to `BF_BOF` in the objective, or a non-obvious constraint (e.g. a
base-year production floor holding `BF_BOF` up, or a Power-supply limit throttling `Scrap_EAF`) binds.

**Next step (needs an instrumented run):** dump, from the built Julia model at the cost-opt solution,
the objective's `DiscountedTechnologyEmissionsPenalty` contribution on `HHI_BF_BOF` and the LP reduced
cost of `HHI_Scrap_EAF` vs `HHI_BF_BOF` NewCapacity. If the penalty term is present but its value on
`BF_BOF` is ~0 → emission-accounting bug (highest-value fix). If the penalty is charged and EAF still
isn't preferred → a binding constraint keeps `BF_BOF` (find it via the IIS-style dual inspection).

</details>

## 6. Corrections to the earlier (medium-confidence) analysis

| Earlier claim | Verdict |
|---|---|
| “Reserve Margin OFF is a firm-capacity gap driver; `switch_reserve=1` is a quick win” | **REFUTED** — GAMS has RM off too; enabling it would make Julia *stricter* than GAMS |
| “Julia CO₂ price is lower than GAMS” | **REFUTED** — `Par_EmissionsPenalty` byte-identical |
| “H₂/steel tech data is missing/worse in Julia” | **REFUTED** — every parameter byte-identical |
| “X_Alkaline produces ~1101 PJ in 2050 / electrolysis barely built” | **CORRECTED** — 17.6 GW built, 278 PJ in 2050; 1101 was an all-year sum |
| “12.77 PJ base-year short = data over-specification / GAMS rides a slack” | **REFUTED earlier** (07-03) — it was the PhaseIn port bug |

## 6b. Input-data completeness audit (2026-07-03, confidence high)

Question: does the DE Julia workbook (76 sheets) provide every parameter the (newer) Julia model
reads, or does something silently default like `REMinProductionTarget` did? **Verdict: the workbook
is effectively COMPLETE.** Every empty/missing sheet is ALSO empty/absent/hardcoded in GAMS, so
Julia's zero/permissive defaults faithfully reproduce GAMS.

- **13 “missing” sheets** → all benign: `Acceptance_Factor/Powerlines_final` live in the separate
  Justice workbook; the 5 `EFactor*` + `CoalDigging/CoalSupply` are the **employment module**
  (`switch_employment_calculation=0` → inert); `GroupTotalAnnualMax/Min`, `TagRegionToSubsets` are
  new Julia grouping features (sheet-absent-safe sentinels); `NetTradeAnnual` is an endogenous
  variable, not an input.
- **16 “empty” sheets** → all empty in GAMS too and either guarded-off or additive-zero in BOTH:
  `SelfSufficiency` (EB7 off both), `CapacityFactor` (sourced from the Timeseries file, by design),
  `MinStorageCharge`/`ResidualStorageCapacity`/`TotalAnnualMin*`/`AnnualExogenousEmission`/
  `ModelPeriodExogenousEmission`/`RegionalCCSLimit`/`NewCapacityExpansionStop`/`SpecifiedDemandDevelopment`
  (the active demand `SpecifiedAnnualDemand` has 896 rows), `BaseYearProduction` (legacy; the active
  one is `RegionalBaseYearProduction`, 421 rows). The lone exception, `REMinProductionTarget`, is
  empty in GAMS too — the RE3 problem is a CODE guard bug (§7 item 2), NOT a data gap.
- **8 “unused” sheets** (Julia hardcodes them) → **the critical z-scaling check PASSES**: all three
  discount rates (General/Social/Technology) are hardcoded **0.05 in both**, so z is not skewed.
  `StorageE2PRatio` is a false positive (it IS read, `dataload.jl:448`, 9 rows match GDX);
  `TradeLossFactor` (Power 0.00003), `TagTimeIndependentFuel` (11-fuel list), `BaseYearSlack` (0.035)
  all match GAMS.

**Two NEW run-SWITCH mismatches found (not workbook data, storage-related, GAMS-parity fixes):**
- `set_storagelevelstart_down` = **0.25** (Julia) vs **0.75** (GAMS) → Julia lets year-start storage
  float in [0.25, 0.75]·cap; GAMS pins 0.75·cap. Loosens Julia storage. Fix: pass 0.75.
- `E2P_ratio_deviation_factor` = **2** (Julia) vs **3** (GAMS) → Julia caps storage energy headroom
  at 2× vs 3× (lower bound 0.5 matches). Tightens Julia storage. Fix: pass 3.

Minor caveat: `ProductionGrowthLimit` values match (0.05 / Air 0.025) but the per-fuel taxonomy
differs — worth a one-time coverage check that every modelled fuel appears (else it silently gets
growth-limit 0).

## 7. Re-ranked actionable items (post-verification)

1. **[HIGH · investigate] The dirty-steel/emission-penalty crux** (§5) — resolve why Julia doesn't
   abate industry despite identical penalty + cheaper clean tech. Likely the single biggest lever
   (drives the H₂ chain + most of the z-gap). Check the solved industry emission-penalty accounting.
2. **[HIGH · code] `RE3_RETargetPath` unreachable** — lift RE3 out of the `REMinProductionTarget>0`
   guard (or populate the sheet). Primary slope driver; pins the acc-opt RE floor like GAMS.
3. **[MEDIUM · config+code] Peaking** — pass GAMS switches (minrun=1, with_trade=0, with_storages=0,
   startyear=2025, min_thermal=0.5) and port the PC4 CHP branch. Raises firm capacity.
4. **[MEDIUM · code] CA3b `×AvailabilityFactor`** and **SC4 pooling** — genuine port bugs; do with a
   DE+Europe+MiddleEarth regression (CA3b is partly compensated by CA5).
5. **[MEDIUM · data] PV_Rooftop_Residential** — populate `A_Rooftop_Residential` area supply.
6. **[LOW · data/config] `set_symmetric_transmission` 0.9→0.85**, `StorageLevelYearStart` pin 0.75,
   `TagTradeMonoDirectional` (2050-only).
7. **NOT `switch_reserve=1`** — refuted; would over-tighten vs GAMS.
