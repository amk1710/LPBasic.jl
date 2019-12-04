using OpenStreetMapX
using OpenStreetMapXPlot
using LightGraphs
using MetaGraphs
using Luxor
using Colors
import Plots

#=
visualization.jl

this script implements visualization alternatives for LPBasic problems and solutions
    
=#

#both of these work ok, but are quite slow and the osm information isn't really useful
export PlotInstance, PlotSolution

"""
    function PlotInstance(instance::ProblemInstance, osmpath::String)
Return a plot of the given instance using the given Open Street Map information.

Substantially slower than the PlotInstance method not using OSM information, but the result is better looking.
"""
function PlotInstance(instance::ProblemInstance, osmpath::String)
    map_data = OpenStreetMapX.get_map_data(osmpath)
    
    Plots.gr() #using the GR back-end
    p = OpenStreetMapXPlot.plotmap(map_data,width=600,height=400);
    
    # "convert" from our instance's network to a format frienldy to the OpenStreetMapX library

    for line in instance.lines
        
        #a route is simply an array of MapData nodes
        route = Array{Int64, 1}() #where T = Int64 
        for stop_tuple in line.walk
            from, to = stop_tuple
            #latitude and longitude for to and from stops
            from_coord = (get_prop(instance.network, vertices(instance.network)[from], :latitude), get_prop(instance.network, vertices(instance.network)[from], :longitude))
            to_coord = (get_prop(instance.network, vertices(instance.network)[to], :latitude), get_prop(instance.network, vertices(instance.network)[to], :longitude))
            
            #the DataMap nodes
            from_node = OpenStreetMapXPlot.point_to_nodes(from_coord, map_data)
            to_node = OpenStreetMapXPlot.point_to_nodes(to_coord, map_data)

            #append to route
            push!(route, from_node)

        end

        #add route to plot
        addroute!(p,map_data,route,route_color="red",start_name="",end_name="");

    end

    return p
end

"""
    PlotSolution(instance::ProblemInstance, solution::Array{Bool, 1}, osmpath::String)
Identical to PlotInstance(instance::ProblemInstance, osmpath::String), but paint unused lines differently

Substantially slower than the PlotSolution method not using OSM information, but the result is better looking.
"""
function PlotSolution(instance::ProblemInstance, solution::Array{Bool, 1}, osmpath::String)
    map_data = OpenStreetMapX.get_map_data(osmpath)
    
    Plots.gr() #using the GR back-end
    p = OpenStreetMapXPlot.plotmap(map_data,width=600,height=400);
    
    # "convert" from our instance's network to a format frienldy to the OpenStreetMapX library

    line_i = 1
    for line in instance.lines
        
        #a route is simply an array of MapData nodes
        route = Array{Int64, 1}() #where T = Int64 
        for stop_tuple in line.walk
            from, to = stop_tuple
            #latitude and longitude for to and from stops
            from_coord = (get_prop(instance.network, vertices(instance.network)[from], :latitude), get_prop(instance.network, vertices(instance.network)[from], :longitude))
            to_coord = (get_prop(instance.network, vertices(instance.network)[to], :latitude), get_prop(instance.network, vertices(instance.network)[to], :longitude))
            
            #the DataMap nodes
            from_node = OpenStreetMapXPlot.point_to_nodes(from_coord, map_data)
            to_node = OpenStreetMapXPlot.point_to_nodes(to_coord, map_data)

            #append to route
            push!(route, from_node)

        end

        #add route to plot
        if solution[line_i]
            addroute!(p,map_data,route,route_color="red",start_name="",end_name="")
        else
            addroute!(p,map_data,route,route_color="blue",start_name="",end_name="")
        end   

        line_i +=1

    end

    return p
    
end

#visualization alternative using Luxor
"""
    PlotInstance(instance::ProblemInstance; out_path::String = "./", should_preview = true)
Return a simple Luxor drawing of the given instance

Substantially faster than the PlotInstance method using Open Street Map information, but draws only simple lines on a blank background.
"""
function PlotInstance(instance::ProblemInstance; out_path::String = "./", should_preview = true)
    PlotSolution(instance, [true for i in 1:length(instance.lines)], out_path = out_path, should_preview = should_preview)
end

"""
    PlotSolution(instance::ProblemInstance, solution::Array{Bool, 1};  <keyword arguments>)
Return a simple Luxor drawing of the given instance, painting lines used in solution differently

# Keywork arguments:
- [out_path]: optional path determining where to save the image. If this isn't set, a time-stamped name will be used
- should_preview=true: should the image be previewed in the default image viewer?
"""
function PlotSolution(instance::ProblemInstance, solution::Array{Bool, 1}; out_path::Union{String, Nothing} = nothing, should_preview = true)
    #min and max of latitudes and longitudes, used for scaling
    min_lat, max_lat = Inf, -Inf
    min_lon, max_lon = Inf, -Inf
    for i in 1:nv(instance.network)
        lat, lon = get_prop(instance.network, vertices(instance.network)[i], :latitude), get_prop(instance.network, vertices(instance.network)[i], :longitude)
        min_lat = min(min_lat, lat)
        max_lat = max(max_lat, lat)
        min_lon = min(min_lon, lon)
        max_lon = max(max_lon, lon)
    end

    #not sure if this is correct
    if max_lat - min_lat > max_lon - min_lon
        #latitude has bigger span than longitude
        slat = 600 / (max_lat - min_lat)
        slon = slat
    else
        #longitude has bigger span than latitude
        slon = 600 / (max_lon - min_lon)
        slat = slon
    end

    Drawing(600, 600, :png, if out_path != nothing out_path else "./$(Dates.minute(now())).png" end)
    origin()
     #default size is 600x600
        
        cx, cy = get_prop(instance.network, :buffer_center_lat), get_prop(instance.network, :buffer_center_lon)
        
        #random, different Colors
        # if seed != nothing
        #     dcolors = Colors.distinguishable_colors(length(instance.lines), seed)
        # else
        #     dcolors = Colors.distinguishable_colors(length(instance.lines))
        # end
        
        sf = 1
        println("slat: $(slat)  e slon:$(slon)")
        for i in 1:(length(instance.lines))
            line = instance.lines[i]
            Luxor.setcolor(if solution[i] "red" else "black" end) #red if included in solution, blue otherwise
            Luxor.setdash("solid")
            #Luxor.setcolor(if solution[i] dcolors[i] else "black" end)
            #Luxor.setdash(if solution[i] "solid" else "dashed" end)
            
            #Luxor.setcolor(dcolors[i])
            #Luxor.setopacity(if solution[i] 1.0 else 0.5 end)

            #if solution[i] action = :fillstroke else action = :dotted end
            #action = if (solution[i]) :fillstroke else :dotted end
            #Luxor.setcolor("black")
            for j in 1:(length(line.walk) - 1) #stop at -1 because we'll draw a line between every two stops
                from, to = line.walk[j]
                p1_x = slat * sf * (get_prop(instance.network, vertices(instance.network)[from], :latitude) - cx)
                p1_y = slon * -sf * (get_prop(instance.network, vertices(instance.network)[from], :longitude) -cy) #negated bc y axis points downwards
                
                p2_x = slat * sf * (get_prop(instance.network, vertices(instance.network)[to], :latitude) -cx)
                p2_y = slon * -sf * (get_prop(instance.network, vertices(instance.network)[to], :longitude) -cy)
                
                #might raise ERROR: cant draw arrow between two identical points. Maybe bc of imprecision?
                try
                    #Luxor.arrow(Luxor.Point(p1_x, p1_y), Luxor.Point(p2_x, p2_y))
                    Luxor.line(Luxor.Point(p1_x, p1_y), Luxor.Point(p2_x, p2_y), :stroke)
                catch e
                    @warn "ERROR: cant draw arrow between two identical points????"
                end
            end
        end
    
    finish()
    !should_preview || preview()
end

#to-do: plotting based on edge frequency, and not lines