var documenterSearchIndex = {"docs":
[{"location":"#The-LPBasic-module-1","page":"The LPBasic module","title":"The LPBasic module","text":"","category":"section"},{"location":"#About-LPBasic.jl-1","page":"The LPBasic module","title":"About LPBasic.jl","text":"","category":"section"},{"location":"#","page":"The LPBasic module","title":"The LPBasic module","text":"LPBasic.jl is a julia module to facilitate JuMP framework's usage for an specific line planning optimization model called LPBasic. It was developed as part of a graduation project at PUC-Rio by Computer Science student André Mazal Krauss during 2019. ","category":"page"},{"location":"#","page":"The LPBasic module","title":"The LPBasic module","text":"For more information visit the project's github page and read the report(in portuguese). You may also contact me directly: amk1710@gmail.com ","category":"page"},{"location":"#LPBasic.jl-Documentation-1","page":"The LPBasic module","title":"LPBasic.jl Documentation","text":"","category":"section"},{"location":"#","page":"The LPBasic module","title":"The LPBasic module","text":"CurrentModule = LPBasic","category":"page"},{"location":"#Dependencies-1","page":"The LPBasic module","title":"Dependencies","text":"","category":"section"},{"location":"#","page":"The LPBasic module","title":"The LPBasic module","text":"The following list includes all direct depencies for the full module's functionality. These dependencies might have their own dependencies, but Julia's  Pkg should resolve them automatically. ","category":"page"},{"location":"#","page":"The LPBasic module","title":"The LPBasic module","text":"Also note that OpenStreetMapPlot is not included in Julia's Registry. However, the package's website has straighforward install instructions. It's only use is to render transport networks with OpenStreetMap information(methods PlotInstance and PlotSolution), so it is possible to use the module without it if so desired. ","category":"page"},{"location":"#","page":"The LPBasic module","title":"The LPBasic module","text":"CSV (https://github.com/JuliaData/CSV.jl)\nColors (https://github.com/JuliaGraphics/Colors.jl)\nJuMP (https://github.com/JuliaOpt/JuMP.jl)\nLightGraphs(https://github.com/JuliaGraphs/LightGraphs.jl)\nLuxor(https://github.com/JuliaGraphics/Luxor.jl)\nMathOptInterface(https://github.com/JuliaOpt/MathOptInterface.jl)\nMetaGraphs(https://github.com/JuliaGraphs/MetaGraphs.jl)\nOpenStreepMapX(https://github.com/pszufe/OpenStreetMapX.jl)\nOpenStreetMapXPlot(https://github.com/pszufe/OpenStreetMapXPlot.jl)\nPlots(https://github.com/JuliaPlots/Plots.jl)","category":"page"},{"location":"#Function-Index-1","page":"The LPBasic module","title":"Function Index","text":"","category":"section"},{"location":"#","page":"The LPBasic module","title":"The LPBasic module","text":"Modules = [LPBasic]","category":"page"},{"location":"#Module-1","page":"The LPBasic module","title":"Module","text":"","category":"section"},{"location":"#","page":"The LPBasic module","title":"The LPBasic module","text":"LPBasic","category":"page"},{"location":"#LPBasic","page":"The LPBasic module","title":"LPBasic","text":"LPBasic Module\n\nJulia module implementing the LPBasic line planning problem.  \n\nThis includes:  \n\ndefining structs for containing the relevant problema data  \nimplementing IO functionality to read relevant data from GTFS data into such structs  \na flexible functionality to construct JuMP models from such structs  \nsome visualization functionality  \n\n\n\n\n\n","category":"module"},{"location":"#Data-Structures-1","page":"The LPBasic module","title":"Data Structures","text":"","category":"section"},{"location":"#","page":"The LPBasic module","title":"The LPBasic module","text":"Line\r\nProblemInstance","category":"page"},{"location":"#Main.LPBasic.Line","page":"The LPBasic module","title":"Main.LPBasic.Line","text":"Line\n\nA basic data structure for model construction. Represents a directed walk through a transportation network  \n\nConstructor:\n\nLine(id::Union{Int64, String}, walk::Array{Tuple{Int64, Int64}, 1}, frequency::Int64, cost::Float64)\n\nFields:\n\nid::Union{Int64, String} - an Int64 or String to help distinguis this lines from other lines. Uniqueness is not enforced  \nwalk::Array{Tuple{Int64, Int64}, 1} - an array of edge indices, representing a directed walk through the transportation network  \nfrequency::Int64 - the base frequency for this line  \ncost::Float64 - the cost per frequency unit of this line  \n\n\n\n\n\n","category":"type"},{"location":"#Main.LPBasic.ProblemInstance","page":"The LPBasic module","title":"Main.LPBasic.ProblemInstance","text":"ProblemInstance\n\nStruct containing all data of a single LPBasic problem's instance.\n\nConstructor:\n\nProblemInstance(network::MetaDiGraph, lines::Array{Line,1})\n\nFields:\n\nnetwork::MetaDiGraph - representation the transportation network\nlines::Array{Line,1} - array containing all lines to be considered in the optimization \n\n\n\n\n\n","category":"type"},{"location":"#IO-Functionality-1","page":"The LPBasic module","title":"IO Functionality","text":"","category":"section"},{"location":"#","page":"The LPBasic module","title":"The LPBasic module","text":"ReadGTFS\r\nReadNatureFeed","category":"page"},{"location":"#Main.LPBasic.ReadGTFS","page":"The LPBasic module","title":"Main.LPBasic.ReadGTFS","text":"ReadGTFS(directory_path, transportModeCode=3)::ProblemInstance\n\nRead the data in an uncompressed GTFS feed into a ProblemInstance struct.  \n\nThe transportModeCode parameter defines which mode of transportation should be considered, with the default value = 3 indicating buses. Another common value would be 1 for trains.\n\n\n\n\n\n","category":"function"},{"location":"#Main.LPBasic.ReadNatureFeed","page":"The LPBasic module","title":"Main.LPBasic.ReadNatureFeed","text":"ReadNatureFeed(directory_path)::ProblemInstance\n\nRead data from a feed as specified in this article  \n\n\n\n\n\n","category":"function"},{"location":"#Model-Construction-1","page":"The LPBasic module","title":"Model Construction","text":"","category":"section"},{"location":"#","page":"The LPBasic module","title":"The LPBasic module","text":"ConstructModel","category":"page"},{"location":"#Main.LPBasic.ConstructModel","page":"The LPBasic module","title":"Main.LPBasic.ConstructModel","text":"function ConstructModel(instance::ProblemInstance; <keyword arguments>)::Model\n\nConstruct a JuMP model from the LPBasic problem instance and return it.\n\nArguments\n\nuseSlack::Bool=false: whether to use slackened constraints. If used, slack_penalty must be defined\nslack_penalty::Float64: the penalty taken to the objective-value for each unit of slack taken  \nuseBinaryVariant::Bool=false: whether to use binary decision variables  \nminFrequencyMultiplier::Number=0.5: the multiplier used to estimate an edge's minimum frequency requirement from the edge's base frequency\nmaxFrequencyMultiplier::Number=2.0: the multiplier used to estimate an edge's maximum frequency requirement from the edge's base frequency\nuseNonIntegerDecisionVariables=false: whether to use relaxed, non-integer decision variables\n\n\n\n\n\n","category":"function"},{"location":"#Visualization-1","page":"The LPBasic module","title":"Visualization","text":"","category":"section"},{"location":"#","page":"The LPBasic module","title":"The LPBasic module","text":"PlotInstance\r\nPlotSolution","category":"page"},{"location":"#Main.LPBasic.PlotInstance","page":"The LPBasic module","title":"Main.LPBasic.PlotInstance","text":"function PlotInstance(instance::ProblemInstance, osmpath::String)\n\nReturn a plot of the given instance using the given Open Street Map information.\n\nSubstantially slower than the PlotInstance method not using OSM information, but the result is better looking.\n\n\n\n\n\nPlotInstance(instance::ProblemInstance; out_path::String = \"./\", should_preview = true)\n\nReturn a simple Luxor drawing of the given instance\n\nSubstantially faster than the PlotInstance method using Open Street Map information, but draws only simple lines on a blank background.\n\n\n\n\n\n","category":"function"},{"location":"#Main.LPBasic.PlotSolution","page":"The LPBasic module","title":"Main.LPBasic.PlotSolution","text":"PlotSolution(instance::ProblemInstance, solution::Array{Bool, 1}, osmpath::String)\n\nIdentical to PlotInstance(instance::ProblemInstance, osmpath::String), but paint unused lines differently\n\nSubstantially slower than the PlotSolution method not using OSM information, but the result is better looking.\n\n\n\n\n\nPlotSolution(instance::ProblemInstance, solution::Array{Bool, 1};  <keyword arguments>)\n\nReturn a simple Luxor drawing of the given instance, painting lines used in solution differently\n\nKeywork arguments:\n\n[out_path]: optional path determining where to save the image. If this isn't set, a time-stamped name will be used\nshould_preview=true: should the image be previewed in the default image viewer?\n\n\n\n\n\n","category":"function"},{"location":"#Miscellaneous-1","page":"The LPBasic module","title":"Miscellaneous","text":"","category":"section"},{"location":"#","page":"The LPBasic module","title":"The LPBasic module","text":"IsEdgeOnLine\r\nCalculateCost\r\nRunSuite\r\nBasicStats\r\nVerifyInstance\r\nVerifySolution\r\nGreatCircleDistance","category":"page"},{"location":"#Main.LPBasic.IsEdgeOnLine","page":"The LPBasic module","title":"Main.LPBasic.IsEdgeOnLine","text":"IsEdgeOnLine(instance::ProblemInstance, edge::LightGraphs.SimpleGraphs.SimpleEdge, lineIndex::Int64; numerical_returns = false)\n\nCheck if the a given edge is contained in a the line indexed by lineIndex in the given LPBasic problem instance.\n\nReturns:\n\ntrue/false\n1/0, if numerical_returns == true\n\nImplementation:\n\nHas O(1) time complexity, by using an internal dictionary pairing each edge to its respective lines\n\n\n\n\n\n","category":"function"},{"location":"#Main.LPBasic.CalculateCost","page":"The LPBasic module","title":"Main.LPBasic.CalculateCost","text":"CalculateCost(instance::ProblemInstance, solution::Array{Bool,1})::Float64\n\nCalculate total line cost for given solution on given instance.\n\nA solution for this method is an array of booleans indicating accepting or rejecting a line with its basic frequency\n\n\n\n\n\nCalculateCost(instance::ProblemInstance, solution::Array{Bool,1})::Float64\n\nCalculate total line cost for given solution on given instance.\n\nA solution for this method is an array of integers representing each line's taken frequency\n\n\n\n\n\n","category":"function"},{"location":"#Main.LPBasic.RunSuite","page":"The LPBasic module","title":"Main.LPBasic.RunSuite","text":"RunSuite(gtfs_path::String, outpath::String = \"./\")\n\nRun through the optimization pipeline reading data from gtfs_path and outputting to outpath\n\nCan be used as a sort of example script for the module's usage.\n\n\n\n\n\n","category":"function"},{"location":"#Main.LPBasic.BasicStats","page":"The LPBasic module","title":"Main.LPBasic.BasicStats","text":"BasicStats(instance::ProblemInstance, solution::Array{Bool,1})\n\nBoolean/binary variant of the BasicStats function. \n\nIn this solution, each line has 0 frequency or its base-frequency\n\n\n\n\n\nBasicStats(instance::ProblemInstance, solution::Array{T,1} where {T<:Integer})\n\nPopulate and return a dictionary with basic information about the instance and solution.\n\nThe returned dictinary has the following key/value pairings:\n\nQntLines: the quantity of lines considered in the instance\nQntStops: the quantity of stops/nodes in the transportation network/graph\nQntEdges: the quantity of conections/edges in the transportation network/graph\nTakenLines: the quantity of lines used in the solution(taken frequency > 0)\nAverageFrequency: the average frequency of service in all conections/edges\nStandardDeviation: the standard deviation for the average above\nVariance: the variance for the average above\nMedian: the median value for the average above\nLowestFrequency: the lowest frequency of service among all conections/edges\nHighestFrequency: the highest frequency of service among all conections/edges\nLineCost: the sum of costs for taking all lines in the solution with the given frequency \n\n\n\n\n\n","category":"function"},{"location":"#Main.LPBasic.VerifyInstance","page":"The LPBasic module","title":"Main.LPBasic.VerifyInstance","text":"VerifyInstance(network::MetaDiGraph, lines::Array{Line,1})\nVerifyInstance(instance::ProblemInstance)\n\nVerify if a given problem instance is valid per the LPBasic requirements. Raise error if there are inconsistensies, otherwise return true.\n\nThis includes checking if:  \n\nall lines are unique(unique id, unique walk, unique frequency)  \neach edge has defined its expected properties  \nthere are no invalid values for frequencies and weights    \n\nto-do:\n\nis the network/graph is connected?(is there is a path between every pair of vertices?)  \nredundant information matches one another? (:line_coverage)  \n\nreturn value:\n\ntrue - indicating that the instance is valid, or  \nraise error - indicating that the instance is not valid and the reason why  \n\n\n\n\n\nVerifyInstance(instance::ProblemInstance)\n\nDo the same as VerifyInstance(instance.network, instance.lines)\n\n\n\n\n\n","category":"function"},{"location":"#Main.LPBasic.VerifySolution","page":"The LPBasic module","title":"Main.LPBasic.VerifySolution","text":"VerifySolution(instance::ProblemInstance, solution::Array{Bool,1})\n\nVerify if a given solution is feasible per the LPBasic requirements.\n\nAlso check for construction errors in the instance and solution itself Return a tuple (true,\"Valid\") or (false, <error_string>)\n\n\n\n\n\n","category":"function"},{"location":"#Main.LPBasic.GreatCircleDistance","page":"The LPBasic module","title":"Main.LPBasic.GreatCircleDistance","text":"GreatCircleDistance(latitude1::Number, longitude1::Number, latitude2::Number, longitude2::Number)::Number\n\nCalculate the great circle distance between points (latitude1, longitude1) and (latitude2, longitude2) on the earth's surface.\n\nImplementation\n\nUses the Haversine formula(https://en.wikipedia.org/wiki/Haversine_formula) supposing the Earth is perfectly round\n\n\n\n\n\n","category":"function"},{"location":"#Authoring-information-1","page":"The LPBasic module","title":"Authoring information","text":"","category":"section"},{"location":"#","page":"The LPBasic module","title":"The LPBasic module","text":"Author: André Mazal Krauss, Computer Sciences student at Pontifícia Universidade Católica do Rio Janeiro(PUC-Rio)","category":"page"},{"location":"#","page":"The LPBasic module","title":"The LPBasic module","text":"Project Supervision: Marcus Poggi","category":"page"}]
}
