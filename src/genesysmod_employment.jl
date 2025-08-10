# GENeSYS-MOD v3.1 [Global Energy System Model]  ~ March 2022
#
# #############################################################
#
# Copyright 2020 Technische Universität Berlin and DIW Berlin
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# #############################################################
"""

"""
# GENeSYS-MOD v3.1 [Global Energy System Model]  ~ March 2022
#
# Employment post-processor with explicit power-tech EF_Power
#
function genesysmod_employment(model, Sets, Params, Vars, Emp_Sets, Switch)
    # 0) helpers
    job_types = ("ManufacturingJobs", "ConstructionJobs", "OMJobs", "SupplyJobs")
    scenario  = "$(Switch.emissionPathway)_$(Switch.emissionScenario)"
    Δmult(y)  = YearlyDifferenceMultiplier(y, Emp_Sets)

    # Fuels axis in the output container: "All" + fuels from Excel
    fuel_axis   = vcat(["All"], Emp_Sets.Fuel)
    fuels_noAll = Emp_Sets.Fuel

    # Explicit list of power-producing technologies; keep only those present
    power_techs_list = [
        "P_Biomass","P_Coal_Hardcoal","P_Coal_Lignite","P_Nuclear","P_Oil",
        "P_CSP","P_Geothermal","P_Hydro_Large","P_Hydro_Small","P_Ocean",
        "P_PV_Rooftop_Commercial","P_PV_Rooftop_Residential",
        "P_PV_Utility_Avg","P_PV_Utility_Inf","P_PV_Utility_Opt",
        "P_Wind_Offshore_Transitional","P_Wind_Offshore_Shallow","P_Wind_Offshore_Deep",
        "P_Wind_Onshore_Avg","P_Wind_Onshore_Inf","P_Wind_Onshore_Opt",
        "D_Battery_Li-Ion","D_PHS","D_CAES",
        "P_Gas_CCGT","P_Gas_Engines","P_Gas_OCGT","P_Gas_CCS","P_H2_OCGT",
        "D_Battery_Redox","D_PHS_Residual"
    ]
    power_techs = [t for t in power_techs_list if t in Emp_Sets.Technology]

    # Try to find an electrolysis technology name present in your set
    electrolysis_candidates = [
        "X_Electrolysis", "X_ELectrolysis", "X_Electrolyser", "X_Electrolyzer",
        "IND_H2_Electrolysis", "H2_Electrolysis"
    ]
    electrolysis = nothing
    for cand in electrolysis_candidates
        if cand in Emp_Sets.Technology
            electrolysis = cand
            break
        end
    end

    ef_fuel(f,y) = Params.EFactorFuelSupply[f,y]

    # 1) allocate: Region × Technology × Fuel × JobType × Scenario × Year
    output_energyjobs = JuMP.Containers.DenseAxisArray(
        [JuMP.AffExpr() for _ in Emp_Sets.Region, _ in Emp_Sets.Technology,
                         _ in fuel_axis,        _ in job_types, _ in (scenario,),
                         _ in Emp_Sets.Year],
        Emp_Sets.Region, Emp_Sets.Technology, fuel_axis, job_types, (scenario,), Emp_Sets.Year
    )

    # 2) exogenous employment: fill AffExprs
    if Switch.switch_endogenous_employment == 0
        # 2a) interpolate any 0-entries in year-only params
        if length(Emp_Sets.Year) >= 3
            for i in 2:(length(Emp_Sets.Year)-1)
                y₋, y, y₊ = Emp_Sets.Year[i-1], Emp_Sets.Year[i], Emp_Sets.Year[i+1]
                for t in Emp_Sets.Technology
                    if Params.EFactorConstruction[t,y]      == 0; Params.EFactorConstruction[t,y]      = (Params.EFactorConstruction[t,y₋]      + Params.EFactorConstruction[t,y₊])      / 2; end
                    if Params.EFactorOM[t,y]                == 0; Params.EFactorOM[t,y]                = (Params.EFactorOM[t,y₋]                + Params.EFactorOM[t,y₊])                / 2; end
                    if Params.EFactorManufacturing[t,y]     == 0; Params.EFactorManufacturing[t,y]     = (Params.EFactorManufacturing[t,y₋]     + Params.EFactorManufacturing[t,y₊])     / 2; end
                    if Params.EFactorCoalJobs[t,y]          == 0; Params.EFactorCoalJobs[t,y]          = (Params.EFactorCoalJobs[t,y₋]          + Params.EFactorCoalJobs[t,y₊])          / 2; end
                    if Params.DeclineRate[t,y]              == 0; Params.DeclineRate[t,y]              = (Params.DeclineRate[t,y₋]              + Params.DeclineRate[t,y₊])              / 2; end
                    if Params.LocalManufacturingFactor[t,y] == 0; Params.LocalManufacturingFactor[t,y] = (Params.LocalManufacturingFactor[t,y₋] + Params.LocalManufacturingFactor[t,y₊]) / 2; end
                end
                for f in Emp_Sets.Fuel
                    if Params.EFactorFuelSupply[f,y] == 0
                        Params.EFactorFuelSupply[f,y] = (Params.EFactorFuelSupply[f,y₋] + Params.EFactorFuelSupply[f,y₊]) / 2
                    end
                end
                for r in Emp_Sets.Region
                    if Params.CoalSupply[r,y] == 0
                        Params.CoalSupply[r,y] = (Params.CoalSupply[r,y₋] + Params.CoalSupply[r,y₊]) / 2
                    end
                end
                if Params.RegionalAdjustmentFactor[y] == 0
                    Params.RegionalAdjustmentFactor[y] = (Params.RegionalAdjustmentFactor[y₋] + Params.RegionalAdjustmentFactor[y₊]) / 2
                end
            end
        end

        # 2b) fill every (r,t,*,job,scenario,y)
        for r in Emp_Sets.Region, t in Emp_Sets.Technology, y in Emp_Sets.Year
            # Manufacturing & Construction divisors by year
            div_m_c = (y == 2018) ? 1.0 : (y == 2025 ? 7.0 : 5.0)

            # Manufacturing (Fuel="All")
            output_energyjobs[r,t,"All","ManufacturingJobs",scenario,y] =
                (Vars.NewCapacity[y,t,r] *
                 Params.EFactorManufacturing[t,y] *
                 Params.LocalManufacturingFactor[t,y] *
                 2.15 *
                 (1 - Params.DeclineRate[t,y])^Δmult(y)) / div_m_c

            # Construction (Fuel="All")
            output_energyjobs[r,t,"All","ConstructionJobs",scenario,y] =
                (Vars.NewCapacity[y,t,r] *
                 Params.EFactorConstruction[t,y] *
                 2.15 *
                 (1 - Params.DeclineRate[t,y])^Δmult(y)) / div_m_c

            # O&M (Fuel="All")
            output_energyjobs[r,t,"All","OMJobs",scenario,y] =
                (Vars.TotalCapacityAnnual[y,t,r] *
                 Params.EFactorOM[t,y] *
                 2.15 *
                 (1 - Params.DeclineRate[t,y])^Δmult(y))

            # Base SupplyJobs per fuel — skip H2 here (we add H2 via EF_H2 later)
            for f in fuels_noAll
                if f == "H2"; continue; end
                output_energyjobs[r,t,f,"SupplyJobs",scenario,y] =
                    (Vars.UseByTechnologyAnnual[y,t,f,r] *
                     ef_fuel(f,y) *
                     2.15 *
                     (1 - Params.DeclineRate[t,y])^Δmult(y))
            end
        end
    end

    # 3) write results (+ append Fuel="Power" and Fuel="H2" using computed factors)
    if occursin("INFEASIBLE", string(termination_status(model)))
        println("Hello")
    else
        # Base DF from the container (Mfg/Constr/OM + Supply for non-H2 Excel fuels)
        df = convert_jump_container_to_df(
            output_energyjobs;
            dim_names = [:Region, :Technology, :Fuel, :JobType, :Scenario, :Year],
            value_col = :Jobs
        )

        # Tables to append
        power_rows = DataFrame(Region=String[], Technology=String[], Fuel=String[],
                               JobType=String[], Scenario=String[], Year=Int[],
                               Jobs=Float64[])
        h2_rows    = DataFrame(Region=String[], Technology=String[], Fuel=String[],
                               JobType=String[], Scenario=String[], Year=Int[],
                               Jobs=Float64[])

        for y in Emp_Sets.Year
            ########## EF_Power (jobs/PJ) — based ONLY on power-producing technologies ##########
            # Numerator: all jobs linked to power techs (Mfg+Constr+OM + non-H2 base supplies)
            jobs_power_total = 0.0
            for r in Emp_Sets.Region, t in power_techs
                div_m_c = (y == 2018) ? 1.0 : (y == 2025 ? 7.0 : 5.0)

                jobs_power_total += JuMP.value(Vars.NewCapacity[y,t,r]) *
                                    Params.EFactorManufacturing[t,y] *
                                    Params.LocalManufacturingFactor[t,y] *
                                    2.15 * (1 - Params.DeclineRate[t,y])^Δmult(y) / div_m_c

                jobs_power_total += JuMP.value(Vars.NewCapacity[y,t,r]) *
                                    Params.EFactorConstruction[t,y] *
                                    2.15 * (1 - Params.DeclineRate[t,y])^Δmult(y) / div_m_c

                jobs_power_total += JuMP.value(Vars.TotalCapacityAnnual[y,t,r]) *
                                    Params.EFactorOM[t,y] *
                                    2.15 * (1 - Params.DeclineRate[t,y])^Δmult(y)

                for f in fuels_noAll
                    if f == "H2"; continue; end  # H2 handled separately
                    jobs_power_total += JuMP.value(Vars.UseByTechnologyAnnual[y,t,f,r]) *
                                        Params.EFactorFuelSupply[f,y] *
                                        2.15 * (1 - Params.DeclineRate[t,y])^Δmult(y)
                end
            end

            # Denominator: total POWER produced by power techs (PJ)
            power_prod_pj = sum(JuMP.value(Vars.ProductionByTechnologyAnnual[y,t,"Power",r])
                                for r in Emp_Sets.Region, t in power_techs)

            ef_power = power_prod_pj > 0 ? jobs_power_total / power_prod_pj : 0.0
            println("Year $(y): EF_Power (jobs/PJ, power-tech only) = ",
                    round(ef_power; digits=6))

            # Allocate Fuel="Power" SupplyJobs to ALL techs by their electricity USE (PJ)
            for r in Emp_Sets.Region, t in Emp_Sets.Technology
                use_power = JuMP.value(Vars.UseByTechnologyAnnual[y,t,"Power",r])
                jobs_here = use_power * ef_power  # ef_power already embeds 2.15 & decline
                if jobs_here != 0.0
                    push!(power_rows, (r, t, "Power", "SupplyJobs", scenario, y, jobs_here))
                end
            end

            ########## EF_H2 (jobs/PJ) — based ONLY on electrolysis tech ##########
            if electrolysis !== nothing
                # Numerator: all jobs linked to the electrolysis tech
                jobs_h2_total = 0.0
                for r in Emp_Sets.Region
                    div_m_c = (y == 2018) ? 1.0 : (y == 2025 ? 7.0 : 5.0)

                    # Mfg + Constr + O&M for electrolysis
                    jobs_h2_total += JuMP.value(Vars.NewCapacity[y,electrolysis,r]) *
                                     Params.EFactorManufacturing[electrolysis,y] *
                                     Params.LocalManufacturingFactor[electrolysis,y] *
                                     2.15 * (1 - Params.DeclineRate[electrolysis,y])^Δmult(y) / div_m_c

                    jobs_h2_total += JuMP.value(Vars.NewCapacity[y,electrolysis,r]) *
                                     Params.EFactorConstruction[electrolysis,y] *
                                     2.15 * (1 - Params.DeclineRate[electrolysis,y])^Δmult(y) / div_m_c

                    jobs_h2_total += JuMP.value(Vars.TotalCapacityAnnual[y,electrolysis,r]) *
                                     Params.EFactorOM[electrolysis,y] *
                                     2.15 * (1 - Params.DeclineRate[electrolysis,y])^Δmult(y)

                    # Fuel-supply jobs from inputs to electrolysis
                    for f in fuels_noAll
                        if f == "H2"; continue; end  # H2 is an output here
                        if f == "Power"
                            # Electricity input → use EF_Power (already includes 2.15 & decline)
                            use_p = JuMP.value(Vars.UseByTechnologyAnnual[y,electrolysis,"Power",r])
                            jobs_h2_total += use_p * ef_power
                        else
                            jobs_h2_total += JuMP.value(Vars.UseByTechnologyAnnual[y,electrolysis,f,r]) *
                                             Params.EFactorFuelSupply[f,y] *
                                             2.15 * (1 - Params.DeclineRate[electrolysis,y])^Δmult(y)
                        end
                    end
                end

                # Denominator: total H2 produced by electrolysis (PJ)
                h2_pj = sum(JuMP.value(Vars.ProductionByTechnologyAnnual[y,electrolysis,"H2",r])
                            for r in Emp_Sets.Region)

                ef_h2 = h2_pj > 0 ? jobs_h2_total / h2_pj : 0.0
                println("Year $(y): EF_H2 (jobs/PJ, electrolysis only) = ",
                        round(ef_h2; digits=6))

                # Allocate Fuel="H2" SupplyJobs to ALL techs by their H2 USE (PJ)
                for r in Emp_Sets.Region, t in Emp_Sets.Technology
                    use_h2 = JuMP.value(Vars.UseByTechnologyAnnual[y,t,"H2",r])
                    jobs_here = use_h2 * ef_h2  # ef_h2 already embeds 2.15 & decline
                    if jobs_here != 0.0
                        push!(h2_rows, (r, t, "H2", "SupplyJobs", scenario, y, jobs_here))
                    end
                end
            else
                println("Year $(y): EF_H2 skipped — no electrolysis tech found.")
            end
        end

        # Append computed Power & H2 rows
        if nrow(power_rows) > 0
            append!(df, power_rows; promote=true)
        end
        if nrow(h2_rows) > 0
            append!(df, h2_rows; promote=true)
        end

        CSV.write("employment_jobs_all_$(Switch.emissionPathway)_$(Switch.emissionScenario).csv", df)
        return output_energyjobs
    end
end