# =====================================================================
#  DE scenario data — Julia port of genesysmod_scenariodata_de.gms
# =====================================================================
# Applied by the build pipeline for model_region="de" (genesysmod_main.jl:130-135),
# after bounds and before genesysmod_equ, so every Params edit propagates into the
# constraints. Mirrors the 367-line GAMS file: trade/import rules, H2 import
# availability+price, nuclear/coal phase-outs, offshore-wind limits, the Osterpaket
# capacity targets, the power-sector net-zero mandate, the RE-share targets, and the
# year-over-year sectoral emission reduction — the DE policy constraints that force
# GAMS to decarbonise+electrify (and were missing in Julia).
#
# Names: the input Excel is already on the Julia naming convention, so this file uses
# the JULIA tech/fuel names (P_Wind_Offshore_*, P_Coal_*, P_PV_Utility_Avg, …) — NOT
# the GAMS RES_* names. Every tech/fuel/region touch is guarded so a missing name
# silently no-ops instead of throwing (and is reported by the startup @warn).
#
# GAMS `%switch_*%` / `%h2_pricetarget%` are compile-time macros, not model data, so
# they are ported as module consts seeded with the GAMS `$if not set` defaults.
# =====================================================================
module ScenarioDataDe
    using JuMP
    export genesysmod_scenariodata

    # --- GAMS $setglobal macros (defaults verified against the .gms header) ---
    const DE_h2_pricetarget            = 1.82   # line 31
    const DE_switch_growth_rate_power  = 1      # line 42 default 1
    const DE_switch_transport_costs_h2 = 1      # line 43 default 1 (×1 ⇒ no-op)
    const DE_switch_h2_waste_heat      = 0      # line 37 default 0 ⇒ zero electrolysis mode-2 output
    const DE_switch_central_h2         = 0      # line 36 default 0
    const DE_switch_Policy_Scenario    = 1      # line 35 default 1 (Osterpaket + RE targets)
    const DE_switch_FEP                = 1      # line 34 default 1 (Flächenentwicklungsplan offshore)

    function genesysmod_scenariodata(model, Sets, Params, Maps, Vars, Switch)
        𝓡 = Sets.Region_full
        𝓨 = Sets.Year
        𝓣 = Sets.Technology
        𝓕 = Sets.Fuel
        𝓛 = Sets.Timeslice
        𝓜 = Sets.Mode_of_operation

        has(t)  = t ∈ 𝓣
        hasr(r) = r ∈ 𝓡
        subset(name) = filter(has, get(Params.Tags.TagTechnologyToSubsets, name, String[]))
        modesof(t) = get(Maps.Tech_MO, t, eltype(𝓜)[])

        # startup sanity: warn on any expected DE tech absent from the data set
        expected = ["P_Nuclear","P_Coal_Lignite","P_Coal_Hardcoal","CHP_Coal_Hardcoal",
            "CHP_Coal_Lignite","R_Coal_Hardcoal","X_SMR","X_Alkaline_Electrolysis",
            "X_SOEC_Electrolysis","X_PEM_Electrolysis","Z_Import_H2","Z_Import_Gas",
            "P_Wind_Offshore_Deep","P_Wind_Offshore_Shallow","P_Wind_Offshore_Transitional",
            "P_Wind_Onshore_Opt","P_Wind_Onshore_Avg","P_Wind_Onshore_Inf","D_Battery_Li-Ion"]
        missing_t = filter(t -> !has(t), expected)
        isempty(missing_t) || @warn "ScenarioDataDe: expected DE techs absent from Sets.Technology (edits skipped): $missing_t"

        offshore_hubs = filter(hasr, ["DE_Nord", "DE_Baltic"])

        # ============ (a) TRADE / IMPORT ============
        # Import.fx from the offshore hubs = 0 (GAMS 27-28)
        for (f, r1, r2) ∈ Maps.Set_Fuel_Regions, y ∈ 𝓨, l ∈ 𝓛
            r1 ∈ offshore_hubs && JuMP.fix(Vars.Import[y, l, f, r1, r2], 0; force = true)
        end
        # NewTradeCapacity Power from hubs = 0 (central_h2, default off ⇒ skipped) (127-128)
        if DE_switch_central_h2 == 1 && "Power" ∈ 𝓕
            for (f, r1, r2) ∈ Maps.Set_Fuel_Regions, y ∈ 𝓨
                (f == "Power" && r1 ∈ offshore_hubs) && JuMP.fix(Vars.NewTradeCapacity[y, f, r1, r2], 0; force = true)
            end
        end
        # Power trade growth rate (growth_rate_power=1) (46)
        if DE_switch_growth_rate_power != 0 && "Power" ∈ 𝓕
            for r ∈ 𝓡, rr ∈ 𝓡, y ∈ 𝓨
                Params.GrowthRateTradeCapacity[r, rr, "Power", y] = DE_switch_growth_rate_power
            end
        end
        # Gas / H2 trade growth rates (159-160)
        for f ∈ ("Gas_Natural" => 0.1, "H2" => 0.15)
            fuel, val = f
            fuel ∈ 𝓕 || continue
            for r ∈ 𝓡, rr ∈ 𝓡, y ∈ 𝓨
                Params.GrowthRateTradeCapacity[r, rr, fuel, y] = val
            end
        end
        # extra gas trade capacity DE_BB->DE_BE (81)
        if "Gas_Natural" ∈ 𝓕 && hasr("DE_BB") && hasr("DE_BE")
            for y ∈ 𝓨
                Params.TradeCapacity["DE_BB", "DE_BE", "Gas_Natural", y] = 100
            end
        end
        # H2 transport cost multiplier (default 1 ⇒ no-op) (52)
        if DE_switch_transport_costs_h2 != 0 && DE_switch_transport_costs_h2 != 1 && "H2" ∈ 𝓕
            for r ∈ 𝓡, y ∈ 𝓨, rr ∈ 𝓡
                Params.TradeCosts[r, "H2", y, rr] *= DE_switch_transport_costs_h2
            end
        end
        # CommissionedTradeCapacity = 0 only if FEP==0 (300); FEP default 1 ⇒ skipped
        if DE_switch_FEP == 0
            for r ∈ 𝓡, rr ∈ 𝓡, f ∈ 𝓕, y ∈ 𝓨
                Params.CommissionedTradeCapacity[r, rr, f, y] = 0
            end
        end

        # ============ (b) H2 IMPORT AVAILABILITY + PRICE ============
        if has("Z_Import_H2")
            # price schedule (34-39), chained 2050 -> 2025
            if DE_h2_pricetarget != 0
                scale = DE_h2_pricetarget / 1.82
                vc = Dict{Int,Float64}()
                vc[2050] = DE_h2_pricetarget * 7.68736
                vc[2045] = vc[2050] * (((1.1 - 1) / scale) + 1)
                vc[2040] = vc[2045] * (((1.15 - 1) / scale) + 1)
                vc[2035] = vc[2040] * (((1.25 - 1) / scale) + 1)
                vc[2030] = vc[2035] * (((1.4 - 1) / scale) + 1)
                vc[2025] = vc[2030] * (((1.5 - 1) / scale) + 1)
                for r ∈ 𝓡, m ∈ modesof("Z_Import_H2"), (yy, v) ∈ vc
                    yy ∈ 𝓨 && (Params.VariableCost[r, "Z_Import_H2", m, yy] = v)
                end
            end
            # availability: 0 before 2030, 1 in 2025, 0 for the listed regions (70-77)
            for r ∈ 𝓡, y ∈ 𝓨
                y < 2030 && (Params.AvailabilityFactor[r, "Z_Import_H2", y] = 0)
            end
            2025 ∈ 𝓨 && (Params.AvailabilityFactor[:, "Z_Import_H2", 2025] .= 1)
            for r ∈ filter(hasr, ["DE_BE", "DE_HB", "DE_HE", "DE_HH", "DE_ST", "DE_TH"]), y ∈ 𝓨
                Params.AvailabilityFactor[r, "Z_Import_H2", y] = 0
            end
        end
        # electrolysis waste-heat mode-2 output = 0 (h2_waste_heat=0) (58-60)
        if DE_switch_h2_waste_heat == 0
            for t ∈ filter(has, ["X_Alkaline_Electrolysis", "X_SOEC_Electrolysis", "X_PEM_Electrolysis"])
                for r ∈ 𝓡, f ∈ 𝓕, m ∈ 𝓜, y ∈ 𝓨
                    m == 2 && (Params.OutputActivityRatio[r, t, f, m, y] = 0)
                end
            end
        end
        # allow base-year SMR expansion (79): remove the 2018 NewCapacity upper bound
        if has("X_SMR")
            for r ∈ 𝓡
                if JuMP.has_upper_bound(Vars.NewCapacity[Switch.StartYear, "X_SMR", r])
                    JuMP.delete_upper_bound(Vars.NewCapacity[Switch.StartYear, "X_SMR", r])
                end
            end
        end
        # electrolysis base-year production floors (141-142)
        if has("X_Alkaline_Electrolysis") && "H2" ∈ 𝓕
            for (yr, k) ∈ ((2018, 0.01), (2025, 0.02))
                yr ∈ 𝓨 || continue
                for r ∈ 𝓡
                    Params.AvailabilityFactor[r, "X_Alkaline_Electrolysis", yr] != 0 || continue
                    Params.RegionalBaseYearProduction[r, "X_Alkaline_Electrolysis", "H2", yr] =
                        k * Params.SpecifiedAnnualDemand[r, "H2", yr]
                end
            end
        end
        # flat H2/gas imports: import ROA per timeslice <= annual-share*1.05 (88, 91)
        for t ∈ filter(has, ["Z_Import_H2", "Z_Import_Gas"])
            m1 = findfirst(==(1), modesof(t))
            m1 === nothing && continue
            m = modesof(t)[m1]
            for y ∈ 𝓨, r ∈ 𝓡
                tot = sum(Vars.RateOfActivity[y, ll, t, m, r] for ll ∈ 𝓛)
                for l ∈ 𝓛
                    @constraint(model, Vars.RateOfActivity[y, l, t, m, r] <= tot * Params.YearSplit[l, y] * 1.05,
                        base_name = "ScenarioData_DE_FlatImport|$(t)|$(y)|$(l)|$(r)")
                end
            end
        end

        # ============ (c) PHASE-OUTS (nuclear / coal) ============
        # nuclear activity cap (104) + availability (308)
        if has("P_Nuclear")
            for r ∈ 𝓡, y ∈ 𝓨
                y >= 2025 && (Params.TotalTechnologyAnnualActivityUpperLimit[r, "P_Nuclear", y] = 0)
                y > 2020 && (Params.AvailabilityFactor[r, "P_Nuclear", y] = 0)
            end
        end
        # coal / fossil-CHP / coal-resource phase-outs by year threshold (309-317)
        phaseout = [("P_Coal_Lignite", 2035), ("P_Coal_Hardcoal", 2035),
            ("CHP_Coal_Hardcoal", 2035), ("CHP_Coal_Lignite", 2035), ("R_Coal_Hardcoal", 2020)]
        for (t, thr) ∈ phaseout, r ∈ 𝓡, y ∈ 𝓨
            (has(t) && y > thr) && (Params.AvailabilityFactor[r, t, y] = 0)
        end
        # NRW earlier lignite exit (2030) (310, 314)
        if hasr("DE_NRW")
            for t ∈ filter(has, ["P_Coal_Lignite", "CHP_Coal_Lignite"]), y ∈ 𝓨
                y > 2030 && (Params.AvailabilityFactor["DE_NRW", t, y] = 0)
            end
        end
        # no hardcoal/lignite power production in 2040 (306-307). GAMS filters by
        # InputActivityRatio(Hardcoal|Lignite); those are exactly the coal power/CHP techs.
        if 2040 ∈ 𝓨 && "Power" ∈ 𝓕
            for t ∈ filter(has, ["P_Coal_Hardcoal", "P_Coal_Lignite", "CHP_Coal_Hardcoal", "CHP_Coal_Lignite"])
                (t, "Power") ∈ Maps.Set_Tech_FuelOut || continue
                for r ∈ 𝓡
                    JuMP.fix(Vars.ProductionByTechnologyAnnual[2040, t, "Power", r], 0; force = true)
                end
            end
        end

        # ============ (d) OFFSHORE / DE_Nord / DE_Baltic + CAPACITY LIMITS ============
        # offshore-wind capacity ceilings for the connected Länder (151-156)
        offlim = [("DE_SH", "P_Wind_Offshore_Deep", 0.0), ("DE_SH", "P_Wind_Offshore_Shallow", 2.4450),
            ("DE_NI", "P_Wind_Offshore_Deep", 0.0), ("DE_NI", "P_Wind_Offshore_Shallow", 4.2530),
            ("DE_MV", "P_Wind_Offshore_Deep", 0.0), ("DE_MV", "P_Wind_Offshore_Shallow", 1.0675)]
        for (r, t, v) ∈ offlim
            (hasr(r) && has(t)) || continue
            for y ∈ 𝓨
                y >= 2015 && (Params.TotalAnnualMaxCapacity[r, t, y] = v)
            end
        end
        # hub regions: zero all availability, then re-enable specific techs (107-123)
        for r ∈ offshore_hubs
            Params.AvailabilityFactor[r, :, :] .= 0
            for t ∈ filter(has, ["P_Wind_Offshore_Deep", "D_Battery_Li-Ion",
                    "X_Alkaline_Electrolysis", "X_PEM_Electrolysis", "X_SOEC_Electrolysis"])
                Params.AvailabilityFactor[r, t, :] .= 1
            end
        end
        # reserve margin off everywhere (131-135; 135 supersedes)
        Params.ReserveMargin[:, :] .= 0
        # offshore base-year production + residual (322-344)
        for (r, t, v) ∈ [("DE_Nord", "P_Wind_Offshore_Deep", 55.0), ("DE_Baltic", "P_Wind_Offshore_Deep", 13.0),
                ("DE_MV", "P_Wind_Offshore_Transitional", 0.0), ("DE_NI", "P_Wind_Offshore_Transitional", 0.0),
                ("DE_SH", "P_Wind_Offshore_Transitional", 0.0)]
            (hasr(r) && has(t) && "Power" ∈ 𝓕 && 2018 ∈ 𝓨) &&
                (Params.RegionalBaseYearProduction[r, t, "Power", 2018] = v)
        end
        if has("P_Wind_Offshore_Transitional")
            for r ∈ filter(hasr, ["DE_MV", "DE_NI", "DE_SH"]), y ∈ 𝓨
                Params.ResidualCapacity[r, "P_Wind_Offshore_Transitional", y] = 0
            end
        end
        if has("P_Wind_Offshore_Deep")
            nord = Dict(2018 => 5.3060, 2020 => 6.6980, 2025 => 6.6980, 2030 => 6.2930, 2035 => 4.6538)
            balt = Dict(2018 => 1.0760, 2020 => 1.0720, 2025 => 1.0675, 2030 => 1.0650, 2035 => 1.0167)
            for (r, tab) ∈ (("DE_Nord", nord), ("DE_Baltic", balt))
                hasr(r) || continue
                for (yr, v) ∈ tab
                    yr ∈ 𝓨 && (Params.ResidualCapacity[r, "P_Wind_Offshore_Deep", yr] = v)
                end
            end
        end

        # ============ (f) TECH-AVAILABILITY / CapacityFactor tweaks ============
        # solar-thermal CF probe on offshore hubs (96-97) — CF is all-ones at this stage
        # (dataload.jl:378) so the GAMS `$ CF==0` guard never fires here → guarded no-op.
        for t ∈ filter(has, ["HLR_Solar_Thermal", "HLI_Solar_Thermal"])
            for r ∈ 𝓡, l ∈ 𝓛, y ∈ 𝓨
                Params.CapacityFactor[r, t, l, y] == 0 && (Params.CapacityFactor[r, t, l, y] = 0.00001)
            end
        end
        # no free variable cost (101)
        for (t, m) ∈ Maps.Set_Tech_MO, r ∈ 𝓡, y ∈ 𝓨
            Params.VariableCost[r, t, m, y] == 0 && (Params.VariableCost[r, t, m, y] = 0.01)
        end

        # ============ (e) SECTORAL EMISSIONS — the decarbonisation drivers ============
        if "CO2" ∈ Sets.Emission
            # power-sector net-zero after 2030 (219) — the key electrification lever
            if "Power" ∈ Sets.Sector
                for y ∈ 𝓨, r ∈ 𝓡
                    y > 2030 && JuMP.fix(Vars.AnnualSectoralEmissions[y, "CO2", "Power", r], 0.0; force = true)
                end
            end
            # E13a: sectoral CO2 must not increase year-over-year (357-358)
            for i ∈ 2:length(𝓨)
                y, yprev = 𝓨[i], 𝓨[i-1]
                y > 2018 || continue
                for se ∈ Sets.Sector, r ∈ 𝓡
                    @constraint(model,
                        Vars.AnnualSectoralEmissions[y, "CO2", se, r] <= Vars.AnnualSectoralEmissions[yprev, "CO2", se, r],
                        base_name = "ScenarioData_DE_E13a|$(y)|$(se)|$(r)")
                end
            end
        end
        # fossil-CHP phase-out from 2035 (223-228)
        for t ∈ intersect(subset("CHP"), subset("FossilPower")), r ∈ 𝓡, y ∈ 𝓨
            y >= 2035 && (Params.AvailabilityFactor[r, t, y] = 0)
        end
        # 80% RES in the power sector from >2025 (233-234)
        if "Power" ∈ 𝓕
            power_out = [t for (t, f) ∈ Maps.Set_Tech_FuelOut if f == "Power"]
            for y ∈ 𝓨
                y > 2025 || continue
                @constraint(model,
                    sum(Vars.TotalREProductionAnnual[y, r, "Power"] for r ∈ 𝓡) >=
                    0.8 * sum(Vars.ProductionByTechnologyAnnual[y, t, "Power", r] for t ∈ power_out, r ∈ 𝓡),
                    base_name = "ScenarioData_DE_PowerREProduction|$(y)")
            end
        end

        # ============ (g) OSTERPAKET + FEP capacity targets ============
        if DE_switch_Policy_Scenario == 1
            solar_g = setdiff(subset("Solar"), ["HLR_Solar_Thermal", "HLI_Solar_Thermal"])
            groups = Dict(
                "onshore"  => filter(has, ["P_Wind_Onshore_Opt", "P_Wind_Onshore_Avg", "P_Wind_Onshore_Inf"]),
                "solar"    => solar_g,
                "offshore" => filter(has, ["P_Wind_Offshore_Deep", "P_Wind_Offshore_Shallow", "P_Wind_Offshore_Transitional"]),
                "h2"       => filter(has, ["X_Alkaline_Electrolysis", "X_SOEC_Electrolysis", "X_PEM_Electrolysis"]),
            )
            cap = Dict("onshore" => 115.0, "solar" => 215.0)
            DE_switch_FEP == 1 && (cap["offshore"] = 30.0; cap["h2"] = 10.0)
            if 2030 ∈ 𝓨
                for (g, v) ∈ cap
                    ts = groups[g]
                    (isempty(ts) || g == "h2") && continue
                    @constraint(model, sum(Vars.TotalCapacityAnnual[2030, t, r] for t ∈ ts, r ∈ 𝓡) >= v,
                        base_name = "ScenarioData_DE_Osterpaket|$(g)")
                end
                if DE_switch_FEP == 1 && !isempty(groups["h2"])
                    @constraint(model, sum(Vars.TotalCapacityAnnual[2030, t, r] for t ∈ groups["h2"], r ∈ 𝓡) == cap["h2"],
                        base_name = "ScenarioData_DE_Osterpaket|h2")
                end
            end
            # FEP offshore capacity corridors (270-287)
            if DE_switch_FEP == 1 && !isempty(groups["offshore"])
                off = groups["offshore"]
                nordic = filter(hasr, ["DE_Nord", "DE_NI", "DE_SH"])
                baltic = filter(hasr, ["DE_Baltic", "DE_MV", "DE_SH"])
                capsum(yr, regs) = sum(Vars.TotalCapacityAnnual[yr, t, r] for t ∈ off, r ∈ regs)
                for (yr, regs, v) ∈ [(2025, nordic, 9.4), (2030, nordic, 31.38), (2045, nordic, 64.4),
                        (2030, baltic, 2.4), (2045, baltic, 5.6)]
                    (yr ∈ 𝓨 && !isempty(regs)) || continue
                    @constraint(model, capsum(yr, regs) == v, base_name = "ScenarioData_DE_FEPoffshore|$(yr)|$(regs[1])")
                end
                for (yr, v) ∈ [(2030, 33.78), (2045, 70.0)]
                    yr ∈ 𝓨 && @constraint(model, sum(Vars.TotalCapacityAnnual[yr, t, r] for t ∈ off, r ∈ 𝓡) >= v,
                        base_name = "ScenarioData_DE_FEPoffshoreTotal|$(yr)")
                end
            end
        end

        # ============ (h) HEAT-SECTOR constraints ============
        # GAMS heat-fuel names map to Julia: Heat_Low_Residential -> Heat_Buildings (converter
        # rename); Heat_Low_Industrial / Heat_District unchanged. Julia's HeatFuels subset already
        # includes Heat_District (GAMS added it separately), so it is excluded from the RHS below.
        heatfuels = intersect(𝓕, get(Params.Tags.TagFuelToSubsets, "HeatFuels", String[]))
        hf_nd = setdiff(heatfuels, ["Heat_District"])

        # HeatREProduction (240): ≥50% of heat production from RES, per region, y>2025 (Policy)
        if DE_switch_Policy_Scenario == 1 && !isempty(heatfuels)
            for y ∈ 𝓨, r ∈ 𝓡
                y > 2025 || continue
                @constraint(model,
                    sum(Vars.TotalREProductionAnnual[y, r, f] for f ∈ heatfuels) >=
                    0.5 * sum(Vars.ProductionByTechnologyAnnual[y, t, f, r] for (t, f) ∈ Maps.Set_Tech_FuelOut if f ∈ hf_nd),
                    base_name = "ScenarioData_DE_HeatREProduction|$(y)|$(r)")
            end
        end

        # BuildingsInertia (354): building-heat production may fall only as fast as the cumulative
        # renovation rate allows (you cannot rip out heating systems faster than they are renovated).
        renov(y) = y > 2040 ? 0.065 : y > 2030 ? 0.045 : y > 2020 ? 0.035 : 0.015
        if "Heat_Buildings" ∈ 𝓕 && 2018 ∈ 𝓨
            bld = [t for t ∈ 𝓣 if Params.Tags.TagTechnologyToSector[t, "Buildings"] != 0 &&
                                  t ∉ get(Params.Tags.TagTechnologyToSubsets, "CHP", String[]) &&
                                  (t, "Heat_Buildings") ∈ Maps.Set_Tech_FuelOut]
            for (jy, y) ∈ enumerate(𝓨)
                y > 2015 || continue
                cum = sum((𝓨[j] - 𝓨[j-1]) * renov(𝓨[j]) for j ∈ 2:jy; init = 0.0)  # YearlyDifferenceMultiplier(𝓨[j-1])
                factor = 1 - cum
                for t ∈ bld, r ∈ 𝓡
                    @constraint(model,
                        Vars.ProductionByTechnologyAnnual[y, t, "Heat_Buildings", r] >=
                        factor * Vars.ProductionByTechnologyAnnual[2018, t, "Heat_Buildings", r],
                        base_name = "ScenarioData_DE_BuildingsInertia|$(y)|$(t)|$(r)")
                end
            end
        end

        # DistrictHeatingShare (365/368): min share of residential (45%) / industrial (10%) heat
        # served via Convert_DH (district heating) in 2050
        for (tech, fuel, share) ∈ (("HLR_Convert_DH", "Heat_Buildings", 0.45),
                                   ("HLI_Convert_DH", "Heat_Low_Industrial", 0.1))
            (2050 ∈ 𝓨 && has(tech) && fuel ∈ 𝓕 && (tech, fuel) ∈ Maps.Set_Tech_FuelOut) || continue
            @constraint(model,
                sum(Vars.ProductionByTechnologyAnnual[2050, tech, fuel, r] for r ∈ 𝓡) >=
                share * sum(Vars.ProductionByTechnologyAnnual[2050, t, fuel, r]
                            for (t, f) ∈ Maps.Set_Tech_FuelOut if f == fuel for r ∈ 𝓡),
                base_name = "ScenarioData_DE_DistrictHeatingShare|$(tech)")
        end

        return nothing
    end
end
