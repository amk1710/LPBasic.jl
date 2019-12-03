
#=
organizational script for defining the LPBasic module

=#

"""
    LPBasic Module
Julia module implementing the LPBasic line planning problem.  

This includes:  
- defining structs for containing the relevant problema data  
- implementing IO functionality to read relevant data from GTFS data into such structs  
- a flexible functionality to construct JuMP models from such structs  
- some visualization functionality  
"""
module LPBasic

#constains basic struct definitions(Line, ProblemInstance) and constructors
include("definitions.jl")

#constains some utility helper functions
include("utility.jl")

#contains code for validation of instance X solution pairs
include("verifier.jl")

#contains code for reading data from a simplified GTFS feed and loading it into a ProblemInstance
include("DataReader.jl")

#contains code for instance/solution visualization
include("visualization.jl")

#contains code resposible for the optimization models
include("optimization.jl")

end