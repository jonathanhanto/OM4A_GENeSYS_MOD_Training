# GENeSYS-MOD v3.1 [Global Energy System Model]  ~ March 2022
#
# #############################################################
#
# Copyright 2020 Technische Universit�t Berlin && DIW Berlin
#
# Licensed under the Apache License, Version 2.0 (the s"License")
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions &&
# limitations under the License.
#
# #############################################################

"""
Visualization function
"""

using CSV
using DataFrames
using StatsPlots
using CategoricalArrays

function visualize(result_dir, production, capacities, emissions, dispatch=nothing)

    if production !== nothing
        # Read the CSV file into a DataFrame
        #dfp = CSV.read("/Users/dozeumhaj/Documents/OM4A_Run/Results/output_annual_production_MiddleEarth_Gondor_globalLimit_122_dispatch.csv", DataFrame)
        dfp=CSV.read(joinpath(result_dir,production), DataFrame)

        # Remove whitespace from column names
        rename!(dfp, Symbol.(map(x -> strip(string(x)), names(dfp))))  # Convert column names to strings, strip whitespace, and convert back to symbols
        dfp[!, :Value_twh] = dfp.Value / 3.6  # create TWh column
        # Check the first few rows of the DataFrame to ensure data integrity


        first(dfp, 5)
        #group technologies
        df=dfp
        function group_technologies(df)
            df[!, :Technology_grouped] = df[!, :Technology]

            # Grouping technologies
            replacements = Dict(
                "D_Battery_Li-Ion" => "Storages",
                "D_PHS" => "Storages",
                "D_PHS_Residual" => "Storages",
                "HLI_Biomass_CHP" => "Biomass",
                "HLI_Biomass" => "Biomass",
                "HLR_Biomass" => "Biomass",
                "P_Biomass" => "Biomass",
                "P_Biomass_CCS" => "Biomass",
                "P_Gas_CCGT" => "Gas",
                "P_Gas_Engines" => "Gas",
                "P_Gas_OCGT" => "Gas",
                "P_Gas" => "Gas",
                "CHP_Gas_CCGT_Natural" => "Gas",
                "X_Electrolysis" => "Electrolysis",
                "HLI_Hardcoal_CHP" => "Hardcoal",
                "CHP_Coal_Hardcoal" => "Hardcoal",
                "CHP_Coal_Lignite" => "Hardcoal",
                "P_Coal_Hardcoal" => "Hardcoal",
                "Z_Import_Hardcoal" => "Hardcoal",
                "RES_Ocean" => "Ocean",
                "RES_Hydro_Dispatchable" => "Hydropower",
                "RES_Hydro_RoR" => "Hydropower",
                "RES_Hydro_Small" => "Hydropower",
                "RES_Hydro_Large" => "Hydropower",
                "RES_Grass" => "Biomass", ###
                "RES_Residues" => "Biomass", ###
                "RES_Wood" => "Biomass", ###
                "P_Coal_Lignite" => "Lignite",
                "P_Oil" => "Oil",
                "P_Nuclear" => "Nuclear",
                "RES_CSP" => "Solar PV",
                "RES_PV_Utility_Avg" => "Solar PV",
                "RES_PV_Utility_Inf" => "Solar PV",
                "RES_PV_Utility_Opt" => "Solar PV",
                "RES_PV_Utility_Opt_H2" => "Solar PV",
                "Res_PV_Utility_Tracking" => "Solar PV",
                "RES_PV_Rooftop_Commercial" => "Solar PV",
                "RES_PV_Rooftop_Residential" => "Solar PV",
                "RES_Wind_Offshore_Deep" => "Wind Offshore",
                "RES_Wind_Offshore_Shallow" => "Wind Offshore",
                "RES_Wind_Offshore_Shallow_H2" => "Wind Offshore",
                "RES_Wind_Offshore_Transitional" => "Wind Offshore",
                "RES_Wind_Onshore_Avg" => "Wind Onshore",
                "RES_Wind_Onshore_Inf" => "Wind Onshore",
                "RES_Wind_Onshore_Opt" => "Wind Onshore",
                "RES_Wind_Onshore_Opt_H2" => "Wind Onshore",
                "FRT_Rail_Electric" => "Demand [Transport]",
                "FRT_Rail_Conv" => "Demand [Transport]",
                "FRT_Road_BEV" => "Demand [Transport]",
                "FRT_Road_ICE" => "Demand [Transport]",
                "FRT_Road_PHEV" => "Demand [Transport]",
                "FRT_Road_OH" => "Demand [Transport]",
                "FRT_Ship_EL" => "Demand [Transport]",
                "FRT_Ship_Bio" => "Demand [Transport]",
                "FRT_Ship_Conv" => "Demand [Transport]",
                "PSNG_Rail_Electric" => "Demand [Transport]",
                "PSNG_Rail_Conv" => "Demand [Transport]",
                "PSNG_Road_BEV" => "Demand [Transport]",
                "PSNG_Road_PHEV" => "Demand [Transport]",
                "PSNG_Road_H2" => "Demand [Transport]",
                "PSNG_Road_ICE" => "Demand [Transport]",
                "PSNG_Air_Conv" => "Demand [Transport]",
                "PSNG_Air_H2" => "Demand [Transport]",
                "HLR_Direct_Electric" => "Demand [Buildings]",
                "HLR_Gas_Boiler" => "Demand [Buildings]",###
                "HLR_H2_Boiler" => "Demand [Buildings]",###
                "HLR_Hardcoal" => "Demand [Buildings]",###
                "HLR_Heatpump_Aerial" => "Demand [Buildings]",
                "HLR_Heatpump_Ground" => "Demand [Buildings]",
                "Power_Demand_IHS_Commercial" => "Demand [Buildings]",
                "Power_Demand_IHS_Residential" => "Demand [Buildings]",
                "HHI_DRI_EAF" => "Demand [Industry]",
                "HHI_Molten_Electrolysis" => "Demand [Industry]",
                "HHI_Scrap_EAF" => "Demand [Industry]",
                "HLI_Direct_Electric" => "Demand [Industry]",
                "HLI_Gas_CHP" => "Demand [Industry]",
                "HLI_Gas_Boiler" => "Demand [Industry]",
                "HLI_H2_Boiler" => "Demand [Industry]",
                "HLI_Hardcoal" => "Demand [Industry]",
                "HMI_Biomass" => "Demand [Industry]",
                "HMI_Steam_Electric" => "Demand [Industry]",
                "HMI_Gas" => "Demand [Industry]",
                "HMI_Hardcoal" => "Demand [Industry]",
                "HMI_HardCoal" => "Demand [Industry]",
                "HMI_Oil" => "Demand [Industry]",######
                "HHI_BF_BOF" => "Demand [Industry]",
                "HLI_Geothermal" => "Demand [Industry]",
                "HLI_Lignite" => "Demand [Industry]",
                "HLI_Solar_Thermal" => "Demand [Industry]",
                "Power_Demand_IHS_Industrial" => "Demand [Industry]",
                "X_Fuel_Cell" => "H2",
                "A_Rooftop_Commercial" => "Demand [Industry]",######
                "Demand" => "Demand [Industry]",######
                "R_Coal_Lignite" => "Demand [Industry]",######
                "R_Nuclear" => "Demand [Industry]",######
                "Trade" => "Demand [Industry]",######
                "X_Biofuel" => "Demand [Industry]",######
                "X_Methanation" => "Demand [Industry]",######
                "Z_Import_Gas" => "Demand [Industry]",######
                "Z_Import_H2" => "Demand [Industry]",######
                "Z_Import_Oil" => "Demand [Industry]",######
                "R_Coal_Hardcoal" => "Demand [Industry]",######
                "Resource" => "Resource",######
                "HHI_Bio_BF_BOF" => "Demand [Industry]",######
                "CHP_Biomass_Solid" => "Biomass",######
                "HLI_Oil_Boiler" => "Demand [Industry]",######
                "HLR_Oil_Boiler" => "Demand [Industry]",######
                "PSNG_Air_Bio" => "Demand [Industry]"######         
            )

            known_technologies = intersect(keys(replacements), unique(dfp.Technology))

            for key in known_technologies
                df[!, :Technology_grouped] = replace(df[!, :Technology_grouped], key => replacements[key])
            end

            return df, setdiff(unique(dfp.Technology), known_technologies)
        end

        dfp, unknown_technologies = group_technologies(dfp)

        if !isempty(unknown_technologies)
            println("Warning: The following technologies are not recognized and will not be included in further processing: ", unknown_technologies)
            
            # Filter out rows with unknown technologies
            dfp = filter(row -> !(row.Technology in unknown_technologies), dfp)
        end

    ############
    # Define the desired order of technologies for stacking
    technology_order = [
        "H2",
        "Solar PV",
        "Wind Offshore",
        "Wind Onshore",
        "Biomass",
        "Hydropower",
        "Ocean",
        "Nuclear",
        "Oil",
        "Electrolysis",
        "Demand [Buildings]",
        "Demand [Industry]",
        "Demand [Transport]",
        "Gas",
        "Lignite",
        "Hardcoal",
    ]

    # Convert Technology_grouped column to CategoricalArray with desired order
    dfp[!, :Technology_grouped] = CategoricalArray(dfp.Technology_grouped, ordered=true, levels=technology_order)
    #######

    # Create dataframe for electricity generation figure
    dfp_elec = combine(groupby(dfp, [:Year, :Fuel, :Type, :Technology_grouped]), :Value_twh => sum)
        
    # Filter for Power production
    dfp_elec = combine(groupby(filter(row -> row.Fuel == "Power" && row.Type == "Production", dfp), [:Year, :Fuel, :Type, :Technology_grouped]), :Value_twh => sum)

    show(dfp_elec, allrows=true, allcols=true)

    tech_colors = Dict(
        "Solar PV" => "#ffeb3b",
        "Wind Offshore" => "#215968",
        "Wind Onshore" => "#518696",
        "Biomass" => "#7cb342",
        "Hydropower" => "#0c46a0",
        "Ocean" => "#a0cbe8",
        "Nuclear" => "#ae393f",
        "Oil" => "#252623",
        "Lignite" => "#754937",
        "Hardcoal" => "#5e5048",
        "Electrolysis" => "#28dddd",
        "Demand [Buildings]" => "#c3b4b2",
        "Demand [Industry]" => "#a39794",
        "Demand [Transport]" => "#57606c",
        "Gas" => "#e54213",
        "H2" => "#26c6da"
    )


    ###############################################
    # Group by year and technology group
    grouped_df = combine(groupby(dfp_elec, [:Year, :Technology_grouped]), :Value_twh_sum => sum)

    # Extract unique years and technology groups
    unique_years = unique(grouped_df.Year)
    unique_technology_groups = unique(grouped_df.Technology_grouped)

    # Create filtered color dictionary
    filtered_tech_colors = Dict(group => tech_colors[group] for group in unique_technology_groups)

    # Convert years to strings for plotting
    grouped_df.Year = string.(grouped_df.Year)

    unique(grouped_df.Technology_grouped) 
    # Create the grouped bar plot
    bar_plot = groupedbar(
        grouped_df.Year,
        grouped_df.Value_twh_sum_sum,
        group = grouped_df.Technology_grouped,
        bar_position = :stack,
        bar_width = 0.8,
        xlabel = "Year",
        ylabel = "TWh",
        title = "Power Production [TWh]",
        size = (900, 800),
        color = [filtered_tech_colors[group] for group in grouped_df.Technology_grouped],
        legend = true,
    )

    # Display the plot
    display(bar_plot)

    end
    ######################################################
    ##################### Capacities ######################
    if capacities !== nothing
    
        # Read the CSV file into a DataFrame
        #dfp = CSV.read("/Users/dozeumhaj/Nextcloud/Projekte/LOTR/Results/output_capacity_MiddleEarth_Gondor_globalLimit_364_dispatch.csv", DataFrame)
        dfp=CSV.read(joinpath(result_dir,capacities), DataFrame)
        # Remove whitespace from column names
        rename!(dfp, Symbol.(map(x -> strip(string(x)), names(dfp))))  # Convert column names to strings, strip whitespace, and convert back to symbols
        #dfp[!, :Value_twh] = dfp.Value / 3.6  # create TWh column
        # Check the first few rows of the DataFrame to ensure data integrity


        first(dfp, 5)
        #group technologies
        df=dfp
        function group_technologies_capacities(df)
            df[!, :Technology_grouped] = df[!, :Technology]

            # Grouping technologies
            replacements = Dict(
                "D_Battery_Li-Ion" => "Storages",
                "D_PHS" => "Storages",
                "D_PHS_Residual" => "Storages",
                "HLI_Biomass_CHP" => "Biomass",
                "HLI_Biomass" => "Biomass",
                "HLR_Biomass" => "Biomass",
                "P_Biomass" => "Biomass",
                "P_Biomass_CCS" => "Biomass",
                "P_Gas_CCGT" => "Gas",
                "P_Gas_Engines" => "Gas",
                "P_Gas_OCGT" => "Gas",
                "P_Gas" => "Gas",
                "CHP_Gas_CCGT_Natural" => "Gas",
                "X_Electrolysis" => "Electrolysis",
                "HLI_Hardcoal_CHP" => "Hardcoal",
                "CHP_Coal_Hardcoal" => "Hardcoal",
                "CHP_Coal_Lignite" => "Hardcoal",
                "P_Coal_Hardcoal" => "Hardcoal",
                "Z_Import_Hardcoal" => "Hardcoal",
                "RES_Ocean" => "Ocean",
                "RES_Hydro_Dispatchable" => "Hydropower",
                "RES_Hydro_RoR" => "Hydropower",
                "RES_Hydro_Small" => "Hydropower",
                "RES_Hydro_Large" => "Hydropower",
                "RES_Grass" => "Biomass", ###
                "RES_Residues" => "Biomass", ###
                "RES_Wood" => "Biomass", ###
                "P_Coal_Lignite" => "Lignite",
                "P_Oil" => "Oil",
                "P_Nuclear" => "Nuclear",
                "RES_CSP" => "Solar PV",
                "RES_PV_Utility_Avg" => "Solar PV",
                "RES_PV_Utility_Inf" => "Solar PV",
                "RES_PV_Utility_Opt" => "Solar PV",
                "RES_PV_Utility_Opt_H2" => "Solar PV",
                "Res_PV_Utility_Tracking" => "Solar PV",
                "RES_PV_Rooftop_Commercial" => "Solar PV",
                "RES_PV_Rooftop_Residential" => "Solar PV",
                "RES_Wind_Offshore_Deep" => "Wind Offshore",
                "RES_Wind_Offshore_Shallow" => "Wind Offshore",
                "RES_Wind_Offshore_Shallow_H2" => "Wind Offshore",
                "RES_Wind_Offshore_Transitional" => "Wind Offshore",
                "RES_Wind_Onshore_Avg" => "Wind Onshore",
                "RES_Wind_Onshore_Inf" => "Wind Onshore",
                "RES_Wind_Onshore_Opt" => "Wind Onshore",
                "RES_Wind_Onshore_Opt_H2" => "Wind Onshore",
                "FRT_Rail_Electric" => "Demand [Transport]",
                "FRT_Rail_Conv" => "Demand [Transport]",
                "FRT_Road_BEV" => "Demand [Transport]",
                "FRT_Road_ICE" => "Demand [Transport]",
                "FRT_Road_PHEV" => "Demand [Transport]",
                "FRT_Road_OH" => "Demand [Transport]",
                "FRT_Ship_EL" => "Demand [Transport]",
                "FRT_Ship_Bio" => "Demand [Transport]",
                "FRT_Ship_Conv" => "Demand [Transport]",
                "PSNG_Rail_Electric" => "Demand [Transport]",
                "PSNG_Rail_Conv" => "Demand [Transport]",
                "PSNG_Road_BEV" => "Demand [Transport]",
                "PSNG_Road_PHEV" => "Demand [Transport]",
                "PSNG_Road_H2" => "Demand [Transport]",
                "PSNG_Road_ICE" => "Demand [Transport]",
                "PSNG_Air_Conv" => "Demand [Transport]",
                "PSNG_Air_H2" => "Demand [Transport]",
                "HLR_Direct_Electric" => "Demand [Buildings]",
                "HLR_Gas_Boiler" => "Demand [Buildings]",###
                "HLR_H2_Boiler" => "Demand [Buildings]",###
                "HLR_Hardcoal" => "Demand [Buildings]",###
                "HLR_Heatpump_Aerial" => "Demand [Buildings]",
                "HLR_Heatpump_Ground" => "Demand [Buildings]",
                "Power_Demand_IHS_Commercial" => "Demand [Buildings]",
                "Power_Demand_IHS_Residential" => "Demand [Buildings]",
                "HHI_DRI_EAF" => "Demand [Industry]",
                "HHI_Molten_Electrolysis" => "Demand [Industry]",
                "HHI_Scrap_EAF" => "Demand [Industry]",
                "HLI_Direct_Electric" => "Demand [Industry]",
                "HLI_Gas_CHP" => "Demand [Industry]",
                "HLI_Gas_Boiler" => "Demand [Industry]",
                "HLI_H2_Boiler" => "Demand [Industry]",
                "HLI_Hardcoal" => "Demand [Industry]",
                "HMI_Biomass" => "Demand [Industry]",
                "HMI_Steam_Electric" => "Demand [Industry]",
                "HMI_Gas" => "Demand [Industry]",
                "HMI_Hardcoal" => "Demand [Industry]",
                "HMI_HardCoal" => "Demand [Industry]",
                "HHI_BF_BOF" => "Demand [Industry]",
                "HLI_Geothermal" => "Demand [Industry]",
                "HLI_Lignite" => "Demand [Industry]",
                "HLI_Solar_Thermal" => "Demand [Industry]",
                "Power_Demand_IHS_Industrial" => "Demand [Industry]",
                "X_Fuel_Cell" => "H2",
                "Demand" => "Demand [Industry]",######
                "R_Coal_Lignite" => "Demand [Industry]",######
                "R_Nuclear" => "Demand [Industry]",######
                "Trade" => "Demand [Industry]",######
                "X_Biofuel" => "Demand [Industry]",######
                "X_Methanation" => "Demand [Industry]",######
                "Z_Import_Gas" => "Demand [Industry]",######
                "Z_Import_H2" => "Demand [Industry]",######
                "Z_Import_Oil" => "Demand [Industry]",######
                "R_Coal_Hardcoal" => "Demand [Industry]",######
                "Resource" => "Demand [Industry]",######
                "A_Rooftop_Commercial" => "Demand [Industry]",######
                "HHI_Bio_BF_BOF" => "Demand [Industry]",######
                "CHP_Biomass_Solid" => "Demand [Industry]",######
                "HLI_Oil_Boiler" => "Demand [Industry]",######
                "HLR_Oil_Boiler" => "Demand [Industry]",######
                "HMI_Oil" => "Demand [Industry]",######
                "X_Gasifier" => "Demand [Industry]",######
                "PSNG_Air_Bio" => "Demand [Industry]"######
            )

            known_technologies = intersect(keys(replacements), unique(dfp.Technology))

        for key in known_technologies
            df[!, :Technology_grouped] = replace(df[!, :Technology_grouped], key => replacements[key])
        end

        return df, setdiff(unique(dfp.Technology), known_technologies)
    end

    dfp, unknown_technologies = group_technologies_capacities(dfp)

    if !isempty(unknown_technologies)
        println("Warning: The following technologies are not recognized and will not be included in further processing: ", unknown_technologies)
        
        # Filter out rows with unknown technologies
        dfp = filter(row -> !(row.Technology in unknown_technologies), dfp)
    end


        ############
        # Define the desired order of technologies for stacking
        technology_order = [
            "H2",
            "Solar PV",
            "Wind Offshore",
            "Wind Onshore",
            "Biomass",
            "Hydropower",
            "Ocean",
            "Nuclear",
            "Oil",
            "Electrolysis",
            "Storages",
            "Demand [Buildings]",
            "Demand [Industry]",
            "Demand [Transport]",
            "Gas",
            "Lignite",
            "Hardcoal",
        ]

        # Convert Technology_grouped column to CategoricalArray with desired order
        dfp[!, :Technology_grouped] = CategoricalArray(dfp.Technology_grouped, ordered=true, levels=technology_order)
        #######
        # Create dataframe for capacities
        dfp_elec = combine(groupby(dfp, [:Year, :Technology, :Type, :Technology_grouped]), :Value => sum)
            
        # Filter for Power production
        dfp_elec = combine(groupby(filter(row -> row.Sector == "Power" && row.Type == "TotalCapacity", dfp), [:Year, :Sector, :Type, :Technology_grouped]), :Value => sum)


        show(dfp_elec, allrows=true, allcols=true)


        tech_colors = Dict(
            "Solar PV" => "#ffeb3b",
            "Wind Offshore" => "#215968",
            "Wind Onshore" => "#518696",
            "Biomass" => "#7cb342",
            "Hydropower" => "#0c46a0",
            "Ocean" => "#a0cbe8",
            "Nuclear" => "#ae393f",
            "Oil" => "#252623",
            "Lignite" => "#754937",
            "Hardcoal" => "#5e5048",
            "Electrolysis" => "#28dddd",
            "Demand [Buildings]" => "#c3b4b2",
            "Demand [Industry]" => "#a39794",
            "Demand [Transport]" => "#57606c",
            "Gas" => "#e54213",
            "H2" => "#26c6da"
        )


        ###############################################
        # Group by year and technology group
        grouped_df = combine(groupby(dfp_elec, [:Year, :Technology_grouped]), :Value_sum => sum)

        # Extract unique years and technology groups
        unique_years = unique(grouped_df.Year)
        unique_technology_groups = unique(grouped_df.Technology_grouped)

        # Create filtered color dictionary
        filtered_tech_colors = Dict(group => tech_colors[group] for group in unique_technology_groups)


        # Convert years to strings for plotting
        grouped_df.Year = string.(grouped_df.Year)


        # Create the grouped bar plot
        bar_plot_capacities = groupedbar(
            grouped_df.Year,
            grouped_df.Value_sum_sum,
            group = grouped_df.Technology_grouped,
            bar_position = :stack,
            bar_width = 0.8,
            xlabel = "Year",
            ylabel = "MW",
            title = "Installed Capacity [MW]",
            size = (800, 750),
            legend = :topleft,
            color = [filtered_tech_colors[group] for group in grouped_df.Technology_grouped]
        )

        # Display plot
        display(bar_plot_capacities)

    end

    ######################################################
    ##################### Emissions ######################
    if emissions !== nothing
  
        # Read the CSV file into a DataFrame
        #dfp = CSV.read("/Users/dozeumhaj/Nextcloud/Projekte/LOTR/Results/output_capacity_MiddleEarth_Gondor_globalLimit_364_dispatch.csv", DataFrame)
        dfp=CSV.read(joinpath(result_dir,emissions), DataFrame)
        # Remove whitespace from column names
        rename!(dfp, Symbol.(map(x -> strip(string(x)), names(dfp))))  # Convert column names to strings, strip whitespace, and convert back to symbols
        #dfp[!, :Value_twh] = dfp.Value / 3.6  # create TWh column
        # Check the first few rows of the DataFrame to ensure data integrity


        first(dfp, 5)
        #group technologies
        df=dfp
        function group_technologies_emissions(df)
            df[!, :Technology_grouped] = df[!, :Technology]

            # Grouping technologies
            replacements = Dict(
                "D_Battery_Li-Ion" => "Storages",
                "D_PHS" => "Storages",
                "D_PHS_Residual" => "Storages",
                "HLI_Biomass_CHP" => "Biomass",
                "HLI_Biomass" => "Biomass",
                "HLR_Biomass" => "Biomass",
                "P_Biomass" => "Biomass",
                "P_Biomass_CCS" => "Biomass",
                "P_Gas_CCGT" => "Gas",
                "P_Gas_Engines" => "Gas",
                "P_Gas_OCGT" => "Gas",
                "P_Gas" => "Gas",
                "CHP_Gas_CCGT_Natural" => "Gas",
                "X_Electrolysis" => "Electrolysis",
                "HLI_Hardcoal_CHP" => "Hardcoal",
                "CHP_Coal_Hardcoal" => "Hardcoal",
                "CHP_Coal_Lignite" => "Hardcoal",
                "P_Coal_Hardcoal" => "Hardcoal",
                "Z_Import_Hardcoal" => "Hardcoal",
                "RES_Ocean" => "Ocean",
                "RES_Hydro_Dispatchable" => "Hydropower",
                "RES_Hydro_RoR" => "Hydropower",
                "RES_Hydro_Small" => "Hydropower",
                "RES_Hydro_Large" => "Hydropower",
                "RES_Grass" => "Biomass", ###
                "RES_Residues" => "Biomass", ###
                "RES_Wood" => "Biomass", ###
                "P_Coal_Lignite" => "Lignite",
                "P_Oil" => "Oil",
                "P_Nuclear" => "Nuclear",
                "RES_CSP" => "Solar PV",
                "RES_PV_Utility_Avg" => "Solar PV",
                "RES_PV_Utility_Inf" => "Solar PV",
                "RES_PV_Utility_Opt" => "Solar PV",
                "RES_PV_Utility_Opt_H2" => "Solar PV",
                "Res_PV_Utility_Tracking" => "Solar PV",
                "RES_PV_Rooftop_Commercial" => "Solar PV",
                "RES_PV_Rooftop_Residential" => "Solar PV",
                "RES_Wind_Offshore_Deep" => "Wind Offshore",
                "RES_Wind_Offshore_Shallow" => "Wind Offshore",
                "RES_Wind_Offshore_Shallow_H2" => "Wind Offshore",
                "RES_Wind_Offshore_Transitional" => "Wind Offshore",
                "RES_Wind_Onshore_Avg" => "Wind Onshore",
                "RES_Wind_Onshore_Inf" => "Wind Onshore",
                "RES_Wind_Onshore_Opt" => "Wind Onshore",
                "RES_Wind_Onshore_Opt_H2" => "Wind Onshore",
                "FRT_Rail_Electric" => "Demand [Transport]",
                "FRT_Rail_Conv" => "Demand [Transport]",
                "FRT_Road_BEV" => "Demand [Transport]",
                "FRT_Road_ICE" => "Demand [Transport]",
                "FRT_Road_PHEV" => "Demand [Transport]",
                "FRT_Road_OH" => "Demand [Transport]",
                "FRT_Ship_EL" => "Demand [Transport]",
                "FRT_Ship_Bio" => "Demand [Transport]",
                "FRT_Ship_Conv" => "Demand [Transport]",
                "PSNG_Rail_Electric" => "Demand [Transport]",
                "PSNG_Rail_Conv" => "Demand [Transport]",
                "PSNG_Road_BEV" => "Demand [Transport]",
                "PSNG_Road_PHEV" => "Demand [Transport]",
                "PSNG_Road_H2" => "Demand [Transport]",
                "PSNG_Road_ICE" => "Demand [Transport]",
                "PSNG_Air_Conv" => "Demand [Transport]",
                "PSNG_Air_H2" => "Demand [Transport]",
                "HLR_Direct_Electric" => "Demand [Buildings]",
                "HLR_Gas_Boiler" => "Demand [Buildings]",###
                "HLR_H2_Boiler" => "Demand [Buildings]",###
                "HLR_Hardcoal" => "Demand [Buildings]",###
                "HLR_Heatpump_Aerial" => "Demand [Buildings]",
                "HLR_Heatpump_Ground" => "Demand [Buildings]",
                "Power_Demand_IHS_Commercial" => "Demand [Buildings]",
                "Power_Demand_IHS_Residential" => "Demand [Buildings]",
                "HHI_DRI_EAF" => "Demand [Industry]",
                "HHI_Molten_Electrolysis" => "Demand [Industry]",
                "HHI_Scrap_EAF" => "Demand [Industry]",
                "HLI_Direct_Electric" => "Demand [Industry]",
                "HLI_Gas_CHP" => "Demand [Industry]",
                "HLI_Gas_Boiler" => "Demand [Industry]",
                "HLI_H2_Boiler" => "Demand [Industry]",
                "HLI_Hardcoal" => "Demand [Industry]",
                "HMI_Biomass" => "Demand [Industry]",
                "HMI_Steam_Electric" => "Demand [Industry]",
                "HMI_Gas" => "Demand [Industry]",
                "HMI_Hardcoal" => "Demand [Industry]",
                "HMI_HardCoal" => "Demand [Industry]",
                "HHI_BF_BOF" => "Demand [Industry]",
                "HLI_Geothermal" => "Demand [Industry]",
                "HLI_Lignite" => "Demand [Industry]",
                "HLI_Solar_Thermal" => "Demand [Industry]",
                "Power_Demand_IHS_Industrial" => "Demand [Industry]",
                "X_Fuel_Cell" => "H2",
                "Demand" => "Demand [Industry]",######
                "R_Coal_Lignite" => "Demand [Industry]",######
                "R_Nuclear" => "Demand [Industry]",######
                "Trade" => "Demand [Industry]",######
                "X_Biofuel" => "Demand [Industry]",######
                "X_Methanation" => "Demand [Industry]",######
                "Z_Import_Gas" => "Demand [Industry]",######
                "Z_Import_H2" => "Demand [Industry]",######
                "Z_Import_Oil" => "Demand [Industry]",######
                "R_Coal_Hardcoal" => "Demand [Industry]",######
                "Resource" => "Demand [Industry]",######
                "A_Rooftop_Commercial" => "Demand [Industry]",######
                "HHI_Bio_BF_BOF" => "Demand [Industry]",######
                "CHP_Biomass_Solid" => "Demand [Industry]",######
                "HLI_Oil_Boiler" => "Demand [Industry]",######
                "HLR_Oil_Boiler" => "Demand [Industry]",######
                "HMI_Oil" => "Demand [Industry]",######
                "X_Gasifier" => "Demand [Industry]",######
                "PSNG_Air_Bio" => "Demand [Industry]"######
            )

            for key in keys(replacements)
                df[!, :Technology_grouped] = replace(df[!, :Technology_grouped], key => replacements[key])
            end

            return df
        end

        group_technologies_emissions(df)

        # Print the resulting DataFrame
        #println(df)
        dfp=df 


        ############
        # Define the desired order of technologies for stacking
        technology_order = [
            "H2",
            "Solar PV",
            "Wind Offshore",
            "Wind Onshore",
            "Biomass",
            "Hydropower",
            "Ocean",
            "Nuclear",
            "Oil",
            "Electrolysis",
            "Storages",
            "Demand [Buildings]",
            "Demand [Industry]",
            "Demand [Transport]",
            "Gas",
            "Lignite",
            "Hardcoal",
        ]

        # Convert Technology_grouped column to CategoricalArray with desired order
        dfp[!, :Technology_grouped] = CategoricalArray(dfp.Technology_grouped, ordered=true, levels=technology_order)
        #######
        # Create dataframe for capacities
        dfp_elec = combine(groupby(dfp, [:Year, :Sector]), :Value => sum)
            
        # Filter for Power production
        #dfp_elec = combine(groupby(filter(row -> row.Sector == "Power" && row.Type == "TotalCapacity", dfp), [:Year, :Sector, :Type, :Technology_grouped]), :Value => sum)


        show(dfp_elec, allrows=true, allcols=true)


        tech_colors = Dict(
            "Solar PV" => "#ffeb3b",
            "Wind Offshore" => "#215968",
            "Wind Onshore" => "#518696",
            "Biomass" => "#7cb342",
            "Hydropower" => "#0c46a0",
            "Ocean" => "#a0cbe8",
            "Nuclear" => "#ae393f",
            "Oil" => "#252623",
            "Lignite" => "#754937",
            "Hardcoal" => "#5e5048",
            "Electrolysis" => "#28dddd",
            "Demand [Buildings]" => "#c3b4b2",
            "Demand [Industry]" => "#a39794",
            "Demand [Transport]" => "#a39794",
            "Gas" => "#e54213",
            "Power" => "#ffeb3b",
            "Buildings" => "#E06666",
            "CHP" => "#B6D7A8",
            "Transportation" => "#741B47",
            "Industry" => "#CE7E00",
        )

        ###############################################
        # Group by year and technology group
        grouped_df = combine(groupby(dfp_elec, [:Year, :Sector]), :Value_sum => sum)

        # Extract unique years and technology groups
        unique_years = unique(grouped_df.Year)
        unique_Sector = unique(grouped_df.Sector)

        # Create filtered color dictionary
        filtered_tech_colors = Dict(group => tech_colors[group] for group in unique_Sector)


        # Convert years to strings for plotting
        grouped_df.Year = string.(grouped_df.Year)


        # Create the grouped bar plot
        bar_plot_emissions = groupedbar(
            grouped_df.Year,
            grouped_df.Value_sum_sum,
            group = grouped_df.Sector,
            bar_position = :stack,
            bar_width = 0.8,
            xlabel = "Year",
            ylabel = "GTCO2",
            title = "Emissions [GTCO2]",
            size = (920, 800),
            legend = :topright,
            color = [filtered_tech_colors[group] for group in grouped_df.Sector]
        )

        # Display plot
        display(bar_plot_emissions)

    end
    

    #######################Dispatch###########################
    if dispatch !== nothing     

        # Read the CSV file into a DataFrame
        #dfp_dispatch = CSV.read("/Users/dozeumhaj/Documents/OM4A_Run/Results/output_production_MiddleEarth_Gondor_globalLimit_122_dispatch.csv", DataFrame)
       

        dfp_dispatch=CSV.read(joinpath(result_dir,dispatch), DataFrame)

        # Remove whitespace from column names
        rename!(dfp_dispatch, Symbol.(map(x -> strip(string(x)), names(dfp_dispatch))))  # Convert column names to strings, strip whitespace, and convert back to symbols
        dfp_dispatch[!, :Value_twh] = dfp_dispatch.Value / 3.6  # create TWh column
        # Check the first few rows of the DataFrame to ensure data integrity


        first(dfp_dispatch, 5)
        #group technologies
        df=dfp_dispatch
        function group_technologies_dispatch(df)
            df[!, :Technology_grouped] = df[!, :Technology]

            # Grouping technologies
            replacements_dispatch = Dict(
                "D_Battery_Li-Ion" => "Storages",
                "D_PHS" => "Storages",
                "D_PHS_Residual" => "Storages",
                "HLI_Biomass_CHP" => "Biomass",
                "HLI_Biomass" => "Biomass",
                "HLR_Biomass" => "Biomass",
                "P_Biomass" => "Biomass",
                "P_Biomass_CCS" => "Biomass",
                "P_Gas_CCGT" => "Gas",
                "P_Gas_Engines" => "Gas",
                "P_Gas_OCGT" => "Gas",
                "P_Gas" => "Gas",
                "CHP_Gas_CCGT_Natural" => "Gas",
                "X_Electrolysis" => "Electrolysis",
                "HLI_Hardcoal_CHP" => "Hardcoal",
                "CHP_Coal_Hardcoal" => "Hardcoal",
                "CHP_Coal_Lignite" => "Hardcoal",
                "P_Coal_Hardcoal" => "Hardcoal",
                "Z_Import_Hardcoal" => "Hardcoal",
                "RES_Ocean" => "Ocean",
                "RES_Hydro_Dispatchable" => "Hydropower",
                "RES_Hydro_RoR" => "Hydropower",
                "RES_Hydro_Small" => "Hydropower",
                "RES_Hydro_Large" => "Hydropower",
                "RES_Grass" => "Biomass", ###
                "RES_Residues" => "Biomass", ###
                "RES_Wood" => "Biomass", ###
                "P_Coal_Lignite" => "Lignite",
                "P_Oil" => "Oil",
                "P_Nuclear" => "Nuclear",
                "RES_CSP" => "Solar PV",
                "RES_PV_Utility_Avg" => "Solar PV",
                "RES_PV_Utility_Inf" => "Solar PV",
                "RES_PV_Utility_Opt" => "Solar PV",
                "RES_PV_Utility_Opt_H2" => "Solar PV",
                "Res_PV_Utility_Tracking" => "Solar PV",
                "RES_PV_Rooftop_Commercial" => "Solar PV",
                "RES_PV_Rooftop_Residential" => "Solar PV",
                "RES_Wind_Offshore_Deep" => "Wind Offshore",
                "RES_Wind_Offshore_Shallow" => "Wind Offshore",
                "RES_Wind_Offshore_Shallow_H2" => "Wind Offshore",
                "RES_Wind_Offshore_Transitional" => "Wind Offshore",
                "RES_Wind_Onshore_Avg" => "Wind Onshore",
                "RES_Wind_Onshore_Inf" => "Wind Onshore",
                "RES_Wind_Onshore_Opt" => "Wind Onshore",
                "RES_Wind_Onshore_Opt_H2" => "Wind Onshore",
                "FRT_Rail_Electric" => "Demand [Transport]",
                "FRT_Rail_Conv" => "Demand [Transport]",
                "FRT_Road_BEV" => "Demand [Transport]",
                "FRT_Road_ICE" => "Demand [Transport]",
                "FRT_Road_PHEV" => "Demand [Transport]",
                "FRT_Road_OH" => "Demand [Transport]",
                "FRT_Ship_EL" => "Demand [Transport]",
                "FRT_Ship_Bio" => "Demand [Transport]",
                "FRT_Ship_Conv" => "Demand [Transport]",
                "PSNG_Rail_Electric" => "Demand [Transport]",
                "PSNG_Rail_Conv" => "Demand [Transport]",
                "PSNG_Road_BEV" => "Demand [Transport]",
                "PSNG_Road_PHEV" => "Demand [Transport]",
                "PSNG_Road_H2" => "Demand [Transport]",
                "PSNG_Road_ICE" => "Demand [Transport]",
                "PSNG_Air_Conv" => "Demand [Transport]",
                "PSNG_Air_H2" => "Demand [Transport]",
                "HLR_Direct_Electric" => "Demand [Buildings]",
                "HLR_Gas_Boiler" => "Demand [Buildings]",###
                "HLR_H2_Boiler" => "Demand [Buildings]",###
                "HLR_Hardcoal" => "Demand [Buildings]",###
                "HLR_Heatpump_Aerial" => "Demand [Buildings]",
                "HLR_Heatpump_Ground" => "Demand [Buildings]",
                "Power_Demand_IHS_Commercial" => "Demand [Buildings]",
                "Power_Demand_IHS_Residential" => "Demand [Buildings]",
                "HHI_DRI_EAF" => "Demand [Industry]",
                "HHI_Molten_Electrolysis" => "Demand [Industry]",
                "HHI_Scrap_EAF" => "Demand [Industry]",
                "HLI_Direct_Electric" => "Demand [Industry]",
                "HLI_Gas_CHP" => "Demand [Industry]",
                "HLI_Gas_Boiler" => "Demand [Industry]",
                "HLI_H2_Boiler" => "Demand [Industry]",
                "HLI_Hardcoal" => "Demand [Industry]",
                "HMI_Biomass" => "Demand [Industry]",
                "HMI_Steam_Electric" => "Demand [Industry]",
                "HMI_Gas" => "Demand [Industry]",
                "HMI_Hardcoal" => "Demand [Industry]",
                "HMI_HardCoal" => "Demand [Industry]",
                "HHI_BF_BOF" => "Demand [Industry]",
                "HLI_Geothermal" => "Demand [Industry]",
                "HLI_Lignite" => "Demand [Industry]",
                "HLI_Solar_Thermal" => "Demand [Industry]",
                "Power_Demand_IHS_Industrial" => "Demand [Industry]",
                "X_Fuel_Cell" => "H2",
                "A_Rooftop_Commercial" => "Demand [Industry]",######
                "Demand" => "Demand [Industry]",######
                "R_Coal_Lignite" => "Demand [Industry]",######
                "R_Nuclear" => "Demand [Industry]",######
                "Trade" => "Demand [Industry]",######
                "X_Biofuel" => "Demand [Industry]",######
                "X_Methanation" => "Demand [Industry]",######
                "X_Gasifier" => "Demand [Industry]",######
                "Z_Import_Gas" => "Demand [Industry]",######
                "Z_Import_H2" => "Demand [Industry]",######
                "Z_Import_Oil" => "Demand [Industry]",######
                "R_Coal_Hardcoal" => "Demand [Industry]",######
                "Resource" => "Resource",######
                "HHI_Bio_BF_BOF" => "Demand [Industry]",######
                "CHP_Biomass_Solid" => "Demand [Industry]",######
                "HLI_Oil_Boiler" => "Demand [Industry]",######
                "HLR_Oil_Boiler" => "Demand [Industry]",######
                "PSNG_Air_Bio" => "Demand [Industry]",######
                "X_Powerfuel" => "Demand [Industry]",######
                "HHI_H2DRI_EAF" => "Demand [Industry]",######
                "X_Gasifier" => "Demand [Industry]"######
            )

            known_technologies = intersect(keys(replacements_dispatch), unique(dfp_dispatch.Technology))

            for key in known_technologies
                df[!, :Technology_grouped] = replace(df[!, :Technology_grouped], key => replacements_dispatch[key])
            end

            return df, setdiff(unique(dfp_dispatch.Technology), known_technologies)
        end

        dfp_dispatch, unknown_technologies = group_technologies_dispatch(dfp_dispatch)

        if !isempty(unknown_technologies)
            println("Warning: The following technologies are not recognized and will not be included in further processing: ", unknown_technologies)
            
            # Filter out rows with unknown technologies
            dfp_dispatch = filter(row -> !(row.Technology in unknown_technologies), dfp_dispatch)
        end

        # Define the desired order of technologies for stacking
        technology_order = [
            "H2",
            "Solar PV",
            "Wind Offshore",
            "Wind Onshore",
            "Biomass",
            "Hydropower",
            "Ocean",
            "Nuclear",
            "Oil",
            "Electrolysis",
            "Demand [Buildings]",
            "Demand [Industry]",
            "Demand [Transport]",
            "Gas",
            "Lignite",
            "Hardcoal",
        ]

        # Create dataframe for electricity generation figure
        #display(dfp_dispatch)
        dfp_elec = combine(groupby(dfp_dispatch, [:Year, :Fuel, :Timeslice, :Type, :Technology_grouped]), :Value_twh => sum)

        # Filter for Power production
        dfp_elec = combine(groupby(filter(row -> row.Year == 2025 && row.Fuel == "Power" && row.Type == "Production", dfp_dispatch), [:Year, :Fuel, :Timeslice, :Type, :Technology_grouped]), :Value_twh => sum)

        # Convert Technology_grouped column to CategoricalArray with desired order
        dfp_elec[!, :Technology_grouped] = CategoricalArray(dfp_elec.Technology_grouped, ordered=true, levels=technology_order)

        # Group by year and technology group
        grouped_df = combine(groupby(dfp_elec, [:Timeslice, :Technology_grouped]), :Value_twh_sum => sum)

        # Pad timeslice strings with leading zeros to ensure fixed length
        padded_timeslices = string.([lpad(ts, 4, '0') for ts in grouped_df.Timeslice])

        # Convert padded timeslices to integers for sorting
        timeslices_int = parse.(Int, padded_timeslices)

        # Sort the timeslices_int array
        sorted_indices = sortperm(timeslices_int)
        sorted_timeslices = padded_timeslices[sorted_indices]

        # Reorder the DataFrame based on sorted timeslices
        grouped_df_sorted = grouped_df[sorted_indices, :]

        # Filtered technology groups
        filtered_technology_groups = filter(group -> group in technology_order, unique(grouped_df.Technology_grouped))

        tech_colors = Dict(
            "Solar PV" => "#ffeb3b",
            "Wind Offshore" => "#215968",
            "Wind Onshore" => "#518696",
            "Biomass" => "#7cb342",
            "Hydropower" => "#0c46a0",
            "Ocean" => "#a0cbe8",
            "Nuclear" => "#ae393f",
            "Oil" => "#252623",
            "Lignite" => "#754937",
            "Hardcoal" => "#5e5048",
            "Electrolysis" => "#28dddd",
            "Demand [Buildings]" => "#c3b4b2",
            "Demand [Industry]" => "#a39794",
            "Demand [Transport]" => "#a39794",
            "Gas" => "#e54213",
            "H2" => "#26c6da"
        )
        # Assign colors based on the filtered technology groups
        filtered_tech_colors = Dict(group => get(tech_colors, group, :auto) for group in filtered_technology_groups)

        # Create the grouped bar plot with corrected timeslice order
        bar_plot_dispatch = groupedbar(
            sorted_timeslices, 
            grouped_df_sorted.Value_twh_sum_sum,
            group = grouped_df_sorted.Technology_grouped,
            bar_position = :stack,
            bar_width = 0.8,
            xlabel = "Timeslice",
            ylabel = "TWh",
            title = "Power Production in 2050 [TWh]",
            size = (880, 700),
            legend = :topleft,
            lw = 0,
            xrotation = 90,
            color = [get(filtered_tech_colors, group, :auto) for group in grouped_df_sorted.Technology_grouped]
        )

        # Display the plot
        display(bar_plot_dispatch)
    end

    if (production === nothing) & (capacities === nothing) & (emissions === nothing) & (dispatch === nothing)
        error("Error: Need at least one of the following arguments as input: ['production', 'capacities', 'emissions', 'dispatch'].")
    end


    
    # # Display the plot
    # display(bar_plot_capacities)
    # display(bar_plot_emissions)

    # if dispatch !== nothing
    #     display(bar_plot_dispatch)
    # end
end