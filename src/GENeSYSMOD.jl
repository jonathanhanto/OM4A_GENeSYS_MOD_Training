"""
Main module for `GENeSYSMOD.jl`.

This module provides the means to run GENeSYS-MOD in julia. It is a translation of the
GAMS version of the model.
"""
module GENeSYSMOD

using DataFrames
using DuckDB
using DBInterface
using Dates
using JuMP
using XLSX
using CSV
using Statistics
using CondaPkg
using PythonCall
using LibGit2
using Downloads

const DenseArray = JuMP.Containers.DenseAxisArray

const LATEST_DATA_VERSION = "v1.0.5"

include("datastructures.jl")
include("utils.jl")
include("genesysmod_db.jl")
include("genesysmod_errorcheck.jl")
include("fetch_inputdata.jl")
include("genesysmod_main.jl")
include("genesysmod_dec.jl")
include("genesysmod_timeseries_reduction.jl")
include("genesysmod_dataload.jl")
include("genesysmod_settings.jl")
include("genesysmod_bounds.jl")
include("genesysmod_equ.jl")
include("genesysmod_employment.jl")
include("genesysmod_variable_parameter.jl")
include("genesysmod_results_raw.jl")
include("genesysmod_results.jl")
include("genesysmod_levelizedcosts.jl")
include("genesysmod_emissionintensity.jl")
include("genesysmod_dispatch.jl")
# Multi-objective (cost vs. social acceptance) add-on — optional, dockable.
# Only active when `genesysmod_augmecon(...)` is called; the single-objective
# path above is untouched.
include("genesysmod_acceptance.jl")
include("genesysmod_augmecon.jl")
# Auto-include every genesysmod_scenariodata_<region>.jl (defines module ScenarioData<Region>,
# dispatched by genesysmod_main.jl for the matching model_region). NB: adding a NEW such file
# requires a content change here (or a clean precompile) so Julia re-runs this dynamic include.
include.(filter(f-> occursin(r".jl$",f) && occursin("scenariodata",f), readdir(joinpath(pkgdir(GENeSYSMOD,"src")))))

export genesysmod, genesysmod_dispatch
export genesysmod_augmecon
export genesysmod_build_model, genesysmod_build_model_dispatch
export NoInfeasibilityTechs, WithInfeasibilityTechs # for use with the switch infeasibility_techs
export OneNodeSimple, TwoNodes, OneNodeStorage
export NoRawResult, CSVResult, TXTResult, TXTandCSV
export update_and_process_data, fetch_data_release
export release_dbs, retry_db_writes

end
