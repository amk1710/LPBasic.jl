#=
verifier.jl
this script implements functionality to independently verify a solution's correctness.
=#

using LightGraphs
using MetaGraphs
using Statistics

export VerifySolution, BasicStats

#=verifies if a given solution is valid per the LPBasic requirements
#this includes checking if:  
    minimum and maximum frequency requirements are met
    
#return value:
    a tuple: (true, "Valid") - indicating that the solution is valid
             (false, error_string) - indicating that the solution is not valid and the reason why 
=#
"""
    VerifySolution(instance::ProblemInstance, solution::Array{Bool,1})
Verify if a given solution is feasible per the LPBasic requirements.

Also check for construction errors in the instance and solution itself
Return a tuple (true,"Valid") or (false, <error_string>)
"""
function VerifySolution(instance::ProblemInstance, solution::Array{Bool,1})
    
    #we supose the instance was already validated?
    VerifyInstance(instance)

    #solution and instance match in number of lines?
    if(length(instance.lines) != length(solution))
        return false, "Number of lines in instance and solution do not match"
    end

    #minimum and maximum frequency requirements are met:
    #for each edge in the network, 
    for e in edges(instance.network)
        #its coverage frequency
        f_min = get_prop(instance.network, e, :f_min)
        f_max = get_prop(instance.network, e, :f_max)
        
        coverage_freq = sum( if (solution[i]) IsEdgeOnLine(instance, e, i) * instance.lines[i].frequency else 0 end for i in 1:length(solution))
        
        if coverage_freq < f_min
            return false, "Coverage frequency is too low on edge " * repr(e) * ": " * string(coverage_freq) * " < " * string(f_min)
        elseif coverage_freq > f_max
            return false, "Coverage frequency too high on edge " * repr(e)* ": " * string(coverage_freq) * " > " + string(f_max)
        end
    end

    return true, "Valid"
end

"""
    CalculateCost(instance::ProblemInstance, solution::Array{Bool,1})::Float64
Calculate total line cost for given solution on given instance.

A solution for this method is an array of booleans indicating accepting or rejecting a line with its basic frequency
"""
function CalculateCost(instance::ProblemInstance, solution::Array{Bool,1})::Float64
    cost = Float64(0.0)
    for i in 1:length(instance.lines)
        if solution[i]
            cost += instance.lines[i].cost * instance.lines[i].frequency
        end
    end
    return cost
end

"""
    CalculateCost(instance::ProblemInstance, solution::Array{Bool,1})::Float64
Calculate total line cost for given solution on given instance.

A solution for this method is an array of integers representing each line's taken frequency
"""
function CalculateCost(instance::ProblemInstance, solution::Array{T,1} where T<:Integer)
    println("Calculate cost Integer")
    return sum(instance.lines[i].cost * solution[i] for i in 1:length(instance.lines))
end

#to do: implement some extra validation criteria, such as:

#returns a dictionary with relevant basic information about the instance-solution pair
"""
    BasicStats(instance::ProblemInstance, solution::Array{Bool,1})
Boolean/binary variant of the BasicStats function. 

In this solution, each line has 0 frequency or its base-frequency
"""
function BasicStats(instance::ProblemInstance, solution::Array{Bool,1})
    
    return BasicStats(instance, collect(Int64, if solution[i] instance.lines[i].frequency else 0 end for i in 1:length(solution)))

end

"""
    BasicStats(instance::ProblemInstance, solution::Array{T,1} where {T<:Integer})
Populate and return a dictionary with basic information about the instance and solution.

The returned dictinary has the following key/value pairings:
- QntLines: the quantity of lines considered in the instance
- QntStops: the quantity of stops/nodes in the transportation network/graph
- QntEdges: the quantity of conections/edges in the transportation network/graph
- TakenLines: the quantity of lines used in the solution(taken frequency > 0)
- AverageFrequency: the average frequency of service in all conections/edges
- StandardDeviation: the standard deviation for the average above
- Variance: the variance for the average above
- Median: the median value for the average above
- LowestFrequency: the lowest frequency of service among all conections/edges
- HighestFrequency: the highest frequency of service among all conections/edges
- LineCost: the sum of costs for taking all lines in the solution with the given frequency 
"""
function BasicStats(instance::ProblemInstance, solution::Array{T,1} where {T<:Integer})

    stats = Dict{Symbol, Any}()
    edge_frequencies = CalculateFrequencyArray(instance, solution)

    #it is maybe better to just do one loop and calculate these simultaneously
    stats[:QntLines] = length(instance.lines)
    stats[:QntStops] = nv(instance.network)
    stats[:QntEdges] = ne(instance.network)
    stats[:TakenLines] = count(i -> (i > 0), solution)
    stats[:AverageFrequency] = mean(edge_frequencies)
    stats[:StandardDeviation] = std(edge_frequencies, mean = stats[:AverageFrequency])
    stats[:Variance] = var(edge_frequencies, mean = stats[:AverageFrequency])
    stats[:Median] = median(edge_frequencies)
    stats[:LowestFrequency] = minimum(edge_frequencies)
    stats[:HighestFrequency] = maximum(edge_frequencies)
    stats[:LineCost] = CalculateCost(instance, solution)

    return stats

end

function CalculateFrequencyArray(instance::ProblemInstance, solution::Array{Bool,1})
    return CalculateFrequencyArray(instance, [if solution[i] instance.lines[i].frequency else 0 end] for i in 1:length(solution))
end

function CalculateFrequencyArray(instance::ProblemInstance, solution::Array{T,1} where {T<:Integer})
    edge_frequencies = Array{Int64, 1}()

    for e in edges(instance.network)
        push!(edge_frequencies, sum( solution[i] * IsEdgeOnLine(instance, e, i) for i in 1:length(solution)))
    end

    return edge_frequencies

end
