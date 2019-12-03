using LightGraphs
using MetaGraphs

#=
definition.jl
this script contains the basic definitions and constructors for the LPBasic problem
=#
export Line, ProblemInstance, LPBasic, VerifyInstance

#structs declarations:
#defines what a line is
"""
    Line  
A basic data structure for model construction. Represents a directed walk through a transportation network  

# Constructor:
    Line(id::Union{Int64, String}, walk::Array{Tuple{Int64, Int64}, 1}, frequency::Int64, cost::Float64)

# Fields:  
- id::Union{Int64, String} - an Int64 or String to help distinguis this lines from other lines. Uniqueness is not enforced  
- walk::Array{Tuple{Int64, Int64}, 1} - an array of edge indices, representing a directed walk through the transportation network  
- frequency::Int64 - the base frequency for this line  
- cost::Float64 - the cost per frequency unit of this line  
"""
struct Line
    id::Union{Int64, String}
    #a walk is defined as a sequence of *edges*
    walk::Array{Tuple{Int64, Int64}, 1}
    frequency::Int64
    #the cost *per frequency unit*
    cost::Float64

    Line(id, walk, frequency, cost) = 
        
        if length(walk) < 1 error("Invalid line: walk must contain at least one edge. Id:" * string(id))
        elseif frequency <= 0 error("Invalid Line: frequency must be strictly positive: " * string(frequency))
        elseif cost < 0 error("Invalid Line: cost must be positive: " * string(cost))
        else new(id, walk, frequency, cost) end
        
end

"""
    VerifyInstance(network::MetaDiGraph, lines::Array{Line,1})
    VerifyInstance(instance::ProblemInstance)

Verify if a given problem instance is valid per the LPBasic requirements. Raise error if there are inconsistensies, otherwise return true.

This includes checking if:  
- all lines are unique(unique id, unique walk, unique frequency)  
- each edge has defined its expected properties  
- there are no invalid values for frequencies and weights    

# to-do:  
- is the network/graph is connected?(is there is a path between every pair of vertices?)  
- redundant information matches one another? (:line_coverage)  
    

# return value:  
- true - indicating that the instance is valid, or  
- *raise error* - indicating that the instance is not valid and the reason why  
"""
function VerifyInstance(network::MetaDiGraph, lines::Array{Line,1})

    #verifies that any redundant information on the LPBasic instance actually matches. This should help detect any errors in the reading of input data
    #lines listed for a given edge as 'covering' actually cover the given edge (to-do, line number is not unique yet)
    
    
    #verifies that at least one line is defined
    if length(lines) <= 0 error("Invalid instance: 0 lines are defined") end

    #verifies that all lines are unique
    setLines = Set{Line}()
    for line in lines
        if in(line, setLines)
            error("Invalid instance: repeated lines detected")
        else
            push!(setLines, line)
        end
    end
    #ps: validation of each line is done elsewhere(on struct constructor)

    #network validation
    #verifies that at least two nodes have been defined
    if nv(network) < 2
        error("Invalid instance: network must contain at least two nodes")
    end
    #verifies that at least one edge exists
    if ne(network) < 1
        error("Invalid instance: network must contain at least one edge")
    end

    #verifies that each edge has defined its expected properties
    #weight, f_min, f_max
    for edge in edges(network)
        base_freq, f_min, f_max, weight,line_coverage = nothing, nothing, nothing, nothing, nothing
        try
            base_freq = get_prop(network, edge, :base_freq)
            f_min = get_prop(network, edge, :f_min)
            f_max = get_prop(network, edge, :f_max)
            weight = get_prop(network, edge, :weight)
            line_coverage = get_prop(network, edge, :line_coverage)
        catch e
            #at least one of the properties was not defined
            error("Expected properties (base_freq, f_min, f_max, weight) were not defined as expected for edge " + edge)
        end

        #if they have been defined, type check them
        #to-do: should f_min and f_max really be restricted to integer values?
        if !(base_freq isa Integer) error("base_freq was not defined as an integer in " * repr(edge)) end
        if !(f_min isa Integer) error("f_min was not defined as an integer in " * repr(edge)) end
        if !(f_max isa Integer) error("f_max was not defined as an integer in " * repr(edge)) end
        if !(weight isa Number) error("weight was not defined as a number in " * repr(edge)) end
        if !(line_coverage isa Dict{Int64,Int64}) error("line_coverage was not defined as a Dict{Int64,Int64} in " * repr(edge)) end

    end

    #checks redundancy on :line_coverage (to-do)

    #if no problems were detected, instance is considered valid
    return true
end

"""
    ProblemInstance  
Struct containing all data of a single LPBasic problem's instance.

# Constructor:
    ProblemInstance(network::MetaDiGraph, lines::Array{Line,1})

# Fields:
- network::MetaDiGraph - representation the transportation network
- lines::Array{Line,1} - array containing all lines to be considered in the optimization 
"""
struct ProblemInstance
	#a metadigraph with edges having the properties:
	#weight, f_min, f_max, (coverage_list)
    network::MetaDiGraph
    #an array of lines
    lines::Array{Line,1}
    
    ProblemInstance(network, lines) = VerifyInstance(network, lines) && new(network,lines) #short circuit: returns the second value if the first is true

end

#second method for VerifyInstance function
"""
    VerifyInstance(instance::ProblemInstance)

Do the same as VerifyInstance(instance.network, instance.lines)
"""
function VerifyInstance(instance::ProblemInstance)
    VerifyInstance(instance.network, instance.lines)
end
