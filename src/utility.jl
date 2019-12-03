 using LightGraphs
using MetaGraphs
using Dates
using CSV
using MathOptInterface
const MOI = MathOptInterface

#=
utility.jl

this script implements various helper functions for LPBasic module usage
    
=#

export IsEdgeOnLine

"""
    IsEdgeOnLine(instance::ProblemInstance, edge::LightGraphs.SimpleGraphs.SimpleEdge, lineIndex::Int64; numerical_returns = false)
Check if the a given *edge* is contained in a the line indexed by *lineIndex* in the given LPBasic problem *instance*.

# Returns:
- true/false
- 1/0, if numerical_returns == true

# Implementation: 
- Has O(1) time complexity, by using an internal dictionary pairing each edge to its respective lines
"""
function IsEdgeOnLine(instance::ProblemInstance, edge::LightGraphs.SimpleGraphs.SimpleEdge, lineIndex::Int64; numerical_returns = false)
    line_coverage = get_prop(instance.network, edge, :line_coverage)
    if haskey(line_coverage, lineIndex)
        if numerical_returns return 1 else return true end
    else 
        if numerical_returns return 0 else return false end
    end

end

function redirect_to_files(dofunc, outfile, errfile)
    open(outfile, "w") do out
        open(errfile, "w") do err
            redirect_stdout(out) do
                redirect_stderr(err) do
                    dofunc()
                end
            end
        end
    end
end

#=calculates great circle distance using the haversine formula https://en.wikipedia.org/wiki/Haversine_formula
this will be used to calculate point to point distances given latitudes and longitudes
supposes the earth to be perfectly round, but the associated error is very small(given our application)
=#
"""
    GreatCircleDistance(latitude1::Number, longitude1::Number, latitude2::Number, longitude2::Number)::Number
Calculate the great circle distance between points (latitude1, longitude1) and (latitude2, longitude2) on the earth's surface.

# Implementation
Uses the Haversine formula(https://en.wikipedia.org/wiki/Haversine_formula) supposing the Earth is perfectly round
"""
function GreatCircleDistance(latitude1::Number, longitude1::Number, latitude2::Number, longitude2::Number)::Number
    ϕ1, ϕ2 = deg2rad(latitude1), deg2rad(latitude2)
    λ1, λ2 = deg2rad(longitude1), deg2rad(longitude2)
    r = 6371e3 #earth radius in meters

    d = 2*r * asin(sqrt(
                sin((ϕ2 - ϕ1) / 2)^2 + 
                cos(ϕ1)*cos(ϕ2)*(sin((λ2-λ1)/2) ^ 2)
    ))

    return d
end

"""
    RunSuite(gtfs_path::String, outpath::String = "./")
Run through the optimization pipeline reading data from gtfs_path and outputting to outpath

Can be used as a sort of example script for the module's usage.
"""
function RunSuite(gtfs_path::String, outpath::String = "./")
    
    instance = nothing
    try
        instance = ReadNatureFeed(gtfs_path)
    catch err
        #stacktrace()
    end

    try
        instance = ReadGTFS(gtfs_path, transportModeCode = 3)
    catch err
        println(err)
        #stacktrace()
    end

    if instance === nothing
        error("Unable to open given gtfs")
    end

    #save initial directory
    initial_dir = pwd()
    #create new directory for results
    path = "$(outpath)_$(Dates.minute(now()))"
    if !isdir(path)
        working_dir = mkdir(path)
    else
        working_dir = path
    end
    cd(working_dir)

    #aux functions
    ms  = (penalty) -> (instance) -> ConstructModel(instance, useSlack = true, slack_penalty = penalty)
    mb = (instance) -> ConstructModel(instance, useBinaryVariant = true)
    mbs = (penalty) -> (instance) -> ConstructModel(instance, useSlack = true, slack_penalty = penalty, useBinaryVariant = true)
    mm = (min_freq) -> (instance) -> ConstructModel(instance, minFrequencyMultiplier = min_freq)
    mmm = (min_freq, max_freq) -> (instance) -> ConstructModel(instance, minFrequencyMultiplier = min_freq, maxFrequencyMultiplier = max_freq)
    mbmm = (min_freq, max_freq) -> (instance) -> ConstructModel(instance, minFrequencyMultiplier = min_freq, maxFrequencyMultiplier = max_freq, useBinaryVariant = true)
    mnmm = (min_freq, max_freq) -> (instance) -> ConstructModel(instance, minFrequencyMultiplier = min_freq, maxFrequencyMultiplier = max_freq, useNonIntegerDecisionVariables = true)
    mmmslack = (min_freq, max_freq, penalty) -> (instance) -> ConstructModel(instance, minFrequencyMultiplier = min_freq, maxFrequencyMultiplier = max_freq, useSlack = true, slack_penalty = penalty, useNonIntegerDecisionVariables = true)
    #modeling_functions = [mm(0.1), mm(0.3), mm(0.5), mm(0.7), mm(0.8), mm(0.9), mm(1.0), mm(1.1), mm(1.2)]
    #names = ["def-01", "def-03", "def-05", "def-07", "def-08", "def-09", "def-10", "def-11", "def-12"]
    #binary = [false, false, false, false, false, false, false, false, false]

    #default
    #modeling_functions = [mmm(0.1, 20.0), mmm(0.2, 20.0), mmm(0.3, 20.0), mmm(0.4, 20.0), mmm(0.5, 20.0), mmm(0.6, 20.0), mmm(0.7, 20.0), mmm(0.8, 20.0), mmm(0.9, 20.0), mmm(1.0, 20.0), mmm(1.1, 20.0), mmm(1.2, 20.0), mmm(1.3, 20.0), mmm(1.4, 20.0), mmm(1.5, 20.0)]
    #names = ["def-01", "def-02", "def-03", "def-04", "def-05", "def-06", "def-07", "def-08", "def-09", "def-10", "def-11", "def-12", "def-13", "def-14", "def-15"]
    #binary = [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]

    #non-integer
    #modeling_functions = [mnmm(0.1, 20.0), mnmm(0.2, 20.0), mnmm(0.3, 20.0), mnmm(0.4, 20.0), mnmm(0.5, 20.0), mnmm(0.6, 20.0), mnmm(0.7, 20.0), mnmm(0.8, 20.0), mnmm(0.9, 20.0), mnmm(1.0, 20.0), mnmm(1.1, 20.0), mnmm(1.2, 20.0), mnmm(1.3, 20.0), mnmm(1.4, 20.0), mnmm(1.5, 20.0)]
    #names = ["ni-01", "ni-02", "ni-03", "ni-04", "ni-05", "ni-06", "ni-07", "ni-08", "ni-09", "ni-10", "ni-11", "ni-12", "ni-13", "ni-14", "ni-15"]
    #binary = [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]

    #slack-100
    penalty = 200.0
    modeling_functions = [mmmslack(0.1, 20.0, penalty), mmmslack(0.2, 20.0, penalty), mmmslack(0.3, 20.0,penalty), mmmslack(0.4, 20.0, penalty), mmmslack(0.5, 20.0, penalty), mmmslack(0.6, 20.0, penalty), mmmslack(0.7, 20.0, penalty), mmmslack(0.8, 20.0, penalty), mmmslack(0.9, 20.0, penalty), mmmslack(1.0, 20.0, penalty), mmmslack(1.1, 20.0, penalty), mmmslack(1.2, 20.0, penalty), mmmslack(1.3, 20.0, penalty), mmmslack(1.4, 20.0, penalty), mmmslack(1.5, 20.0, penalty)]
    names = ["s$(penalty)-01", "s$(penalty)-02", "s$(penalty)-03", "s$(penalty)-04", "s$(penalty)-05", "s$(penalty)-06", "s$(penalty)-07", "s$(penalty)-08", "s$(penalty)-09", "s$(penalty)-10", "s$(penalty)-11", "s$(penalty)-12", "s$(penalty)-13", "s$(penalty)-14", "s$(penalty)-15"]
    binary = [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]



    #plot instance, without solution
    PlotInstance(instance, out_path = "instance_plot.png", should_preview = false)

    #new dataframes:
    df1 = DataFrame()
    df_upper = DataFrame()
    df_lower = DataFrame()
    df_rest = DataFrame()
    df_dual = DataFrame()
    df_stats = nothing

    println("length: $(length(instance.lines))")
    yb = Array{Bool, 1}()
    for i in 1:length(instance.lines)
        push!(yb, true)
    end
    total_possible_cost = CalculateCost(instance,yb)

    i = 1
    #redirects stdout and stderr
    redirect_to_files("stdout.log", "stderr.log") do 
        for f in modeling_functions
            model = f(instance)
            name = names[i]

            println("Starting $name model")

                println("Optimization model number $(i): $(name)")

                time = @elapsed begin optimize!(model, with_optimizer(Cbc.Optimizer)) end
				
				try

					#dump log_string into file
					open("$(name)-out.txt", "w") do f
						println(f, name)
						print(f, model)
						println(f, termination_status(model))
						if termination_status(model) == MOI.OPTIMAL
                            println(f, primal_status(model))
                            println(f, "objective value", objective_value(model))
						else
                            println(f, "primal_status, NaN")
                            println(f, "objective value", "NaN")
						end
					end
				catch e
				
				end

                #new dataframe for results
                vars = JuMP.all_variables(model)
                qtd_lines = length(instance.lines)
                n_edges = ne(instance.network)

                y = Array{Int64, 1}()
                yb = Array{Bool, 1}()
                
                l_slack = Array{Int64, 1}()
                u_slack = Array{Int64, 1}()
                if termination_status(model) == MOI.OPTIMAL        
                    for i = 1:length(vars)
                        if i <= qtd_lines
                            push!(y, round(Int64, value(vars[i])))
                            push!(yb, value(vars[i]) > 0)
                        elseif i <= qtd_lines + n_edges
                            push!(l_slack, round(Int64, value((vars[i]))))
                        else #if i <= qtd_lines + n_edges + n_edges ==? length(vars)
                            push!(u_slack, round(Int64, value((vars[i]))))
                        
                        end
                        
                    end
                else
                    for i = 1:length(vars)
                        if i <= qtd_lines
                            push!(y, 0)
                            push!(yb, false)
                        elseif i <= qtd_lines + n_edges
                            push!(l_slack, 0)
                        else #if i <= qtd_lines + n_edges + n_edges ==? length(vars)
                            push!(u_slack, 0)
                        end 
                        
                    end
                end
                
                col_name = Symbol(name)
                df1[!, col_name] = y
                
                
                if(length(l_slack) > 0)
                    
                    df_lower[!,col_name] = l_slack
                    df_upper[!,col_name] = u_slack
                else
                    df_lower[!,col_name] = [0 for i in 1:n_edges]
                    df_upper[!,col_name] = [0 for i in 1:n_edges]
                end
                

                if binary[i]
                    stats = BasicStats(instance, yb)
                else
                    stats = BasicStats(instance, y)
                end

				obj_value = nothing
                if termination_status(model) == MOI.OPTIMAL
					obj_value = JuMP.objective_value(model)
				else
					obj_value = Inf
				end
                

                stats[:PenaltyCost] = obj_value - stats[:LineCost] 
                stats[:ObjectiveValue] = obj_value
                stats[:ElapsedTime] = time
                stats[:PercOfMaxCost] = obj_value / total_possible_cost
                #total possible cost, for for flexible optimization, is a good upper bound, but not really the maximum cost anymore
                stats[:MaxCost] = total_possible_cost

                if(df_stats === nothing)
                    df_stats = DataFrame()
                    keys = [key for (key, _) in stats]
                    df_stats[!,:model] = Any[]
                    for (key,_) in stats
                        df_stats[!, key] = Any[]
                    end
                end
                
                values = Array{Any,1}()
                pushfirst!(values, name)
                for (_,value) in stats 
                    push!(values, value)                
                end

                push!(df_stats, values)

                #a dataframe for this model, so its easier to interpret
                
                
                df_results = DataFrame()
                df_restrictions = DataFrame()
                df_results[!,:y] = y
                df_results[!,:yb] = yb
                constraint_type = Array{String, 1}()
                constraint_type2 = Array{String, 1}()
                constraint_slack = Array{Float64,1}()
                shadow_price_arr = Array{Float64,1}()
                dual_arr = Array{Float64,1}()
                for ctr_type in list_of_constraint_types(model)
                    for ctr in all_constraints(model, ctr_type[1], ctr_type[2])
                        push!(constraint_type, string(ctr_type[1]))
                        push!(constraint_type2, string(ctr_type[2]))
                        if has_duals(model)
                            push!(shadow_price_arr, shadow_price(ctr))
                            push!(dual_arr, dual(ctr))
                        else
                            push!(shadow_price_arr, NaN)
                            push!(dual_arr, NaN)
                        end
                    end
                end
                df_restrictions[!,:constraint_type] = constraint_type
                df_restrictions[!,:constraint_type2] = constraint_type2
                df_restrictions[!,:dual] = dual_arr
                df_restrictions[!,:shadow_price] = shadow_price_arr
                #shadow_price

                CSV.write("$(name)-results.csv", df_results)
                CSV.write("$(name)-restriction.csv", df_restrictions)
                

                PlotSolution(instance, yb, out_path = name * "_solution.png", should_preview = false)

            i += 1
            
        end
    end

    println("Writing data to csv")
    #write dataframes
    CSV.write("solutions.csv", df1)
    CSV.write("slack_upper.csv", df_upper)
    CSV.write("slack_lower.csv", df_lower)
    CSV.write("stats.csv", df_stats)

    #go back to initial dir
    cd(initial_dir)

    println("Finished")
    
end