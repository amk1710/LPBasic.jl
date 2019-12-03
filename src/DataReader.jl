
#=
DataReader.jl
This script implements basic IO functionalities reading data from the files described at (https://www.nature.com/articles/sdata201889) into an in-memory data structure. Possible improvements include rethinking data structure use-cases, reading directly from GTFS files, investigating possible gains of using the MetaGraphs Julia package, and supporting multiple edges between nodes.
=#

export ReadNatureFeed, ReadGTFS

#importing all necessary packages
using DataFrames
using LightGraphs
using CSV
using MetaGraphs

#function gets as parameter a directory path containing the necessary files described in Nature's article
"""
	ReadNatureFeed(directory_path)::ProblemInstance
Read data from a feed as specified in [this article](https://www.nature.com/articles/sdata201889)  
"""
function ReadNatureFeed(directory_path)::ProblemInstance

	#checks if all needed files exist and loads them into dataframes:
	
	nodes_path = string(directory_path, "network_nodes.csv")
	edges_path = string(directory_path, "network_bus.csv") #loading the bus dataset for now
	temp_day_path = string(directory_path, "network_temporal_day.csv")
	stats_path = string(directory_path, "stats.csv")
	

	#why load all files into memory simultaneously?
	#reads network nodes into dataframe, if file exists. Else, raises error
	if isfile(nodes_path)
		nodes = CSV.read(nodes_path)
	else
		error(string("File ", nodes_path, " not found"))
	end
		
	#reads network connections into dataframe, if file exists. Else, raises error
	if isfile(edges_path)
		edges_df = CSV.read(edges_path)
	else
		error(string("File ", edges_path, " not found"))
	end
	
	# "", network_temporal_day 
	#we extract, from the network_temporal_day file, infos about each route
	if isfile(temp_day_path)
		temp_day = CSV.read(temp_day_path)
	else
		error(string("File ", temp_day_path, " not found"))
	end

	if isfile(stats_path)
		stats_df = CSV.read(stats_path)
	else
		error(string("File ", stats_path, " not found"))
	end


	#existem arestas paralelas no grafo?
	edges_set = Set{Tuple{Int64, Int64}}()

	for row in eachrow(edges_df)
		edge = (row.from_stop_I, row.to_stop_I)
		if in(edge, edges_set)
			error("Error: parallel edges were detected in the network graph, but are not currently supported")
		else
			push!(edges_set, edge)
		end
	end

	#a identificação dos vértices é feita por inteiros, mas estes vem do arquivo e não necessariamente tem o índice < n_nodes

	#por isso, além de criar o grafo, crio um dicionário auxiliar que mapeia cada índice original ao seu novo índice
	#posso, posteriormente, criar outro dicionário para o processo reverso, caso seja necessário

	n_nodes = size(nodes, 1)
	graph = SimpleDiGraph(n_nodes)
	metagraph = MetaDiGraph(graph)
	new_indices = Dict{Int64, Int64}()

	i = 1
	for row in eachrow(nodes)
		new_indices[row.stop_I] = i
		
		#set properties for storing a stop's latitude and longitude
		set_props!(metagraph, i, Dict(:latitude => row.lat, :longitude => row.lon, :name => row.name) )

		i = i + 1
	end


	#important note: lightgraphs does not allow for multiple edges between two nodes

	#creates a problem instance given the above information

	n_edges = size(edges_df, 1)

	for row in eachrow(edges_df)
		#metagraph
		s,d = new_indices[row.from_stop_I], new_indices[row.to_stop_I] #source and destination nodes
		edge = Edge(s,d)
		add_edge!(metagraph, edge)
		set_prop!(metagraph, Edge(s,d), :weight, row.d * 1.0 + row.duration_avg * 0.0) #the weight of the edge is given as a function of the distance and the avg time
		
		#route_I_counts field: list (string)
		#as in https://www.nature.com/articles/sdata201889/tables/7
		#=
			A list of route_I's and the number of times each route has operated between two stops. 
		For the network extracts, this data is formatted as a string where each element is written as ``route_I:count'' and different routes are separated by a comma. 
		An example value for this field is thus ``1:3,2:131,10:93''. (...)Please note that the definition of a route varies across the cities provided, 
		and that routes can have deviations from their main paths for instance when traveling to and from a depot.

			I use this field to estimate the minimum frequency requirements for the given edge. I heuristically assume the minimum frequency keep the same number of vehicles described by the network.
				This should guarantee that any optimization done at least mantains a similar level of service, for each edge
		=#
		str = row.route_I_counts
		sum = 0 # the sum of all vehicles covering this edge
		#route_coverage = Array{Int64,1}() #the routes id's covering this specific edge. ###### NOTE THAT, FOR NOW, THERE IS NO GUARANTEE THAT THE ID IS UNIQUE PER LINE (TO DO)########
		for m in eachmatch(r"(\d+)\:(\d+)", str)
			#push!(route_coverage, parse(Int64, m.captures[1]))
			sum += parse(Int64, m.captures[2])
		end

		set_prop!(metagraph, Edge(s,d), :base_freq, sum)
		
		#I'm removing these properties so I can place these kind of approximations in the ConstructModel function itself
		set_prop!(metagraph, Edge(s,d), :f_min, Int64(ceil(sum*0.5))) #setting it to floor may make requirements drop to zero on some edges
		set_prop!(metagraph, Edge(s,d), :f_max, Int64(sum*10))

		#line_coverage is a dict containing each line covering this line, mapping to is frequency
		#however, it isn't populated now because we haven't constructed the lines array yet
		set_prop!(metagraph, Edge(s,d), :line_coverage, Dict{Int64, Int64}())

	end

	#constructing the routes array

	#temporary, i just want to check if tripIds are unique
	all_trips = Set{Int64}()

	#this temporary dictionary records walks and their respective (id, frequency, cost, trip_id)
	#trip_id is later discarded, but it is useful for debugging
	walks_read = Dict{Array{Tuple{Int64, Int64}}, Tuple{Int64, Int64, Float64, Int64}}()

	routes_read = Set{Int64}()
	count = 0
	invalid_route = false
	i, row_count = 1, size(temp_day, 1)
	while i <= row_count # -1 
		col = temp_day[i, :]

		#read the route in this column:
		routeId = col.route_I
		tripId = col.trip_I

		if in(tripId, all_trips)
			error("trip ids are not unique!" * string(tripId))
		else
			push!(all_trips, tripId)
		end
		
		#read the entire route,
		walk = Array{Tuple{Int64, Int64}, 1}()
		walk_cost = 0.0
		invalid_route = false
		while i <= row_count && tripId == temp_day[i, :trip_I] #we've not reached the end of the data-frame and we're still reading the same trip
			col = temp_day[i, :]

			#the edge is a tuple indicating its origin and destination nodes,
			#and we have to take the new node numeration as defined above
			s,d = new_indices[col.from_stop_I], new_indices[col.to_stop_I]
			
			#if a route isn't of the bus mode,
			#or if an edge in the route has not been added to the network, it means this route is not in the same mode of transport we've loaded
			#thus we should ignore it for now
			if col.route_type != 3 || ~has_edge(metagraph, s, d) #3 is the identifier for the 'bus' mode in a GTFS feed(https://developers.google.com/transit/gtfs/reference/)
				invalid_route = true
				i += 1
				continue # continue is used instead of break to make the iteration run to the end of this unwanted trip
			end
			
			edge = (s,d)
			push!(walk, edge)

			#increment walk's total cost. The cost per edge is given by a funcion of the edge's distance and time
			walk_cost += get_prop(metagraph, s, d, :weight)
			i += 1
		end

		if ~invalid_route
			#counts how many unique route identifiers there are
			count += 1
			push!(routes_read, routeId)

			#if the route I just read had not been read yet,
			if ~haskey(walks_read, walk) 
				walks_read[walk] = (routeId, 1, walk_cost, tripId)
			else
				#increment the walk's frequency
				walks_read[walk] = (walks_read[walk][1], walks_read[walk][2] + 1, walks_read[walk][3], walks_read[walk][4])
			end
		end		
	end

	#FILTERING WALKS:
	#it is common that some routes feature little variations during the day, making them register as an unique walk. We discard these instances
	#freq_threshold = 1 #possibly parametrize this later
	#walks_read = filter((pair) -> pair.second[2] > freq_threshold, walks_read) #filter to remove frequency values < freq_threshold
	
	#=
	#it is also common for different walks to be part of the same line(as in: one way and back). We merge these into one bigger walk
	walks_dict_perID = Dict{Int64, Tuple{Array{Tuple{Int64, Int64}, 1}, Int64, Float64}}() #dictionary of (walks, freq, cost), indexed per id
	for (k,v) in walks_read
		id = v[1]
		if haskey(walks_dict_perID, id) #if we've already seen this ID, but its a different walk,
			#try to merge the two walks into one
			println("Merging two walks. Id: $(id)")
			freq = v[2]
			if walks_dict_perID[id][2] != v[2]
				@warn "Merging two walks with different frequencies. Lowest frequency is kept"
				freq = min(walks_dict_perID[id][2], v[2])
			end
			walk = vcat(walks_dict_perID[id][1], k)
			cost = v[3] + walks_dict_perID[id][3]
			walks_dict_perID[id] = (walk, freq, cost)
		else
			walks_dict_perID[id] = (k, v[2], v[3])
		end
	end
	=#

	#possibly divide the frequency for a given time period (24h) and/or filter lines with too low a frequency
	
	#take every read walk, its frequency and create the lines array
	lines = Array{Line, 1}()
	for (k,v) in walks_read
		line = Line(v[1], k, v[2], v[3])
		push!(lines, line)
	end
	

	#println("unique route ids:" ,  length(routes_read))
	#println("Unique lines:", length(lines))
	#println("Count:", count)


	#iterate through the lines array, adding some redundant info on the graphs edges that refer back to each line
	# O(e*v), isn't great, but will contribute to avoiding constant O(e*v) checks in the future
	for i in 1:length(lines)
		line = lines[i]
		for (s, d) in line.walk
			dict = get_prop(metagraph, Edge(s, d), :line_coverage)
			dict[i] = line.frequency
			set_prop!(metagraph, Edge(s,d), :line_coverage, dict)
		end
	end

	#add some useful (for plotting) info to the metagraph
	set_prop!(metagraph, :buffer_center_lat, stats_df[1, :buffer_center_lat])
	set_prop!(metagraph, :buffer_center_lon, stats_df[1, :buffer_center_lon])
	set_prop!(metagraph, :buffer_radius_km, stats_df[1, :buffer_radius_km])

	#finally, construct new problem instance

	problemInstance = ProblemInstance(metagraph, lines)
	return problemInstance

#ends ReadProblemInstance function
end


"""
	ReadGTFS(directory_path, transportModeCode=3)::ProblemInstance

Read the data in an uncompressed GTFS feed into a ProblemInstance struct.  
  	
The transportModeCode parameter defines which mode of transportation should
be considered, with the default value = 3 indicating buses. Another common value would be 1 for trains.

"""
function ReadGTFS(directory_path::String; transportModeCode::Int64 = 3)::ProblemInstance
	#checks if all needed files exist and loads them into dataframes:
	
	nodes_path = string(directory_path, "stops.txt")
	routes_path = string(directory_path, "routes.txt")
	trips_path = string(directory_path, "trips.txt")
	stop_times_path = string(directory_path, "stop_times.txt")

	#why load all files into memory simultaneously?

	#reads network nodes into dataframe, if file exists. Else, raises error
	if !isfile(nodes_path)
		error("File " * nodes_path * " not found")
	end
	nodes = CSV.read(nodes_path)

	if !isfile(routes_path)
		error("File " * routes_path * " not found")
	end
	routes = CSV.read(routes_path)
	#a mapping of route ids to route_type
    route_types = Dict{Any, Int}()
    for row in eachrow(routes) 
        if(row.route_id !== DataFrames.missing && row.route_type !== DataFrames.missing)
            route_types[row.route_id] = row.route_type
        end
    end

	if !isfile(trips_path)
		error("File " * trips_path * " not found")
	end
	trips_df = CSV.read(trips_path)
	#a mapping of trip_ids to route_ids
    trips_to_routes = Dict{Any, Any}()
    for row in eachrow(trips_df)
        if(row.trip_id !== DataFrames.missing && row.route_id !== DataFrames.missing)
            trips_to_routes[row.trip_id] = row.route_id
        end
    end

	


	n_nodes = size(nodes, 1)
	graph = SimpleDiGraph(n_nodes)
	metagraph = MetaDiGraph(graph)

    #a identificação dos vértices é feita por inteiros, mas estes vem do arquivo e não necessariamente tem o índice < n_nodes
	#por isso, além de criar o grafo, crio um dicionário auxiliar que mapeia cada índice original ao seu novo índice
	new_indices = Dict{Any, Int64}()
	i = 1
    #at the same time, we compute median latitude and longitude, it may later be used for plotting purposes
    lat_sum, lon_sum = 0.0, 0.0
	for row in eachrow(nodes)
		new_indices[row.stop_id] = i
		#set properties in metagraph for storing a stop's latitude and longitude
		set_props!(metagraph, i, Dict(:latitude => row.stop_lat, :longitude => row.stop_lon, :name => row.stop_name) )
		lat_sum += row.stop_lat
        lon_sum += row.stop_lon
        i = i + 1
	end
    set_prop!(metagraph, :buffer_center_lat, lat_sum / (i - 1))
    set_prop!(metagraph, :buffer_center_lon, lon_sum / (i - 1))
    
    
    
		
	#reads network connections into dataframe, if file exists. Else, raises error
	if !isfile(stop_times_path)
		error(string("File ", stop_times_path, " not found"))
	end
	stop_times_df = CSV.read(stop_times_path)
    
	#constructing the routes array AND the graph's edges

	#temporary, i just want to check if tripIds are unique
	all_trips = Set{Any}()

	#this temporary dictionary records walks and their respective (id, frequency, cost, trip_id)
	#trip_id is later discarded, but it is useful for debugging
	walks_read = Dict{Array{Tuple{Int64, Int64}, 1}, Tuple{String, Int64, Float64}}()

	routes_read = Set{Int64}()
	count = 0
	invalid_route = false
	i, row_count = 1, size(stop_times_df, 1)
	while i <= row_count
        col = stop_times_df[i, :]

        #read the route in this column:
        tripId = col.trip_id
        routeId = trips_to_routes[tripId]

        if in(tripId, all_trips)
            error("trip ids are not unique!" * string(tripId))
        else
            push!(all_trips, tripId)
        end

        #read the entire route,
        invalid_route = route_types[trips_to_routes[stop_times_df[i, :trip_id]]] != transportModeCode #compares with the given gtfs standard transport mode code
        
        stops = Array{Int64,1}() #the sequence of all stops in this trip
        while i <= row_count && tripId == stop_times_df[i, :trip_id] #we've not reached the end of the data-frame and we're still reading the same trip
            col = stop_times_df[i, :]
            #if the route type isnt of type bus, just skip it for now. But the while continues, as we just need to find its end
            if invalid_route
                i += 1
                continue
            end
            stop_id = new_indices[col.stop_id]
            push!(stops, stop_id)
            i += 1
        end
        
        #iterate through all of the trip's stops, constructing the edges,
        #only if there's more than one stop
        walk = Array{Tuple{Int64, Int64}, 1}()
        walk_cost = 0.0
        for i in 1:(length(stops) - 1)
            from = stops[i]
            to = stops[i+1]
            #creates edge
            edge = (from,to)
            push!(walk, edge)
            
            #increments walk's cost with calculated point to point distance
            lat1, lon1 = get_prop(metagraph, from, :latitude), get_prop(metagraph, from, :longitude)
            lat2, lon2 = get_prop(metagraph, to, :latitude), get_prop(metagraph, to, :longitude)
            d = GreatCircleDistance(lat1, lon1, lat2, lon2)
            walk_cost += d
            
            if !has_edge(metagraph, from,to)
                #adds edge to graph, also setting its weigth:
                edge = Edge(from, to)
                add_edge!(metagraph, edge)
                set_prop!(metagraph, edge, :weight, d)               
            end
            
            
            
        end

        #if the route I just read had not been read yet,
        if ~haskey(walks_read, walk) 
			if length(walk) > 0
				walks_read[walk] = (string(trips_to_routes[tripId]), 1, walk_cost)
			else
				@warn "Read walk with zero length?"
			end
        else
            #increment the walk's frequency
            walks_read[walk] = (walks_read[walk][1], walks_read[walk][2] + 1, walks_read[walk][3])
        end

    end
    #to-do - filtering walks: merging forw and back walks into one, frequency threshold, etc. 

	#FILTERING WALKS:
	#it is common that some routes feature little variations during the day, making them register as an unique walk. We discard these instances
	#freq_threshold = 1 #possibly parametrize this later
	#walks_read = filter((pair) -> pair.second[2] > freq_threshold, walks_read) #filter to remove frequency values < freq_threshold
	
	#=
	#it is also common for different walks to be part of the same line(as in: one way and back). We merge these into one bigger walk
	walks_dict_perID = Dict{Int64, Tuple{Array{Tuple{Int64, Int64}, 1}, Int64, Float64}}() #dictionary of (walks, freq, cost), indexed per id
	for (k,v) in walks_read
		id = v[1]
		if haskey(walks_dict_perID, id) #if we've already seen this ID, but its a different walk,
			#try to merge the two walks into one
			println("Merging two walks. Id: $(id)")
			freq = v[2]
			if walks_dict_perID[id][2] != v[2]
				@warn "Merging two walks with different frequencies. Lowest frequency is kept"
				freq = min(walks_dict_perID[id][2], v[2])
			end
			walk = vcat(walks_dict_perID[id][1], k)
			cost = v[3] + walks_dict_perID[id][3]
			walks_dict_perID[id] = (walk, freq, cost)
		else
			walks_dict_perID[id] = (k, v[2], v[3])
		end
	end
	=#
	    
    #take every read walk, its frequency and create the lines array
    lines = Array{Line, 1}()
	edges_freq = Dict{Tuple{Int64, Int64}, Int64}() #set the edge's min_freq and max_freq based on the lines array
	
	#line_coverage is a dict containing each line covering this line, mapping to is frequency,
	#and we should have one of them per edge
	edges_lineCoverage = Dict{Tuple{Int64, Int64}, Dict{Int64, Int64}}()

	i = 1
	for (k,v) in walks_read
        line = Line(v[1], k, v[2], v[3])
        push!(lines, line)
        
        for (s,d) in k
			if haskey(edges_freq, (s,d))
				edges_freq[(s,d)] = edges_freq[(s,d)] + v[2]
				
				edges_lineCoverage[(s,d)][i] = v[2]
            else
				edges_freq[(s,d)] = v[2]
				#println(typeof(edges_lineCoverage))
				edges_lineCoverage[(s,d)] = Dict{Int64,Int64}(i => v[2])
            end
		end
		i += 1
        
	end
	  
    
    #set min_freq and max_freq for each edge
    for e in edges(metagraph)
        s = src(e)
        d = dst(e)
        if ~haskey(edges_freq, (s,d))
            error("An edge was included in the graph but its accumulated frequency is non existent.")
        else
            base_freq = edges_freq[(s,d)]
            set_prop!(metagraph, e, :base_freq, base_freq)
            set_prop!(metagraph, e, :f_min, Int64(max(1, floor(base_freq*0.5))))
			set_prop!(metagraph, e, :f_max, Int64(base_freq*10))
			
			set_prop!(metagraph, e, :line_coverage, edges_lineCoverage[(s,d)])
            
        end
    end

    #finally, construct new problem instance
    problemInstance = ProblemInstance(metagraph, lines)
    return problemInstance    

#end read gtfs function
end
