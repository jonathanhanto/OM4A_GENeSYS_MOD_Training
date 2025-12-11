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
  @constraint(model,
  Vars.TotalCapacityAnnual[2030,"RES_PV_Utility_Avg","UG-E"] <= 6,
  base_name="Uganda_PV_2030")

    
  @constraint(model,
  Vars.TotalCapacityAnnual[2035,"RES_PV_Utility_Avg","UG-C"] <= 15,
  base_name="Uganda_PV_2030")

    
    
end
