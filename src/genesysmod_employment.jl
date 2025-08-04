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
function genesysmod_employment(model, Sets, Params, Vars, Emp_Sets, Switch)
    # 0) helpers
    job_types = ("ManufacturingJobs", "ConstructionJobs", "OMJobs", "SupplyJobs")
    scenario  = "$(Switch.emissionPathway)_$(Switch.emissionScenario)"
    Δmult(y)  = YearlyDifferenceMultiplier(y, Emp_Sets)

    # 1) allocate a zero‐AffExpr container: Region × Tech × JobType × Scenario × Year
    output_energyjobs = JuMP.Containers.DenseAxisArray(
        fill(JuMP.AffExpr(), 
             length(Emp_Sets.Region),
             length(Emp_Sets.Technology),
             length(job_types),
             1,
             length(Emp_Sets.Year)
        ),
        Emp_Sets.Region,
        Emp_Sets.Technology,
        job_types,
        (scenario,),
        Emp_Sets.Year
    )

    # 2) if the user isn’t solving endo‐employment, we just fill it by interpolation+formulas
    if Switch.switch_endogenous_employment == 0

        # 2a) interpolate any 0-entries in your year‐only parameters
        for i in 2:(length(Emp_Sets.Year)-1)
            y₋, y, y₊ = Emp_Sets.Year[i-1], Emp_Sets.Year[i], Emp_Sets.Year[i+1]
            for t in Emp_Sets.Technology
                if Params.EFactorConstruction[t,y] == 0
                    Params.EFactorConstruction[t,y] = (Params.EFactorConstruction[t,y₋] + Params.EFactorConstruction[t,y₊]) / 2
                end
                if Params.EFactorOM[t,y] == 0
                    Params.EFactorOM[t,y] = (Params.EFactorOM[t,y₋] + Params.EFactorOM[t,y₊]) / 2
                end
                if Params.EFactorManufacturing[t,y] == 0
                    Params.EFactorManufacturing[t,y] = (Params.EFactorManufacturing[t,y₋] + Params.EFactorManufacturing[t,y₊]) / 2
                end
                if Params.EFactorFuelSupply[t,y] == 0
                    Params.EFactorFuelSupply[t,y] = (Params.EFactorFuelSupply[t,y₋] + Params.EFactorFuelSupply[t,y₊]) / 2
                end
                if Params.EFactorCoalJobs[t,y] == 0
                    Params.EFactorCoalJobs[t,y] = (Params.EFactorCoalJobs[t,y₋] + Params.EFactorCoalJobs[t,y₊]) / 2
                end
                if Params.DeclineRate[t,y] == 0
                    Params.DeclineRate[t,y] = (Params.DeclineRate[t,y₋] + Params.DeclineRate[t,y₊]) / 2
                end
                if Params.LocalManufacturingFactor[t,y] == 0
                    Params.LocalManufacturingFactor[t,y] = (Params.LocalManufacturingFactor[t,y₋] + Params.LocalManufacturingFactor[t,y₊]) / 2
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

        # 2b) now fill every (r,t,job,scenario,y) slot with a JuMP AffExpr
        for r in Emp_Sets.Region, t in Emp_Sets.Technology, y in Emp_Sets.Year
            # Manufacturing jobs
            output_energyjobs[r,t,"ManufacturingJobs",scenario,y] = sum(
                Vars.NewCapacity[y,t,r]
              * Params.EFactorManufacturing[t,y]
              * Params.LocalManufacturingFactor[t,y]
              * 2.15
              * (1 - Params.DeclineRate[t,y])^YearlyDifferenceMultiplier(y, Emp_Sets)
            )

            # Construction jobs
            output_energyjobs[r,t,"ConstructionJobs",scenario,y] = (sum(
                Vars.NewCapacity[y,t,r]
                
              * Params.EFactorConstruction[t,y]
              * 2.15
              * (1 - Params.DeclineRate[t,y])^YearlyDifferenceMultiplier(y, Emp_Sets))/Params.ConstructionTime[t,y]
            )

            # O&M jobs
            output_energyjobs[r,t,"OMJobs",scenario,y] = sum(
                Vars.TotalCapacityAnnual[y,t,r]
              * Params.EFactorOM[t,y]
              * 2.15
              * (1 - Params.DeclineRate[t,y])^YearlyDifferenceMultiplier(y, Emp_Sets)
            )

            # Fuel-supply jobs (note: uses the model’s Sets.Fuel)
            output_energyjobs[r,t,"SupplyJobs",scenario,y] = (sum(
                Vars.UseByTechnologyAnnual[y,t,f,r] for f in Sets.Fuel)
              * Params.EFactorFuelSupply[t,y]
              * 2.15
              * (1 - Params.DeclineRate[t,y])^YearlyDifferenceMultiplier(y, Emp_Sets)
              #for _se in Sets.Sector
            )

        end
        # 2c) special Coal_Heat supply job formula
        # c) Coal-Heat special — replace this entire for-loop:
        for r in Emp_Sets.Region, y in Emp_Sets.Year
            # sum total annual coal-heat use across the three heat technologies:
            annual_coal_heat = 
                Vars.UseByTechnologyAnnual[y, "HLI_Hardcoal", "Hardcoal", r] +
                Vars.UseByTechnologyAnnual[y, "HMI_HardCoal", "Hardcoal", r] +
                Vars.UseByTechnologyAnnual[y, "HHI_BF_BOF", "Hardcoal", r]

        # apply the coal‐jobs and coal-supply factors
          #output_energyjobs[r, "Coal_Heat", "SupplyJobs", scenario, y] =
           # - annual_coal_heat* Params.EFactorCoalJobs["Coal_Heat", y]* Params.CoalSupply[r, y]
        end
    end
    if occursin("INFEASIBLE",string(termination_status(model)))
        println("Hello")
    else
        df = convert_jump_container_to_df(output_energyjobs;
            dim_names=[:Region, :Technology, :JobType, :Scenario, :Year],
            value_col=:Jobs)
        #show(df, allrows=true, allcols=true)        # print it all
        CSV.write("employment_jobs_$(Switch.emissionPathway)_$(Switch.emissionScenario).csv", df)        # save to disk
        return output_energyjobs
    end
end
