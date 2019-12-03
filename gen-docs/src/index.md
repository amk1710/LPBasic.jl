# The LPBasic module

# About LPBasic.jl
LPBasic.jl is a julia module to facilitate JuMP framework's usage for an specific line planning optimization model called LPBasic. It was developed as part of a graduation project at PUC-Rio by Computer Science student André Mazal Krauss during 2019. 

For more information visit the project's github page and read the report(in portuguese). You may also contact me directly: amk1710@gmail.com 

# LPBasic.jl Documentation

```@meta
CurrentModule = LPBasic
```

## Dependencies
The following list includes all direct depencies for the full module's functionality. These dependencies might have their own dependencies, but Julia's 
Pkg should resolve them automatically. 

Also note that OpenStreetMapPlot is not included in Julia's Registry. However, the package's website has straighforward install instructions. It's only use is to render transport networks with OpenStreetMap information(methods PlotInstance and PlotSolution), so it is possible to use the module without it if so desired. 

- [CSV](https://github.com/JuliaData/CSV.jl) (https://github.com/JuliaData/CSV.jl)
- [Colors](https://github.com/JuliaGraphics/Colors.jl) (https://github.com/JuliaGraphics/Colors.jl)
- [JuMP](https://github.com/JuliaOpt/JuMP.jl) (https://github.com/JuliaOpt/JuMP.jl)
- [LightGraphs](https://github.com/JuliaGraphs/LightGraphs.jl)(https://github.com/JuliaGraphs/LightGraphs.jl)
- [Luxor](https://github.com/JuliaGraphics/Luxor.jl)(https://github.com/JuliaGraphics/Luxor.jl)
- [MathOptInterface](https://github.com/JuliaOpt/MathOptInterface.jl)(https://github.com/JuliaOpt/MathOptInterface.jl)
- [MetaGraphs](https://github.com/JuliaGraphs/MetaGraphs.jl)(https://github.com/JuliaGraphs/MetaGraphs.jl)
- [OpenStreepMapX](https://github.com/pszufe/OpenStreetMapX.jl)(https://github.com/pszufe/OpenStreetMapX.jl)
- [OpenStreetMapXPlot](https://github.com/pszufe/OpenStreetMapXPlot.jl)(https://github.com/pszufe/OpenStreetMapXPlot.jl)
- [Plots](https://github.com/JuliaPlots/Plots.jl)(https://github.com/JuliaPlots/Plots.jl)

## Function Index
```@index
Modules = [LPBasic]
```

## Module
```@docs
LPBasic
```

## Data Structures
```@docs
Line
ProblemInstance
```

## IO Functionality
```@docs
ReadGTFS
ReadNatureFeed
```

## Model Construction
```@docs
ConstructModel
```

## Visualization
```@docs
PlotInstance
PlotSolution
```

## Miscellaneous
```@docs
IsEdgeOnLine
CalculateCost
RunSuite
BasicStats
VerifyInstance
VerifySolution
GreatCircleDistance
```

# Authoring information
Author: André Mazal Krauss, Computer Sciences student at Pontifícia Universidade Católica do Rio Janeiro(PUC-Rio)

Project Supervision: Marcus Poggi
