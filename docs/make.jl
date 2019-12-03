push!(LOAD_PATH,"../src/")

using Documenter
using DocumenterLaTeX
include("../src/LPBasic.jl")
#using LPBasic

makedocs(sitename="LPBasic.jl Documentation", authors = "André Mazal Krauss", modules = [LPBasic])