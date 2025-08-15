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
function genesysmod_levelizedcosts(model, Sets, Params, VarPar, Vars, Switch, Settings,
                                   z_fuelcosts, LoopSetOutput, LoopSetInput, extr_str)

    # ---------------- configuration ----------------
    TierThree = ["Gas_Bio","Biofuel","Gas_Synth"]
    TierFive  = ["Mobility_Passenger","Mobility_Freight","Heat_Buildings",
                 "Heat_Low_Industrial","Heat_Medium_Industrial","Heat_High_Industrial"]

    Resources = ["Hardcoal","Lignite","Gas_Natural","Oil","Nuclear","Biomass","H2"]
    ResourceTechnologies = ["R_Grass","R_Wood","R_Residues","R_Paper_Cardboard","R_Roundwood",
                            "R_Biogas","Z_Import_Hardcoal","R_Coal_Hardcoal","R_Coal_Lignite",
                            "Z_Import_Oil","Z_Import_Gas","R_Nuclear","R_Gas","R_Oil"]

    # MATERIAL / NON-ENERGY fuels (native units)
    NonEnergyFuels = Set(["Crude_Steel","DR_Iron","DR_Iron_H2","Scrap_Steel","Iron_Ore"])

    # Upstream→downstream order (Scrap_Steel BEFORE Crude_Steel)
    MATERIAL_ORDER = ["DR_Iron_H2","DR_Iron","Scrap_Steel","Crude_Steel","Iron_Ore"]
    MATERIAL_ORDER = [f for f in MATERIAL_ORDER if f in Sets.Fuel]

    Time = 0:110

    # --------------- containers ---------------------
    levelizedcosts   = JuMP.Containers.DenseAxisArray(
        zeros(length(Sets.Region_full),length(Sets.Technology),length(Sets.Fuel),
              length(Sets.Mode_of_operation),length(Sets.Year)),
        Sets.Region_full, Sets.Technology, Sets.Fuel, Sets.Mode_of_operation, Sets.Year)

    capitalcosts     = JuMP.Containers.DenseAxisArray(
        zeros(length(Sets.Region_full),length(Sets.Technology),length(Sets.Fuel),
              length(Sets.Mode_of_operation),length(Sets.Year)),
        Sets.Region_full, Sets.Technology, Sets.Fuel, Sets.Mode_of_operation, Sets.Year)

    omcosts          = JuMP.Containers.DenseAxisArray(
        zeros(length(Sets.Region_full),length(Sets.Technology),length(Sets.Fuel),
              length(Sets.Mode_of_operation),length(Sets.Year)),
        Sets.Region_full, Sets.Technology, Sets.Fuel, Sets.Mode_of_operation, Sets.Year)

    discountedfuelcosts = JuMP.Containers.DenseAxisArray(
        zeros(length(Sets.Region_full),length(Sets.Technology),length(Sets.Fuel),
              length(Sets.Mode_of_operation),length(Sets.Year)),
        Sets.Region_full, Sets.Technology, Sets.Fuel, Sets.Mode_of_operation, Sets.Year)

    emissioncosts    = JuMP.Containers.DenseAxisArray(
        zeros(length(Sets.Region_full),length(Sets.Technology),length(Sets.Fuel),
              length(Sets.Mode_of_operation),length(Sets.Year)),
        Sets.Region_full, Sets.Technology, Sets.Fuel, Sets.Mode_of_operation, Sets.Year)

    fuelcosts        = JuMP.Containers.DenseAxisArray(
        zeros(length(Sets.Region_full),length(Sets.Technology),length(Sets.Fuel),
              length(Sets.Mode_of_operation),length(Sets.Year)),
        Sets.Region_full, Sets.Technology, Sets.Fuel, Sets.Mode_of_operation, Sets.Year)

    resourcecosts    = JuMP.Containers.DenseAxisArray(
        zeros(length(Sets.Region_full),length(Sets.Fuel),length(Sets.Year)),
        Sets.Region_full, Sets.Fuel, Sets.Year)

    AnnualTechnologyProductionByMode = JuMP.Containers.DenseAxisArray(
        zeros(length(Sets.Region_full),length(Sets.Technology),length(Sets.Mode_of_operation),
              length(Sets.Fuel),length(Sets.Year)),
        Sets.Region_full, Sets.Technology, Sets.Mode_of_operation, Sets.Fuel, Sets.Year)

    RegionalEmissionContentPerFuel = JuMP.Containers.DenseAxisArray(
        zeros(length(Sets.Year),length(Sets.Region_full),length(Sets.Fuel),length(Sets.Emission)),
        Sets.Year, Sets.Region_full, Sets.Fuel, Sets.Emission)

    maxgeneration    = JuMP.Containers.DenseAxisArray(
        zeros(length(Sets.Region_full),length(Sets.Technology),length(Sets.Year),
              length(Sets.Mode_of_operation),length(Sets.Fuel)),
        Sets.Region_full, Sets.Technology, Sets.Year, Sets.Mode_of_operation, Sets.Fuel)

    AnnualProduction = VarPar.ProductionAnnual

    # --------------- helpers -----------------------
    safe_oar(r,t,f,m,y) = (try Params.OutputActivityRatio[r,t,f,m,y] catch; 0.0 end)
    safe_iar(r,t,f,m,y) = (try Params.InputActivityRatio[r,t,f,m,y]  catch; 0.0 end)
    safe_avail(r,t,y)   = (try Params.AvailabilityFactor[r,t,y]       catch; 0.0 end)
    safe_capfac_sum(r,t,y) = sum(
        (try Params.CapacityFactor[r,t,l,y] catch; 0.0 end) * Params.YearSplit[l,y]
        for l ∈ Sets.Timeslice;
        init=0.0
    )

    # aggregate to annual by mode
    for r ∈ Sets.Region_full, t ∈ Sets.Technology, m ∈ Sets.Mode_of_operation,
        f ∈ Sets.Fuel, y ∈ Sets.Year
        AnnualTechnologyProductionByMode[r,t,m,f,y] =
            sum(VarPar.RateOfProductionByTechnologyByMode[y,l,t,m,f,r]*Params.YearSplit[l,y]
                for l ∈ Sets.Timeslice; init=0.0)
    end

    # shadow carbon price (fallback to penalty → 15)
    CarbonPrice = JuMP.Containers.DenseAxisArray(
        zeros(length(Sets.Region_full),length(Sets.Emission),length(Sets.Year)),
        Sets.Region_full, Sets.Emission, Sets.Year)

    for r ∈ Sets.Region_full, y ∈ Sets.Year, e ∈ Sets.Emission
        c8 = JuMP.constraint_by_name(model, "E8_RegionalAnnualEmissionsLimit|$(y)|$(e)|$(r)")
        if c8 !== nothing
            CarbonPrice[r,e,y] = -JuMP.dual(c8)
        end
        if CarbonPrice[r,e,y] == 0
            c9 = JuMP.constraint_by_name(model, "E9_AnnualEmissionsLimit|$(y)|$(e)")
            if c9 !== nothing
                CarbonPrice[r,e,y] = -JuMP.dual(c9)
            end
        end
        if CarbonPrice[r,e,y] == 0
            CarbonPrice[r,e,y] = Params.EmissionsPenalty[r,e,y]
        end
        if CarbonPrice[r,e,y] == 0
            CarbonPrice[r,e,y] = 15.0
        end
    end

    SectorEmissions, EmissionIntensity =
        genesysmod_emissionintensity(model, Sets, Params, VarPar, Vars, TierFive,
                                     LoopSetOutput, LoopSetInput)

    for y ∈ Sets.Year, r ∈ Sets.Region_full, e ∈ Sets.Emission
        for f ∈ Sets.Fuel
            RegionalEmissionContentPerFuel[y,r,f,e] = Params.EmissionContentPerFuel[f,e]
        end
        RegionalEmissionContentPerFuel[y,r,"Power",e] = EmissionIntensity[y,r,"Power",e]
    end

    # ---------------- prelims ----------------------
    for r ∈ Sets.Region_full, y ∈ Sets.Year
        # max generation envelope
        for f ∈ Sets.Fuel
            for (t,m) ∈ get(LoopSetOutput, (r,f,y), Vector{Tuple{Any,Any}}())
                maxgeneration[r,t,y,m,f] =
                    safe_capfac_sum(r,t,y) *
                    maximum((safe_avail(r,t,yy) for yy ∈ Sets.Year); init=0.0) *
                    Params.CapacityToActivityUnit[t] * safe_oar(r,t,f,m,y)
            end
        end

        # base resource prices
        for f ∈ Resources
            if value(AnnualProduction[y,f,r]) > 0
                denom = value(AnnualProduction[y,f,r])
                if denom > 0
                    resourcecosts[r,f,y] =
                        sum(Params.VariableCost[r,t,1,y] *
                            value(Vars.ProductionByTechnologyAnnual[y,t,f,r]) / denom
                            for t ∈ ResourceTechnologies; init=0.0)
                end
            end
            if resourcecosts[r,f,y] == 0
                resourcecosts[r,f,y] = z_fuelcosts[f,y,r]
            end
        end

        # first pass cost components (no discount split yet)
        for f ∈ Sets.Fuel
            for (t,m) ∈ get(LoopSetOutput, (r,f,y), Vector{Tuple{Any,Any}}())
                if safe_oar(r,t,f,m,y) > 0
                    denom_oar = safe_oar(r,t,f,m,y)

                    fuelcosts[r,t,f,m,y] =
                        sum(safe_iar(r,t,ff,m,y)*resourcecosts[r,ff,y] for ff ∈ Sets.Fuel; init=0.0) / denom_oar

                    emissioncosts[r,t,f,m,y] =
                        sum(safe_iar(r,t,ff,m,y) *
                            sum(Params.EmissionActivityRatio[r,t,m,e,y] *
                                RegionalEmissionContentPerFuel[y,r,ff,e] *
                                CarbonPrice[r,e,y] for e ∈ Sets.Emission; init=0.0)
                            for ff ∈ Sets.Fuel; init=0.0) / denom_oar

                    if maxgeneration[r,t,y,m,f] > 0
                        denom_gen = sum((maxgeneration[r,t,y,m,f] / ((1+Settings.GeneralDiscountRate[r])^o))
                                        for o ∈ Time if o <= Params.OperationalLife[t]; init=0.0)
                        if denom_gen > 0
                            capitalcosts[r,t,f,m,y] = Params.CapitalCost[r,t,y] / denom_gen
                            omcosts[r,t,f,m,y] =
                                (sum(((Params.FixedCost[r,t,y] +
                                       (Params.VariableCost[r,t,m,y])*maxgeneration[r,t,y,m,f]) /
                                      ((1+Settings.GeneralDiscountRate[r])^o))
                                     for o ∈ Time if o <= Params.OperationalLife[t]; init=0.0)) / denom_gen
                        end
                    end
                end
            end
        end
    end

    # --------------- Tier A/B/C/D (energy chains) ---------------
    # Power (first pass)
    for r ∈ Sets.Region_full, y ∈ Sets.Year
        for (t,m) ∈ get(LoopSetOutput, (r,"Power",y), Vector{Tuple{Any,Any}}())
            if safe_oar(r,t,"Power",m,y) > 0 && maxgeneration[r,t,y,m,"Power"] > 0
                denom = sum((maxgeneration[r,t,y,m,"Power"]/((1+Settings.GeneralDiscountRate[r])^o))
                            for o ∈ Time if o <= Params.OperationalLife[t]; init=0.0)
                if denom > 0
                    discountedfuelcosts[r,t,"Power",m,y] =
                        (sum((((fuelcosts[r,t,"Power",m,y])*maxgeneration[r,t,y,m,"Power"]) /
                              ((1+Settings.GeneralDiscountRate[r])^o))
                             for o ∈ Time if o <= Params.OperationalLife[t]; init=0.0)) / denom
                end
            end
            levelizedcosts[r,t,"Power",m,y] =
                capitalcosts[r,t,"Power",m,y] + omcosts[r,t,"Power",m,y] +
                discountedfuelcosts[r,t,"Power",m,y] + emissioncosts[r,t,"Power",m,y]
        end

        if value(AnnualProduction[y,"Power",r]) > 0
            denom = sum(AnnualTechnologyProductionByMode[r,tt,1,"Power",y] for tt ∈ Sets.Technology; init=0.0)
            if denom > 0
                resourcecosts[r,"Power",y] =
                    sum(levelizedcosts[r,t,"Power",1,y] *
                        AnnualTechnologyProductionByMode[r,t,1,"Power",y] / denom
                        for t ∈ Sets.Technology; init=0.0)
            end
        end
    end

    # Hydrogen
    for r ∈ Sets.Region_full, y ∈ Sets.Year
        for f ∈ Sets.Fuel
            for (t,m) ∈ get(LoopSetOutput, (r,f,y), Vector{Tuple{Any,Any}}())
                if safe_oar(r,t,f,m,y) > 0
                    fuelcosts[r,t,f,m,y] =
                        sum(safe_iar(r,t,fff,m,y)*resourcecosts[r,fff,y] for fff ∈ Sets.Fuel; init=0.0) /
                        safe_oar(r,t,f,m,y)
                end
            end
        end
        for (t,m) ∈ get(LoopSetOutput, (r,"H2",y), Vector{Tuple{Any,Any}}())
            if safe_oar(r,t,"H2",m,y) > 0 && maxgeneration[r,t,y,m,"H2"] > 0
                denom = sum((maxgeneration[r,t,y,m,"H2"]/((1+Settings.GeneralDiscountRate[r])^o))
                            for o ∈ Time if o <= Params.OperationalLife[t]; init=0.0)
                if denom > 0
                    discountedfuelcosts[r,t,"H2",m,y] =
                        (sum((((fuelcosts[r,t,"H2",m,y])*maxgeneration[r,t,y,m,"H2"]) /
                              ((1+Settings.GeneralDiscountRate[r])^o))
                             for o ∈ Time if o <= Params.OperationalLife[t]; init=0.0)) / denom
                    levelizedcosts[r,t,"H2",m,y] =
                        capitalcosts[r,t,"H2",m,y] + omcosts[r,t,"H2",m,y] +
                        discountedfuelcosts[r,t,"H2",m,y] + emissioncosts[r,t,"H2",m,y]
                end
            end
        end
        denomH2 = sum(AnnualTechnologyProductionByMode[r,tt,1,"H2",y] for tt ∈ Sets.Technology; init=0.0)
        if denomH2 > 0
            resourcecosts[r,"H2",y] =
                sum(levelizedcosts[r,t,"H2",1,y] *
                    AnnualTechnologyProductionByMode[r,t,1,"H2",y] / denomH2
                    for t ∈ Sets.Technology; init=0.0)
        end
    end

    # SNG/Biofuels (TierThree)
    for r ∈ Sets.Region_full, y ∈ Sets.Year
        for f ∈ Sets.Fuel
            for (t,m) ∈ get(LoopSetOutput, (r,f,y), Vector{Tuple{Any,Any}}())
                if safe_oar(r,t,f,m,y) > 0
                    fuelcosts[r,t,f,m,y] =
                        sum(safe_iar(r,t,fff,m,y)*resourcecosts[r,fff,y] for fff ∈ Sets.Fuel; init=0.0) /
                        safe_oar(r,t,f,m,y)
                end
            end
        end
        for f ∈ TierThree
            for (t,m) ∈ get(LoopSetOutput, (r,f,y), Vector{Tuple{Any,Any}}())
                if maxgeneration[r,t,y,m,f] > 0
                    denom = sum((maxgeneration[r,t,y,m,f]/((1+Settings.GeneralDiscountRate[r])^o))
                                for o ∈ Time if o <= Params.OperationalLife[t]; init=0.0)
                    if denom > 0
                        discountedfuelcosts[r,t,f,m,y] =
                            (sum((((fuelcosts[r,t,f,m,y])*maxgeneration[r,t,y,m,f]) /
                                  ((1+Settings.GeneralDiscountRate[r])^o))
                                 for o ∈ Time if o <= Params.OperationalLife[t]; init=0.0)) / denom
                        levelizedcosts[r,t,f,m,y] =
                            capitalcosts[r,t,f,m,y] + omcosts[r,t,f,m,y] +
                            discountedfuelcosts[r,t,f,m,y] + emissioncosts[r,t,f,m,y]
                    end
                end
            end
        end
        for f ∈ TierThree
            denom = sum(AnnualTechnologyProductionByMode[r,tt,1,f,y] for tt ∈ Sets.Technology; init=0.0)
            if denom > 0
                resourcecosts[r,f,y] =
                    sum(levelizedcosts[r,t,f,1,y] *
                        AnnualTechnologyProductionByMode[r,t,1,f,y] / denom
                        for t ∈ Sets.Technology; init=0.0)
            end
        end
        if resourcecosts[r,"Gas_Bio",y] == 0
            try
                resourcecosts[r,"Gas_Bio",y] =
                    resourcecosts[r,"Biomass",y] * safe_iar(r,"X_Methanation","Biomass",2,y)
            catch
            end
        end
    end

    # Power (re-electrification + storages)
    for r ∈ Sets.Region_full, y ∈ Sets.Year
        for f ∈ Sets.Fuel
            for (t,m) ∈ get(LoopSetOutput, (r,f,y), Vector{Tuple{Any,Any}}())
                if safe_oar(r,t,f,m,y) > 0
                    fuelcosts[r,t,f,m,y] =
                        sum(safe_iar(r,t,fff,m,y)*resourcecosts[r,fff,y] for fff ∈ Sets.Fuel; init=0.0) /
                        safe_oar(r,t,f,m,y)
                end
            end
            if haskey(Params.TagTechnologyToSubsets,"StorageDummies")
                for t ∈ Params.TagTechnologyToSubsets["StorageDummies"]
                    if safe_oar(r,t,f,2,y) > 0
                        denom = safe_oar(r,t,f,2,y) *
                                sum(((try Params.TechnologyToStorage[t,s,1,y] catch; 0.0 end)^2)
                                    for s ∈ Sets.Storage; init=0.0)
                        if denom > 0
                            fuelcosts[r,t,f,1,y] =
                                sum(safe_iar(r,t,fff,1,y)*resourcecosts[r,fff,y] for fff ∈ Sets.Fuel; init=0.0) /
                                denom
                        end
                    end
                end
            end
        end
        for (t,m) ∈ get(LoopSetOutput, (r,"Power",y), Vector{Tuple{Any,Any}}())
            if safe_oar(r,t,"Power",m,y) > 0 && maxgeneration[r,t,y,m,"Power"] > 0
                denom = sum((maxgeneration[r,t,y,m,"Power"]/((1+Settings.GeneralDiscountRate[r])^o))
                            for o ∈ Time if o <= Params.OperationalLife[t]; init=0.0)
                if denom > 0
                    discountedfuelcosts[r,t,"Power",m,y] =
                        (sum((((fuelcosts[r,t,"Power",m,y])*maxgeneration[r,t,y,m,"Power"]) /
                              ((1+Settings.GeneralDiscountRate[r])^o))
                             for o ∈ Time if o <= Params.OperationalLife[t]; init=0.0)) / denom
                    levelizedcosts[r,t,"Power",m,y] =
                        capitalcosts[r,t,"Power",m,y] + omcosts[r,t,"Power",m,y] +
                        discountedfuelcosts[r,t,"Power",m,y] + emissioncosts[r,t,"Power",m,y]
                end
            end
        end
        denom = sum(AnnualTechnologyProductionByMode[r,tt,mm,"Power",y]
                    for tt ∈ Sets.Technology, mm ∈ Sets.Mode_of_operation; init=0.0)
        if denom > 0
            resourcecosts[r,"Power",y] =
                sum(levelizedcosts[r,t,"Power",m,y] *
                    AnnualTechnologyProductionByMode[r,t,m,"Power",y] / denom
                    for t ∈ Sets.Technology, m ∈ Sets.Mode_of_operation; init=0.0)
        end
    end

    # resource cost fallbacks
    for r ∈ Sets.Region_full, y ∈ Sets.Year
        if resourcecosts[r,"H2",y] == 0
            try
                resourcecosts[r,"H2",y] = levelizedcosts[r,"Z_Import_H2","H2",1,y]
            catch
            end
        end
        if resourcecosts[r,"Biofuel",y] == 0
            try
                resourcecosts[r,"Biofuel",y] = levelizedcosts[r,"X_Biofuel","Biofuel",1,y]
            catch
            end
        end
        try
            resourcecosts[r,"Gas_Synth",y] = levelizedcosts[r,"X_Methanation","Gas_Synth",1,y]
        catch
        end
    end

    # ---------------- Tier M: Materials --------------------------
    # compute costs in native units (no ×3.6)
    for r ∈ Sets.Region_full, y ∈ Sets.Year
        for f ∈ MATERIAL_ORDER
            # refresh fuel inputs with latest resourcecosts
            for (t,m) ∈ get(LoopSetOutput, (r,f,y), Vector{Tuple{Any,Any}}())
                if safe_oar(r,t,f,m,y) > 0
                    fuelcosts[r,t,f,m,y] =
                        sum(safe_iar(r,t,ff,m,y)*resourcecosts[r,ff,y] for ff ∈ Sets.Fuel; init=0.0) /
                        safe_oar(r,t,f,m,y)
                end
            end
            # per-tech levelized (native)
            for (t,m) ∈ get(LoopSetOutput, (r,f,y), Vector{Tuple{Any,Any}}())
                if safe_oar(r,t,f,m,y) > 0 && maxgeneration[r,t,y,m,f] > 0
                    denom = sum((maxgeneration[r,t,y,m,f]/((1+Settings.GeneralDiscountRate[r])^o))
                                for o ∈ Time if o <= Params.OperationalLife[t]; init=0.0)
                    if denom > 0
                        discountedfuelcosts[r,t,f,m,y] =
                            (sum((((fuelcosts[r,t,f,m,y])*maxgeneration[r,t,y,m,f]) /
                                  ((1+Settings.GeneralDiscountRate[r])^o))
                                 for o ∈ Time if o <= Params.OperationalLife[t]; init=0.0)) / denom
                        levelizedcosts[r,t,f,m,y] =
                            capitalcosts[r,t,f,m,y] + omcosts[r,t,f,m,y] +
                            discountedfuelcosts[r,t,f,m,y] + emissioncosts[r,t,f,m,y]
                    end
                end
            end
            # production-weighted average resourcecost in native units
            denomM = sum(AnnualTechnologyProductionByMode[r,tt,mm,f,y]
                         for tt ∈ Sets.Technology, mm ∈ Sets.Mode_of_operation; init=0.0)
            if denomM > 0
                resourcecosts[r,f,y] =
                    sum(levelizedcosts[r,t,f,m,y] *
                        AnnualTechnologyProductionByMode[r,t,m,f,y] / denomM
                        for t ∈ Sets.Technology, m ∈ Sets.Mode_of_operation; init=0.0)
            end
        end
    end

    # ---------------- Tier N: Reprice techs that use materials ----------------
    # Ensure EAF (and any other tech consuming materials) picks up material input costs.
    for r ∈ Sets.Region_full, y ∈ Sets.Year, f_out ∈ Sets.Fuel
        for (t,m) ∈ get(LoopSetOutput, (r, f_out, y), Vector{Tuple{Any,Any}}())
            if safe_oar(r,t,f_out,m,y) > 0
                uses_material = any(fff -> (fff in NonEnergyFuels) && (safe_iar(r,t,fff,m,y) > 0.0), Sets.Fuel)
                if uses_material
                    denom = safe_oar(r,t,f_out,m,y)
                    fuelcosts[r,t,f_out,m,y] =
                        (denom > 0.0) ?
                        sum(safe_iar(r,t,fff,m,y) * resourcecosts[r,fff,y] for fff ∈ Sets.Fuel; init=0.0) / denom :
                        0.0

                    if maxgeneration[r,t,y,m,f_out] > 0.0
                        denom_gen = sum((maxgeneration[r,t,y,m,f_out] / ((1+Settings.GeneralDiscountRate[r])^o))
                                        for o ∈ Time if o <= Params.OperationalLife[t]; init=0.0)
                        if denom_gen > 0.0
                            discountedfuelcosts[r,t,f_out,m,y] =
                                (sum(((fuelcosts[r,t,f_out,m,y] * maxgeneration[r,t,y,m,f_out]) /
                                      ((1+Settings.GeneralDiscountRate[r])^o))
                                     for o ∈ Time if o <= Params.OperationalLife[t]; init=0.0)) / denom_gen
                        else
                            discountedfuelcosts[r,t,f_out,m,y] = 0.0
                        end
                    end

                    # total (no re-scaling here; energy/material scaling already applied)
                    levelizedcosts[r,t,f_out,m,y] =
                        capitalcosts[r,t,f_out,m,y] +
                        omcosts[r,t,f_out,m,y] +
                        discountedfuelcosts[r,t,f_out,m,y] +
                        emissioncosts[r,t,f_out,m,y]
                end
            end
        end
    end
    # --------------------------------------------------------------------------

    # ------------- convert to EUR/MWh for ENERGY fuels ----------
    TransportSubset = haskey(Params.TagTechnologyToSubsets,"Transport") ?
                      Set(Params.TagTechnologyToSubsets["Transport"]) : Set{String}()
    for r ∈ Sets.Region_full, y ∈ Sets.Year, t ∈ Sets.Technology, m ∈ Sets.Mode_of_operation
        for f ∈ Sets.Fuel
            if !(f in NonEnergyFuels) && !(f in TransportSubset)
                capitalcosts[r,t,f,m,y]        *= 3.6
                omcosts[r,t,f,m,y]             *= 3.6
                discountedfuelcosts[r,t,f,m,y] *= 3.6
                emissioncosts[r,t,f,m,y]       *= 3.6
                levelizedcosts[r,t,f,m,y]      *= 3.6
            end
        end
    end

    # ---------------- outputs (fuelcosts) ------------------------
    energy_fuels = [f for f ∈ Sets.Fuel if !(f in NonEnergyFuels)]
    fc1 = convert_jump_container_to_df(resourcecosts[:,energy_fuels,:];
                                       dim_names=[:Region, :Fuel, :Year])
    fc1[!,:Variable] .= "Fuel Costs in MEUR/PJ"

    fc2 = convert_jump_container_to_df((resourcecosts[:,energy_fuels,:].*3.6);
                                       dim_names=[:Region, :Fuel, :Year])
    fc2[!,:Variable] .= "Fuel Costs in EUR/MWh"

    output_fuelcosts = vcat(fc1, fc2; cols=:union)

    # Total rows for energy fuels (production-weighted)
    for y ∈ Sets.Year
        for f ∈ energy_fuels
            prodsum = sum(VarPar.ProductionAnnual[y,f,r] for r ∈ Sets.Region_full; init=0.0)
            if prodsum > 0
                avgMEURPJ = sum(resourcecosts[r,f,y]*VarPar.ProductionAnnual[y,f,r]
                                for r ∈ Sets.Region_full; init=0.0) / prodsum
                push!(output_fuelcosts, ("Total", f, y, avgMEURPJ, "Fuel Costs in MEUR/PJ"))
                push!(output_fuelcosts, ("Total", f, y, avgMEURPJ*3.6, "Fuel Costs in EUR/MWh"))
            elseif any(resourcecosts[r,f,y] != 0 for r ∈ Sets.Region_full)
                avgMEURPJ = sum(resourcecosts[r,f,y] for r ∈ Sets.Region_full; init=0.0) / length(Sets.Region_full)
                push!(output_fuelcosts, ("Total", f, y, avgMEURPJ, "Fuel Costs in MEUR/PJ"))
                push!(output_fuelcosts, ("Total", f, y, avgMEURPJ*3.6, "Fuel Costs in EUR/MWh"))
            end
        end
    end
    rename!(output_fuelcosts, [:Region, :Fuel, :Year, :Value, :Variable])

    # ---------------- outputs (cost components) ------------------
    function df_cost(container; nm)
        df = convert_jump_container_to_df(container;
                dim_names=[:Region, :Technology, :Fuel, :Mode_of_operation, :Year])
        df[!,:Variable] .= nm
        return df
    end

    capex_df       = df_cost(capitalcosts;        nm="Capex")
    oem_df         = df_cost(omcosts;             nm="OandM")
    fuelcosts_df   = df_cost(discountedfuelcosts; nm="Fuelcosts")
    emissions_df   = df_cost(emissioncosts;       nm="Emissions")
    totallevel_df  = df_cost(levelizedcosts;      nm="TotalLevelized")

    # also write a "without emissions" total
    total_wo_em = JuMP.Containers.DenseAxisArray(
        zeros(length(Sets.Region_full),length(Sets.Technology),length(Sets.Fuel),
              length(Sets.Mode_of_operation),length(Sets.Year)),
        Sets.Region_full, Sets.Technology, Sets.Fuel, Sets.Mode_of_operation, Sets.Year)
    for r ∈ Sets.Region_full, t ∈ Sets.Technology, f ∈ Sets.Fuel, m ∈ Sets.Mode_of_operation, y ∈ Sets.Year
        total_wo_em[r,t,f,m,y] = capitalcosts[r,t,f,m,y] + omcosts[r,t,f,m,y] + discountedfuelcosts[r,t,f,m,y]
    end
    total_wo_em_df = df_cost(total_wo_em; nm="TotalLevelized_woEmissions")

    output_costs = vcat(capex_df, oem_df, fuelcosts_df, emissions_df, totallevel_df, total_wo_em_df; cols=:union)

    # ---------------- outputs (emission intensity) ---------------
    output_emissionintensity = convert_jump_container_to_df(
        EmissionIntensity[:,:,"Power",:]; dim_names=[:Year, :Region, :Emission])
    output_emissionintensity[!,:Fuel] .= "Power"

    # ---------------- EAF aggregation (native units) -------------
    TECH_EAF   = "IND_Steel_2_EAF"
    FUEL_STEEL = "Crude_Steel"

    eaf_cols = [:Region, :Year, :Variable, :Value, :Unit]
    eaf_df   = DataFrame([name => Any[] for name in eaf_cols])

    for r ∈ Sets.Region_full, y ∈ Sets.Year
        denom = sum(AnnualTechnologyProductionByMode[r,TECH_EAF,m,FUEL_STEEL,y]
                    for m ∈ Sets.Mode_of_operation; init=0.0)
        if denom > 0
            cap  = sum(capitalcosts[r,TECH_EAF,FUEL_STEEL,m,y]        * AnnualTechnologyProductionByMode[r,TECH_EAF,m,FUEL_STEEL,y] for m ∈ Sets.Mode_of_operation) / denom
            oam  = sum(omcosts[r,TECH_EAF,FUEL_STEEL,m,y]             * AnnualTechnologyProductionByMode[r,TECH_EAF,m,FUEL_STEEL,y] for m ∈ Sets.Mode_of_operation) / denom
            fcs  = sum(discountedfuelcosts[r,TECH_EAF,FUEL_STEEL,m,y] * AnnualTechnologyProductionByMode[r,TECH_EAF,m,FUEL_STEEL,y] for m ∈ Sets.Mode_of_operation) / denom
            emc  = sum(emissioncosts[r,TECH_EAF,FUEL_STEEL,m,y]       * AnnualTechnologyProductionByMode[r,TECH_EAF,m,FUEL_STEEL,y] for m ∈ Sets.Mode_of_operation) / denom
            tot  = sum(levelizedcosts[r,TECH_EAF,FUEL_STEEL,m,y]      * AnnualTechnologyProductionByMode[r,TECH_EAF,m,FUEL_STEEL,y] for m ∈ Sets.Mode_of_operation) / denom
            tot0 = cap + oam + fcs
            unit_str = "per unit of Crude_Steel (native unit)"
            push!(eaf_df, (Region=r, Year=y, Variable="Capex",                  Value=cap,  Unit=unit_str))
            push!(eaf_df, (Region=r, Year=y, Variable="OandM",                  Value=oam,  Unit=unit_str))
            push!(eaf_df, (Region=r, Year=y, Variable="Fuelcosts",              Value=fcs,  Unit=unit_str))
            push!(eaf_df, (Region=r, Year=y, Variable="Emissions",              Value=emc,  Unit=unit_str))
            push!(eaf_df, (Region=r, Year=y, Variable="TotalLevelized",         Value=tot,  Unit=unit_str))
            push!(eaf_df, (Region=r, Year=y, Variable="TotalLevelized_woEmis",  Value=tot0, Unit=unit_str))
        end
    end

    # ---------------- materials CSV (native) ---------------------
    material_rows = DataFrame(Region=String[], Fuel=String[], Year=Int[], Value=Float64[],
                              Variable=String[])
    for r ∈ Sets.Region_full, y ∈ Sets.Year
        for f ∈ Sets.Fuel
            if f in NonEnergyFuels && resourcecosts[r,f,y] != 0
                push!(material_rows, (r, f, y, resourcecosts[r,f,y], "Material Costs (native units)"))
                # "without emissions" (production-weighted subtraction of emission costs)
                num = sum(emissioncosts[r,t,f,m,y]*AnnualTechnologyProductionByMode[r,t,m,f,y]
                          for t ∈ Sets.Technology, m ∈ Sets.Mode_of_operation; init=0.0)
                den = sum(AnnualTechnologyProductionByMode[r,t,m,f,y]
                          for t ∈ Sets.Technology, m ∈ Sets.Mode_of_operation; init=0.0)
                wo_em = resourcecosts[r,f,y] - (den > 0 ? num/den : 0.0)
                push!(material_rows, (r, f, y, wo_em, "Material Costs wo Emissions (native)"))
            end
        end
    end

    # --------- add production-weighted "Total" across regions ----
    for y ∈ Sets.Year
        for f ∈ Sets.Fuel
            if !(f in NonEnergyFuels)
                continue
            end
            denomTot = sum(AnnualTechnologyProductionByMode[r,t,m,f,y]
                           for r ∈ Sets.Region_full, t ∈ Sets.Technology, m ∈ Sets.Mode_of_operation; init=0.0)
            if denomTot > 0
                avg_with = sum(levelizedcosts[r,t,f,m,y] *
                               AnnualTechnologyProductionByMode[r,t,m,f,y]
                               for r ∈ Sets.Region_full, t ∈ Sets.Technology, m ∈ Sets.Mode_of_operation; init=0.0) / denomTot
                avg_woem = sum((capitalcosts[r,t,f,m,y] + omcosts[r,t,f,m,y] + discountedfuelcosts[r,t,f,m,y]) *
                               AnnualTechnologyProductionByMode[r,t,m,f,y]
                               for r ∈ Sets.Region_full, t ∈ Sets.Technology, m ∈ Sets.Mode_of_operation; init=0.0) / denomTot
                push!(material_rows, ("Total", f, y, avg_with, "Material Costs (native units)"))
                push!(material_rows, ("Total", f, y, avg_woem, "Material Costs wo Emissions (native)"))
            end
        end
    end

    # ---------------- write CSVs -------------------
    CSV.write(joinpath(Switch.resultdir,
        "output_costs_$(Switch.model_region)_$(Switch.emissionPathway)_$(Switch.emissionScenario)_$(extr_str).csv"),
        output_costs[output_costs.Value .!= 0,:])

    CSV.write(joinpath(Switch.resultdir,
        "output_fuelcosts_$(Switch.model_region)_$(Switch.emissionPathway)_$(Switch.emissionScenario)_$(extr_str).csv"),
        output_fuelcosts[output_fuelcosts.Value .!= 0,:])

    CSV.write(joinpath(Switch.resultdir,
        "output_emissions_$(Switch.model_region)_$(Switch.emissionPathway)_$(Switch.emissionScenario)_$(extr_str).csv"),
        output_emissionintensity[output_emissionintensity.Value .!= 0,:])

    # EAF detail
    CSV.write(joinpath(
        Switch.resultdir,
        "output_levelizedcosts_EAF_$(Switch.model_region)_$(Switch.emissionPathway)_$(Switch.emissionScenario)_$(extr_str).csv"
    ), eaf_df)

    # Materials (native units) + totals
    CSV.write(joinpath(Switch.resultdir,
        "output_materialcosts_$(Switch.model_region)_$(Switch.emissionPathway)_$(Switch.emissionScenario)_$(extr_str).csv"),
        material_rows)

    return resourcecosts, output_emissionintensity
end

