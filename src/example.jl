#example script
using JuMP
using Cbc
include("LPBasic.jl")

#só aceita transportes com o código passado: 1-> trem, 3 -> ônibus 
instance = LPBasic.ReadGTFS("../GTFS/bage/", transportModeCode = 3)

#=constrói o modelo:
    useSlack determina se o modelo deve usar variáveis de slack, com o custo dado por slack_penalty. Os valor default é não usar(false)
    useFlexibleLineFrequency determina se as linhas poderão ser tomadas com uma parcela de sua frequencia base. O valor default é false

=#
model = LPBasic.ConstructModel(instance, useSlack = true, slack_penalty = 1000.0, useFlexibleLineFrequency = false)

optimize!(model, with_optimizer(Cbc.Optimizer))



