using Distributions
using Serialization
using DataFrames
using Query
using JSON  
include("elo.jl")

result = deserialize("results.jds")
result =  result |> @mutate(biden_prob = win_prob(_.biden_elo, _.trump_elo)[1]) |> 
    @mutate(trump_prob = win_prob(_.biden_elo, _.trump_elo)[2]) |> DataFrame
result = stack(result, [:biden_prob, :trump_prob])
result = result |> @filter(_.variable == "biden_prob") |> @filter(_.poll_week == 44) |> DataFrame

electoral_vote = JSON.parsefile("electoral_votes.json")

function simulation(result::DataFrame)
    
end