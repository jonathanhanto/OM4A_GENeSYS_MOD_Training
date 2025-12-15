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
Internal function used in the run process to set run settings such as dicount rates.
"""
function genesysmod_scenariodata(model, Sets, Params, Vars, Settings, Switch)
  if Switch.switch_scenario_1 == 1
    @constraint(model,
    Vars.TotalCapacityAnnual[2025,"P_Oil","UG-C"] <= 0.051,
    base_name="UGANDA_UG_C_P_Oil_2025_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2025,"RES_PV_Utility_Avg","UG-C"] <= 0.041,
    base_name="UGANDA_UG_C_RES_PV_Utility_Avg_2025_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2025,"CHP_Biomass_Solid","UG-C"] <= 0.0421,
    base_name="UGANDA_UG_C_CHP_Biomass_Solid_2025_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2025,"RES_Hydro_Small","UG-W"] <= 0.1784,
    base_name="UGANDA_UG_W_RES_Hydro_Small_2025_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2025,"CHP_Biomass_Solid","UG-W"] <= 0.0346,
    base_name="UGANDA_UG_W_CHP_Biomass_Solid_2025_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2025,"P_Oil","UG-E"] <= 0.0421,
    base_name="UGANDA_UG_E_P_Oil_2025_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2025,"RES_Hydro_Large","UG-E"] <= 0.8131,
    base_name="UGANDA_UG_E_RES_Hydro_Large_2025_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2025,"RES_Hydro_Small","UG-E"] <= 0.02841,
    base_name="UGANDA_UG_E_RES_Hydro_Small_2025_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2025,"RES_PV_Utility_Avg","UG-E"] <= 0.0441,
    base_name="UGANDA_UG_E_RES_PV_Utility_Avg_2025_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2025,"CHP_Biomass_Solid","UG-E"] <= 0.0861,
    base_name="UGANDA_UG_E_CHP_Biomass_Solid_2025_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2025,"RES_Hydro_Small","UG-N"] <= 0.01011,
    base_name="UGANDA_UG_N_RES_Hydro_Small_2025_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2025,"RES_Hydro_Large","UG-N"] <= 0.687211,
    base_name="UGANDA_UG_N_RES_Hydro_Large_2025_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2025,"RES_PV_Utility_Avg","UG-N"] <= 0.0211,
    base_name="UGANDA_UG_N_RES_PV_Utility_Avg_2025_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"P_Oil","UG-C"] <= 0.051,
    base_name="UGANDA_UG_C_P_Oil_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"P_Oil","UG-C"] <= 0.051,
    base_name="UGANDA_UG_C_P_Oil_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"RES_PV_Utility_Avg","UG-C"] <= 0.041,
    base_name="UGANDA_UG_C_RES_PV_Utility_Avg_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"CHP_Biomass_Solid","UG-C"] <= 0.07151,
    base_name="UGANDA_UG_C_CHP_Biomass_Solid_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"CHP_Biomass_Solid","UG-W"] <= 0.04951,
    base_name="UGANDA_UG_W_CHP_Biomass_Solid_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"P_Oil","UG-E"] <= 0.0421,
    base_name="UGANDA_UG_E_P_Oil_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"RES_Hydro_Large","UG-E"] <= 0.8131,
    base_name="UGANDA_UG_E_RES_Hydro_Large_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"RES_Hydro_Small","UG-E"] <= 0.097551,
    base_name="UGANDA_UG_E_RES_Hydro_Small_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"RES_PV_Utility_Avg","UG-E"] <= 0.2681,
    base_name="UGANDA_UG_E_RES_PV_Utility_Avg_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"CHP_Biomass_Solid","UG-E"] <= 0.1361,
    base_name="UGANDA_UG_E_CHP_Biomass_Solid_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"RES_Hydro_Small","UG-N"] <= 0.079171,
    base_name="UGANDA_UG_N_RES_Hydro_Small_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"RES_Hydro_Large","UG-N"] <= 0.687211,
    base_name="UGANDA_UG_N_RES_Hydro_Large_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"RES_PV_Utility_Avg","UG-N"] <= 0.0951,
    base_name="UGANDA_UG_N_RES_PV_Utility_Avg_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"CHP_Biomass_Solid","UG-N"] <= 0.0251,
    base_name="UGANDA_UG_N_CHP_Biomass_Solid_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"P_Gas_CCGT","UG-W"] <= 0.23911,
    base_name="UGANDA_UG_W_P_Gas_CCGT_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"RES_Wind_Onshore_Avg","UG-E"] <= 0.021,
    base_name="UGANDA_UG_E_RES_Wind_Onshore_Avg_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"RES_PV_Utility_Avg","UG-W"] <= 0.081,
    base_name="UGANDA_UG_W_RES_PV_Utility_Avg_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"RES_Hydro_Small","UG-W"] <= 0.3314541,
    base_name="UGANDA_UG_W_RES_Hydro_Small_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"RES_Hydro_Small","UG-C"] <= 0.0006931,
    base_name="UGANDA_UG_C_RES_Hydro_Small_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2030,"RES_Geothermal","UG-W"] <= 0.181,
    base_name="UGANDA_UG_W_RES_Geothermal_2030_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"P_Oil","UG-C"] <= 0.051,
    base_name="UGANDA_UG_C_P_Oil_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"RES_PV_Utility_Avg","UG-C"] <= 0.041,
    base_name="UGANDA_UG_C_RES_PV_Utility_Avg_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"CHP_Biomass_Solid","UG-C"] <= 0.07151,
    base_name="UGANDA_UG_C_CHP_Biomass_Solid_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"RES_Hydro_Small","UG-W"] <= 0.3431541,
    base_name="UGANDA_UG_W_RES_Hydro_Small_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"CHP_Biomass_Solid","UG-W"] <= 0.04951,
    base_name="UGANDA_UG_W_CHP_Biomass_Solid_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"P_Oil","UG-E"] <= 0.0421,
    base_name="UGANDA_UG_E_P_Oil_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"RES_Hydro_Large","UG-E"] <= 0.8131,
    base_name="UGANDA_UG_E_RES_Hydro_Large_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"RES_Hydro_Small","UG-E"] <= 0.097551,
    base_name="UGANDA_UG_E_RES_Hydro_Small_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"RES_PV_Utility_Avg","UG-E"] <= 0.2681,
    base_name="UGANDA_UG_E_RES_PV_Utility_Avg_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"CHP_Biomass_Solid","UG-E"] <= 0.1361,
    base_name="UGANDA_UG_E_CHP_Biomass_Solid_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"RES_Hydro_Small","UG-N"] <= 0.079171,
    base_name="UGANDA_UG_N_RES_Hydro_Small_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"RES_Hydro_Large","UG-N"] <= 1.479211,
    base_name="UGANDA_UG_N_RES_Hydro_Large_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"RES_PV_Utility_Avg","UG-N"] <= 0.0951,
    base_name="UGANDA_UG_N_RES_PV_Utility_Avg_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"CHP_Biomass_Solid","UG-N"] <= 0.0251,
    base_name="UGANDA_UG_N_CHP_Biomass_Solid_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"P_Gas_CCGT","UG-W"] <= 0.23911,
    base_name="UGANDA_UG_W_P_Gas_CCGT_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"RES_Geothermal","UG-W"] <= 0.181,
    base_name="UGANDA_UG_W_RES_Geothermal_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"RES_Wind_Onshore_Avg","UG-E"] <= 0.021,
    base_name="UGANDA_UG_E_RES_Wind_Onshore_Avg_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"RES_PV_Utility_Avg","UG-W"] <= 0.081,
    base_name="UGANDA_UG_W_RES_PV_Utility_Avg_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2035,"RES_Hydro_Small","UG-C"] <= 0.0006931,
    base_name="UGANDA_UG_C_RES_Hydro_Small_2035_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"P_Oil","UG-C"] <= 0.051,
    base_name="UGANDA_UG_C_P_Oil_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"RES_PV_Utility_Avg","UG-C"] <= 0.041,
    base_name="UGANDA_UG_C_RES_PV_Utility_Avg_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"CHP_Biomass_Solid","UG-C"] <= 0.07151,
    base_name="UGANDA_UG_C_CHP_Biomass_Solid_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"RES_Hydro_Small","UG-W"] <= 0.3431541,
    base_name="UGANDA_UG_W_RES_Hydro_Small_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"CHP_Biomass_Solid","UG-W"] <= 0.04951,
    base_name="UGANDA_UG_W_CHP_Biomass_Solid_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"P_Oil","UG-E"] <= 0.0421,
    base_name="UGANDA_UG_E_P_Oil_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"RES_Hydro_Large","UG-E"] <= 0.8131,
    base_name="UGANDA_UG_E_RES_Hydro_Large_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"RES_Hydro_Small","UG-E"] <= 0.097551,
    base_name="UGANDA_UG_E_RES_Hydro_Small_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"RES_PV_Utility_Avg","UG-E"] <= 0.2681,
    base_name="UGANDA_UG_E_RES_PV_Utility_Avg_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"CHP_Biomass_Solid","UG-E"] <= 0.1361,
    base_name="UGANDA_UG_E_CHP_Biomass_Solid_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"RES_Hydro_Small","UG-N"] <= 0.079171,
    base_name="UGANDA_UG_N_RES_Hydro_Small_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"RES_Hydro_Large","UG-N"] <= 2.719211,
    base_name="UGANDA_UG_N_RES_Hydro_Large_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"RES_PV_Utility_Avg","UG-N"] <= 0.0951,
    base_name="UGANDA_UG_N_RES_PV_Utility_Avg_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"CHP_Biomass_Solid","UG-N"] <= 0.0251,
    base_name="UGANDA_UG_N_CHP_Biomass_Solid_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"P_Gas_CCGT","UG-W"] <= 0.23911,
    base_name="UGANDA_UG_W_P_Gas_CCGT_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"RES_Geothermal","UG-W"] <= 0.181,
    base_name="UGANDA_UG_W_RES_Geothermal_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"RES_Wind_Onshore_Avg","UG-E"] <= 0.021,
    base_name="UGANDA_UG_E_RES_Wind_Onshore_Avg_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"RES_PV_Utility_Avg","UG-W"] <= 0.081,
    base_name="UGANDA_UG_W_RES_PV_Utility_Avg_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"RES_Hydro_Small","UG-C"] <= 0.0006931,
    base_name="UGANDA_UG_C_RES_Hydro_Small_2040_MaxCapacity")

    @constraint(model,
    Vars.TotalCapacityAnnual[2040,"P_Nuclear","UG-E"] <= 1.41,
    base_name="UGANDA_UG_E_P_Nuclear_2040_MaxCapacity")
  end
    
end
