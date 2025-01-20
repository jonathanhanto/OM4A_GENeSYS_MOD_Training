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
# #############################################################
# test
"""
Internal function used in the run process to set run settings such as dicount rates.
"""
function genesysmod_scenariodata(model, Sets, Params, Vars, Settings, Switch)
  
  for f ∈ Sets.Fuel for r ∈ Sets.Region_full for rr ∈ Sets.Region_full
    Params.TradeCapacityGrowthCosts[r,rr,"Gas_Natural"] = 0.0039
    Params.TradeCapacityGrowthCosts[r,rr,"H2"] = 0.0053
    Params.TradeCapacityGrowthCosts[r,rr,"LSG"] = 0.0053
    Params.TradeCapacityGrowthCosts[r,rr,"LH2"] = 0.0053
  end end end
  
  for y ∈ Sets.Year for f ∈ Sets.Fuel for r ∈ Sets.Region_full for rr ∈ Sets.Region_full  
    Params.GrowthRateTradeCapacity[r,rr,"Gas_Natural",y] = 0.1
    Params.GrowthRateTradeCapacity[r,rr,"H2",y] = 0.15
  end end end end
  ######Availability Factor Gas to zero
  for r ∈ Sets.Region_full 
    Params.AvailabilityFactor[r,"Z_Import_Gas",2018] = 0
  end

    ######Availability Factor Gas to zero
  for r ∈ Sets.Region_full for y ∈ Sets.Year
    Params.AvailabilityFactor[r,"CHP_Coal_Hardcoal_CCS",y] = 0
  end end



  ####################Capacity in 2025 Constraint ##############################################
  ### max cap to stop studden build-up
  #@constraint(model, 
  #sum(Vars.AccumulatedNewCapacity[2018,t,r] for r in Sets.Region_full, t in Sets.Technology) <= 200, 
  #base_name="JH_RES_MAX_CAP_2025")
  ##################TEST for WIND###############
  ################################################
  ##########################################
  #@constraint(model, 
  #  sum(Vars.TotalCapacityAnnual[2030,"RES_Wind_Onshore_Opt", r] for r in Sets.Region_full) >= 25, #13
  #  base_name="JH_Windpush_Total_2030")
  ######

  #@constraint(model, 
  #  sum(Vars.TotalCapacityAnnual[2035,"RES_Wind_Onshore_Opt", r] for r in Sets.Region_full) >= 32, #13
  #  base_name="JH_Windpush_Total_2035")
  ######

  #@constraint(model, 
  #  sum(Vars.TotalCapacityAnnual[2040,"RES_Wind_Onshore_Opt", r] for r in Sets.Region_full) >= 40, #13
  #  base_name="JH_Windpush_Total_2040")#

  #@constraint(model, 
  #  sum(Vars.TotalCapacityAnnual[2045,"RES_Wind_Onshore_Opt", r] for r in Sets.Region_full) >= 50, #13
  #  base_name="JH_Windpush_Total_2045")
  ######
  #@constraint(model, 
  #  sum(Vars.TotalCapacityAnnual[2050,"RES_Wind_Onshore_Opt", r] for r in Sets.Region_full) >= 60, #13
  #  base_name="JH_Windpush_Total_2050")
  ###############################################################################
  #############################################################################
  @constraint(model, 
  sum(Vars.ProductionByTechnologyAnnual[2025,"P_Gas_OCGT","Power", r] for r in Sets.Region_full) >= 15, 
  base_name="JH_Gas_MinProd_Total_2025")
#####
  ############################### Settings Coal production ###############################################
  ### Coal min production to be in line with IRP and current research

  @constraint(model, 
    sum(Vars.ProductionByTechnologyAnnual[2025,"P_Coal_Hardcoal","Power", r] for r in Sets.Region_full) >= 770, 
    base_name="JH_Coal_MinProd_Total_2025")
  #####

   ### Coal min production to be in line with IRP and current ressearc
  @constraint(model, 
    sum(Vars.ProductionByTechnologyAnnual[2030,"P_Coal_Hardcoal","Power", r] for r in Sets.Region_full) >= 300, 
    base_name="JH_Coal_MinProd_Total_2030")
  #####
  ###########################################Coal production lowerlimit in BAU Scenario#########
  if Switch.switch_2degree == 0
      ### Coal min production to be in line with IRP and current ressearc
    @constraint(model, 
    sum(Vars.ProductionByTechnologyAnnual[2030,"P_Coal_Hardcoal","Power", r] for r in Sets.Region_full) >= 680, 
    base_name="JH_Coal_MinProd_Total_2030")
    @constraint(model, 
    sum(Vars.ProductionByTechnologyAnnual[2025,"P_Coal_Hardcoal","Power", r] for r in Sets.Region_full) <= 795, 
    base_name="JH_Coal_MaxProd_Total_2025")
  end



  ############################### Settings 2025 ###############################################
  #####  CHP Biomass Capacity Cap for 2025
  @constraint(model, 
    sum(Vars.ProductionByTechnologyAnnual[2025,"CHP_Biomass_Solid","Power", r] for r in Sets.Region_full) <= 16, 
    base_name="JH_Biomass_MaxProd_Total_2025")
  #####

  #####  Solar Capacity Cap for 2025
   @constraint(model, 
    sum(Vars.TotalCapacityAnnual[2025, t, r] for r in Sets.Region_full, t in Params.TagTechnologyToSubsets["Solar"]) <= 15, #13
    base_name="JH_PvRestriction_Total_2025")
  #####
  #####  Wind Capacity Cap for 2025
  @constraint(model, 
    sum(Vars.TotalCapacityAnnual[2025, t, r] for r in Sets.Region_full, t in Params.TagTechnologyToSubsets["Wind"]) <= 8,  #9
    base_name="JH_WindRestriction_Total_2025")
  #####

  #####  Hydro Capacity Cap for 2025
  @constraint(model, 
    sum(Vars.TotalCapacityAnnual[2025, t, r] for r in Sets.Region_full, t in Params.TagTechnologyToSubsets["Hydro"]) <= 4, 
    base_name="JH_HydroRestriction_Total_2025")
  #####

  ###### P_Gas_OCGT Cap for 2025
  @constraint(model, 
  sum(Vars.TotalCapacityAnnual[2025,"P_Gas_OCGT", r] for r in Sets.Region_full) <= 5, #5
  base_name="JH_Gas_1_Restriction_Total_2025")
  #####
  
  ###### P_Gas_CCGT Cap for 2025
  @constraint(model, 
  sum(Vars.TotalCapacityAnnual[2025,"P_Gas_CCGT", r] for r in Sets.Region_full) <= 0.1, #0.1
  base_name="JH_Gas_2_Restriction_Total_2025")
  #####  

  ###### CHP_Gas_CCGT_Natural Cap for 2025
  @constraint(model, 
  sum(Vars.TotalCapacityAnnual[2025,"CHP_Gas_CCGT_Natural", r] for r in Sets.Region_full) <= 0.1, 
  base_name="JH_Gas_3_Restriction_Total_2025")
  #####  

  ###### P_Gas_Engines Cap for 2025
  @constraint(model, 
  sum(Vars.TotalCapacityAnnual[2025,"P_Gas_Engines", r] for r in Sets.Region_full) <= 0.1, 
  base_name="JH_Gas_4_Restriction_Total_2025")
  #####  

  ###### CHP_Gas_CCGT_Biogas Cap for 2025
  @constraint(model, 
  sum(Vars.TotalCapacityAnnual[2025,"CHP_Gas_CCGT_Biogas", r] for r in Sets.Region_full) <= 0.1, 
  base_name="JH_Gas_5_Restriction_Total_2025")
  #####  

  ###### CHP_Gas_CCGT_SynGas Cap for 2025
  @constraint(model, 
  sum(Vars.TotalCapacityAnnual[2025,"CHP_Gas_CCGT_SynGas", r] for r in Sets.Region_full) <= 0.1, 
  base_name="JH_Gas_6_Restriction_Total_2025")
  #####  

  ###### RES_Wind_Offshore_Transitional Cap for 2025
  @constraint(model, 
  sum(Vars.TotalCapacityAnnual[2025,"P_Wind_Offshore_Transitional", r] for r in Sets.Region_full) <= 0.1, 
  base_name="JH_Wind_offshore_Transitional_Restriction_Total_2025")
  #####  
  ###### RES_Wind_Offshore_Shallow Cap for 2025
  @constraint(model, 
  sum(Vars.TotalCapacityAnnual[2025,"P_Wind_Offshore_Shallow", r] for r in Sets.Region_full) <= 0.1, 
  base_name="JH_Wind_offshore_Shallow_Restriction_Total_2025")
  #####  
  ###### RES_Wind_Offshore_Deep Cap for 2025
  @constraint(model, 
  sum(Vars.TotalCapacityAnnual[2025,"P_Wind_Offshore_Deep", r] for r in Sets.Region_full) <= 0.1, 
  base_name="JH_Wind_offshore_Deep_Restriction_Total_2025")
  #####  

  ######################Caps for 2030##############
  ###### P_Gas_OCGT Cap for 2030

  #@constraint(model,
  #sum(Vars.TotalCapacityAnnual[2030, tech, r] for tech in ["P_Gas_OCGT", "P_Gas_CCGT", "P_Gas_Engines"], r in Sets.Region_full) <= 12, 
  #base_name="JH_Gas_Combined_Restriction_Total_All_Years")

  #@constraint(model,
  #sum(Vars.TotalCapacityAnnual[2035, tech, r] for tech in ["P_Gas_OCGT", "P_Gas_CCGT", "P_Gas_Engines"], r in Sets.Region_full) <= 13, 
  #base_name="JH_Gas_Combined_Restriction_Total_All_Years")

  #@constraint(model,
  #sum(Vars.TotalCapacityAnnual[2040, tech, r] for tech in ["P_Gas_OCGT", "P_Gas_CCGT", "P_Gas_Engines"], r in Sets.Region_full) <= 14, 
  #base_name="JH_Gas_Combined_Restriction_Total_All_Years")

  #@constraint(model,
  #sum(Vars.TotalCapacityAnnual[2045, tech, r] for tech in ["P_Gas_OCGT", "P_Gas_CCGT", "P_Gas_Engines"], r in Sets.Region_full) <= 15, 
  #base_name="JH_Gas_Combined_Restriction_Total_All_Years")

  #@constraint(model,
  #sum(Vars.TotalCapacityAnnual[2050, tech, r] for tech in ["P_Gas_OCGT", "P_Gas_CCGT", "P_Gas_Engines"], r in Sets.Region_full) <= 20, 
  #base_name="JH_Gas_Combined_Restriction_Total_All_Years")


  @constraint(model, 
  sum(Vars.TotalCapacityAnnual[2030,"P_Gas_OCGT", r] for r in Sets.Region_full) <= 12, 
  base_name="JH_Gas_1_Restriction_Total_2030")
  #####
  
  ###### P_Gas_CCGT Cap for 2030
  @constraint(model, 
  sum(Vars.TotalCapacityAnnual[2030,"P_Gas_CCGT", r] for r in Sets.Region_full) <= 0.1, 
  base_name="JH_Gas_2_Restriction_Total_2030")
  #####  

  ###### CHP_Gas_CCGT_Natural Cap for 2030
  @constraint(model, 
  sum(Vars.TotalCapacityAnnual[2030,"CHP_Gas_CCGT_Natural", r] for r in Sets.Region_full) <= 7.5, 
  base_name="JH_Gas_3_Restriction_Total_2030")
  #####  

  ###### P_Gas_Engines Cap for 2030
  @constraint(model, 
  sum(Vars.TotalCapacityAnnual[2030,"P_Gas_Engines", r] for r in Sets.Region_full) <= 0.1, 
  base_name="JH_Gas_4_Restriction_Total_2030")
  #####  

  ###### CHP_Gas_CCGT_Biogas Cap for 2030
  @constraint(model, 
  sum(Vars.TotalCapacityAnnual[2030,"CHP_Gas_CCGT_Biogas", r] for r in Sets.Region_full) <= 0.1, 
  base_name="JH_Gas_5_Restriction_Total_2030")
  #####  

  ###### CHP_Gas_CCGT_SynGas Cap for 2030
  @constraint(model, 
  sum(Vars.TotalCapacityAnnual[2030,"CHP_Gas_CCGT_SynGas", r] for r in Sets.Region_full) <= 0.1, 
  base_name="JH_Gas_6_Restriction_Total_2030")
  #####  

  ###### H2 Export Caps
  @constraint(model, 
  sum(Vars.UseByTechnologyAnnual[2025,"Export_H2","H2", r] for r in Sets.Region_full) == 0, 
  base_name="JG_H2_Export_Cap_2025")
  
  @constraint(model, 
  sum(Vars.UseByTechnologyAnnual[2030,"Export_H2","H2", r] for r in Sets.Region_full) <= 240, 
  base_name="JG_H2_Export_Cap_2030")

  @constraint(model, 
  sum(Vars.UseByTechnologyAnnual[2035,"Export_H2","H2", r] for r in Sets.Region_full) <= 360, 
  base_name="JG_H2_Export_Cap_2035")

  @constraint(model, 
  sum(Vars.UseByTechnologyAnnual[2040,"Export_H2","H2", r] for r in Sets.Region_full) <= 481, 
  base_name="JG_H2_Export_Cap_2040")

  @constraint(model, 
  sum(Vars.UseByTechnologyAnnual[2045,"Export_H2","H2", r] for r in Sets.Region_full) <= 600, 
  base_name="JG_H2_Export_Cap_2045")

  @constraint(model, 
  sum(Vars.UseByTechnologyAnnual[2050,"Export_H2","H2", r] for r in Sets.Region_full) <= 721, 
  base_name="JG_H2_Export_Cap_2050")


  #No new PV technologies in 2018 & 2025
  #tracking not allowed
  for r ∈ Sets.Region_full
    Params.AvailabilityFactor[r,"RES_PV_Utility_HSAT",2018] = 0
    Params.AvailabilityFactor[r,"RES_PV_Utility_THSAT",2018] = 0
    Params.AvailabilityFactor[r,"RES_PV_Utility_VSAT",2018] = 0
    Params.AvailabilityFactor[r,"RES_PV_Utility_DAT",2018] = 0
    Params.AvailabilityFactor[r,"RES_BPV_Utility_HSAT",2018] = 0
    Params.AvailabilityFactor[r,"RES_BPV_Utility_THSAT",2018] = 0
    Params.AvailabilityFactor[r,"RES_BPV_Utility_VSAT",2018] = 0
    Params.AvailabilityFactor[r,"RES_BPV_Utility_DAT",2018] = 0
    #Params.AvailabilityFactor[r,"RES_PV_Utility_HSAT",2025] = 0
    #Params.AvailabilityFactor[r,"RES_PV_Utility_THSAT",2025] = 0
    #Params.AvailabilityFactor[r,"RES_PV_Utility_VSAT",2025] = 0
    #Params.AvailabilityFactor[r,"RES_PV_Utility_DAT",2025] = 0
    #Params.AvailabilityFactor[r,"RES_BPV_Utility_HSAT",2025] = 0
    #Params.AvailabilityFactor[r,"RES_BPV_Utility_THSAT",2025] = 0
    #Params.AvailabilityFactor[r,"RES_BPV_Utility_VSAT",2025] = 0
    #Params.AvailabilityFactor[r,"RES_BPV_Utility_DAT",2025] = 0
  end
  
  #bifacial not allowed
  for r ∈ Sets.Region_full
    Params.AvailabilityFactor[r,"RES_BPV_Utility_HSAT",2018] = 0
    Params.AvailabilityFactor[r,"RES_BPV_Utility_THSAT",2018] = 0
    Params.AvailabilityFactor[r,"RES_BPV_Utility_VSAT",2018] = 0
    Params.AvailabilityFactor[r,"RES_BPV_Utility_DAT",2018] = 0 
    Params.AvailabilityFactor[r,"RES_BPV_Utility_90",2018] = 0
    Params.AvailabilityFactor[r,"RES_BPV_Utility_Opt",2018] = 0
    Params.AvailabilityFactor[r,"RES_BPV_Utility_HSAT",2025] = 0
    Params.AvailabilityFactor[r,"RES_BPV_Utility_THSAT",2025] = 0
    Params.AvailabilityFactor[r,"RES_BPV_Utility_VSAT",2025] = 0
    Params.AvailabilityFactor[r,"RES_BPV_Utility_DAT",2025] = 0 
    Params.AvailabilityFactor[r,"RES_BPV_Utility_90",2025] = 0
    Params.AvailabilityFactor[r,"RES_BPV_Utility_Opt",2025] = 0

  end


  for y ∈ Sets.Year for t ∈ Sets.Technology for r ∈ Sets.Region_full
    if (t in Params.TagTechnologyToSubsets["SolarUtility"]) && (Params.TotalAnnualMaxCapacity[r,t,y] < 999999) && (Params.TotalAnnualMaxCapacity[r,t,y] > 0)
      @constraint(model, sum(Vars.TotalCapacityAnnual[y, tt, r] for tt in Params.TagTechnologyToSubsets["SolarUtility"]) 
      <= Params.TotalAnnualMaxCapacity[r,t,y], base_name="TCC1_SolarUtilityTotalAnnualMaxCapacityConstraint_$(y)_$(t)_$(r)")    
    elseif (Params.TotalAnnualMaxCapacity[r,t,y] < 999999) && (Params.TotalAnnualMaxCapacity[r,t,y] > 0)
      @constraint(model, Vars.TotalCapacityAnnual[y,t,r] <= Params.TotalAnnualMaxCapacity[r,t,y], base_name="TCC1_TotalAnnualMaxCapacityConstraint_$(y)_$(t)_$(r)")
    elseif Params.TotalAnnualMaxCapacity[r,t,y] == 0
      JuMP.fix(Vars.TotalCapacityAnnual[y,t,r],0; force=true)
    end
  end end end

  #Nuclear
  for y ∈ Sets.Year for r ∈ Sets.Region_full
    Params.TotalAnnualMaxCapacity[r,"P_Nuclear",y] = Params.ResidualCapacity[r,"P_Nuclear",y]
  end end

  #Scenrios
  #2degree emission pathway
  if Switch.switch_2degree == 1
    Params.AnnualEmissionLimit["CO2", 2018] = 430   #310old based on climate Tracker South Africa
    Params.AnnualEmissionLimit["CO2", 2025] = 331   #240   ##
    Params.AnnualEmissionLimit["CO2", 2030] = 264   #170 
    Params.AnnualEmissionLimit["CO2", 2035] = 196   #100
    Params.AnnualEmissionLimit["CO2", 2040] = 129    #40
    Params.AnnualEmissionLimit["CO2", 2045] = 62    #20
    Params.AnnualEmissionLimit["CO2", 2050] = 0     #### based on https://carbonbudgetcalculator.com/country.html?country=South%20Africa
  end

  #hydrogen demand
 
  for y ∈ Sets.Year for r ∈ Sets.Region_full
    Params.AvailabilityFactor[r,"Z_Import_H2",y] = 0
  end end

  #tracking not allowed
  if Switch.switch_PVtracking == 0
    for y ∈ Sets.Year for r ∈ Sets.Region_full
      Params.AvailabilityFactor[r,"RES_PV_Utility_HSAT",y] = 0
      Params.AvailabilityFactor[r,"RES_PV_Utility_THSAT",y] = 0
      Params.AvailabilityFactor[r,"RES_PV_Utility_VSAT",y] = 0
      Params.AvailabilityFactor[r,"RES_PV_Utility_DAT",y] = 0
      Params.AvailabilityFactor[r,"RES_BPV_Utility_HSAT",y] = 0
      Params.AvailabilityFactor[r,"RES_BPV_Utility_THSAT",y] = 0
      Params.AvailabilityFactor[r,"RES_BPV_Utility_VSAT",y] = 0
      Params.AvailabilityFactor[r,"RES_BPV_Utility_DAT",y] = 0
    end end
  end

  #bifacial not allowed
  if Switch.switch_bifacialPV == 0
    for y ∈ Sets.Year for r ∈ Sets.Region_full
      Params.AvailabilityFactor[r,"RES_BPV_Utility_HSAT",y] = 0
      Params.AvailabilityFactor[r,"RES_BPV_Utility_THSAT",y] = 0
      Params.AvailabilityFactor[r,"RES_BPV_Utility_VSAT",y] = 0
      Params.AvailabilityFactor[r,"RES_BPV_Utility_DAT",y] = 0
      Params.AvailabilityFactor[r,"RES_BPV_Utility_90",y] = 0
      Params.AvailabilityFactor[r,"RES_BPV_Utility_Opt",y] = 0
    end end
  end


  #h2 Prices
  for r ∈ Sets.Region_full
    Params.VariableCost[r, "Export_H2", 1, 2018] = Switch.switch_h2prices[1]*-8.3240740741
    Params.VariableCost[r, "Export_H2", 1, 2025] = Switch.switch_h2prices[2]*-8.3240740741
    Params.VariableCost[r, "Export_H2", 1, 2030] = Switch.switch_h2prices[3]*-8.3240740741
    Params.VariableCost[r, "Export_H2", 1, 2035] = Switch.switch_h2prices[4]*-8.3240740741
    Params.VariableCost[r, "Export_H2", 1, 2040] = Switch.switch_h2prices[5]*-8.3240740741
    Params.VariableCost[r, "Export_H2", 1, 2045] = Switch.switch_h2prices[6]*-8.3240740741
    Params.VariableCost[r, "Export_H2", 1, 2050] = Switch.switch_h2prices[7]*-8.3240740741
  end
  #JuMP.fix(Vars.ProductionByTechnologyAnnual[2050,"Export_H2","H2","SA-EC"],10; force=true)

  #=@constraint(model, 
  sum(Vars.UseByTechnologyAnnual[y,"Export_H2","H2",r] for y in Sets.Year, r in Sets.Region_full) >= 1000, 
  base_name="KL_ExportTest")=#
  

end

