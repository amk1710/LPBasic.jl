using LightGraphs
using MetaGraphs
using JuMP
using Cbc

#=
optimization.jl:

models(using JuMP) some variations around the vanilla LPBasic optimization problem. 

=#

export ConstructModel


"""
    function ConstructModel(instance::ProblemInstance; <keyword arguments>)::Model

Construct a JuMP model from the LPBasic problem instance and return it.

# Arguments
- `useSlack::Bool=false`: whether to use slackened constraints. If used, slack_penalty must be defined
- `slack_penalty::Float64`: the penalty taken to the objective-value for each unit of slack taken  
- `useBinaryVariant::Bool=false`: whether to use binary decision variables  
- `minFrequencyMultiplier::Number=0.5`: the multiplier used to estimate an edge's minimum frequency requirement from the edge's base frequency
- `maxFrequencyMultiplier::Number=2.0`: the multiplier used to estimate an edge's maximum frequency requirement from the edge's base frequency
- `useNonIntegerDecisionVariables=false`: whether to use relaxed, non-integer decision variables

"""
function ConstructModel(instance::ProblemInstance; useSlack::Bool = false, slack_penalty::Union{Nothing, Float64} = nothing, useBinaryVariant::Bool = false, minFrequencyMultiplier::Number = 0.5, maxFrequencyMultiplier::Number = 2.0, useNonIntegerDecisionVariables = false)::Model
    if slack_penalty == 0.0
        @warn "Setting slack to zero should cause the optimization to not choose any line for the solution."
    end
    if slack_penalty != nothing && ~useSlack
        @warn "Slack penalty is set, but useSlack is not set to true. If the use of slackened constraints is intended, please set the useSlack argument to true"
    end
    if minFrequencyMultiplier > maxFrequencyMultiplier
        @warn "min/max base-frequency multiplier choice may result in an unsolvable model: $(minFrequencyMultiplier), $(maxFrequencyMultiplier)"
    end
    if useNonIntegerDecisionVariables && useBinaryVariant
        error("Unable to use both binary and non-integer decision variables simultaneously")
    end
    
    #creates JuMP model
    model = Model()

    #add decision variables
    if useBinaryVariant
        #we use binary decision variables: each line can either be fully taken(with a preset frequency), or not taken at all
        @variable(model, y[1:length(instance.lines)], Bin, container = Array)
    elseif useNonIntegerDecisionVariables
        #variables are not constrained as integers
        @variable(model, y[1:length(instance.lines)] >= 0, container = Array)
    else
        #if flexible frequencies are used, the default behaviour, we use integer decision variables:
        #thus, each line can be taken with an arbitrary frequency (including 0 for not taken)
        @variable(model, y[1:length(instance.lines)] >= 0, Int, container = Array)
    
    end
    #rethinking this restriction, I thought: why cant I just use float values here? The representation with frequencies over a T time span is already an aproximation of real operations anyway...

    if useSlack && !useNonIntegerDecisionVariables
        #slack variables for the altered formulation
        @variable(model, l_slack[1:ne(instance.network)] >= 0, Int, container = Array) #lower slack
        @variable(model, u_slack[1:ne(instance.network)] >= 0, Int, container = Array) #upper slack
        #the cost penalty should stop the optimizer from using both simultaneously for any single edge
    elseif useSlack && useNonIntegerDecisionVariables
        #slack variables not constrained to integer values
        @variable(model, l_slack[1:ne(instance.network)] >= 0, container = Array) #lower slack
        @variable(model, u_slack[1:ne(instance.network)] >= 0, container = Array) #upper slack
        
    end
    
    #shortcut auxiliary function for clearer reading:
    IsEdgeOnLine_A(edge::LightGraphs.SimpleGraphs.SimpleEdge, lineIndex::Int64) = IsEdgeOnLine(instance, edge, lineIndex, numerical_returns = true)

    #collect edges
    edges_array = [e for e in edges(instance.network)]

    #add frequency restrictions
    for i in 1:length(edges_array)
        e = edges_array[i]
        
        #f_min and f_max estimation: turns out to be pretty important in practical experimentation
        f_min = Int64(ceil(get_prop(instance.network, e, :base_freq) * minFrequencyMultiplier)) #ceil is important so we pretty much never get a 0 value, which could cause the line set to not be connected
        f_max = Int64(round(get_prop(instance.network, e, :base_freq) * maxFrequencyMultiplier))

        #=
        #this has sometimes raised a warning about to many unperformant additions beeing called. Maybe restructure it? to-do
        @constraint(model, f_min <= 
        
        if useBinaryVariant
            sum(instance.lines[j].frequency * y[j] * IsEdgeOnLine_A(e, j) for j in 1:length(instance.lines))
        else
            #y[j] already represent a variable line frequency. thus we do not multiply it by instance.lines[j].frequency
            sum(y[j] * IsEdgeOnLine_A(e, j) for j in 1:length(instance.lines))
        end
        +
        if ~useSlack
            0
        else
            #plus l_slack, so having some l_slack != 0 helps accomodate the lower limit
            #minus u_slack, helping with the upper limit
            l_slack[i] - u_slack[i]
        end
        
        <= f_max)
        =#

        
        ex = @expression(model, 
            if useBinaryVariant
                sum(instance.lines[j].frequency * y[j] * IsEdgeOnLine_A(e, j) for j in 1:length(instance.lines))
            else
                #y[j] already represent a variable line frequency. thus we do not multiply it by instance.lines[j].frequency
                sum(y[j] * IsEdgeOnLine_A(e, j) for j in 1:length(instance.lines))
            end
            
            +
            if ~useSlack
                0
            else
                #plus l_slack, so having some l_slack != 0 helps accomodate the lower limit
                #minus u_slack, helping with the upper limit
                l_slack[i] - u_slack[i]
            end
            
        )
        
        
        @constraint(model, f_min <= ex <= f_max)
    end

    @objective(model, Min,
        if useBinaryVariant
            sum(y[i] * instance.lines[i].cost * instance.lines[i].frequency for i=1:length(instance.lines))
        else
            #y[i] already represents the taken frequency
            sum(y[i] * instance.lines[i].cost for i=1:length(instance.lines))
        end
        +
        if ~useSlack
            0 #if not using slack, slack penalty is 0
        else
            #sum of taken slack * slack_penalty
            sum( (l_slack[i] + u_slack[i]) * slack_penalty for i=1:ne(instance.network))
        end
    )

    return model
end


