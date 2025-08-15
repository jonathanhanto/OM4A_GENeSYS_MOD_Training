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
Internal function used in the run to compute sectoral emissions and emission intensity of fuels.
"""
function genesysmod_emissionintensity(model, Sets, Params, VarPar, Vars,
                                      TierFive, LoopSetOutput, LoopSetInput)

    𝓡 = Sets.Region_full
    𝓕 = Sets.Fuel
    𝓨 = Sets.Year
    𝓣 = Sets.Technology
    𝓔 = Sets.Emission

    SectorEmissions   = JuMP.Containers.DenseAxisArray(
        zeros(length(𝓨), length(𝓡), length(𝓕), length(𝓔)), 𝓨, 𝓡, 𝓕, 𝓔)
    EmissionIntensity = JuMP.Containers.DenseAxisArray(
        zeros(length(𝓨), length(𝓡), length(𝓕), length(𝓔)), 𝓨, 𝓡, 𝓕, 𝓔)

    # Safe OutputActivityRatio access (falls back to 0.0)
    safe_oar(r,t,f,m,y) = try
        Params.OutputActivityRatio[r,t,f,m,y]
    catch
        0.0
    end

    for y ∈ 𝓨, r ∈ 𝓡, e ∈ 𝓔
        # ---------- Power ----------
        outs_power = get(LoopSetOutput, (r, "Power", y), Tuple{Any,Any}[])

        SectorEmissions[y,r,"Power",e] =
            sum((value(Vars.AnnualTechnologyEmissionByMode[y,t,e,m,r]) *
                 safe_oar(r,t,"Power",m,y)) for (t,m) in outs_power; init=0.0)

        # Total produced power (exclude storages)
        denom_power = sum(value(Vars.ProductionByTechnologyAnnual[y,t,"Power",r])
                          for t ∈ 𝓣 if Params.TagTechnologyToSector[t,"Storages"] == 0; init=0.0)

        EmissionIntensity[y,r,"Power",e] =
            denom_power == 0.0 ? 0.0 : SectorEmissions[y,r,"Power",e] / denom_power

        # ---------- TierFive fuels (heat & transport splits) ----------
        for f ∈ TierFive
            outs_f = get(LoopSetOutput, (r, f, y), Tuple{Any,Any}[])

            SectorEmissions[y,r,f,e] =
                sum((value(Vars.AnnualTechnologyEmissionByMode[y,t,e,m,r]) *
                     safe_oar(r,t,f,m,y)) for (t,m) in outs_f; init=0.0)

            # ProductionAnnual may be zero/missing
            denom_f = try
                VarPar.ProductionAnnual[y,f,r]
            catch
                0.0
            end
            EmissionIntensity[y,r,f,e] =
                (denom_f == 0.0) ? 0.0 : SectorEmissions[y,r,f,e] / denom_f
        end
    end

    return SectorEmissions, EmissionIntensity
end