using DataFrames
using CSV
using Dates
using Query
include("elo.jl")

f = CSV.File("polls/presidential_poll_averages_2020.csv") |> DataFrame
prior = CSV.File("data/returns-2016.csv") |> DataFrame

# Convert to date time 

date_week = map(x -> week(Date(x, "mm/dd/yyyy")), f.modeldate)
replace!(f.candidate_name, "Convention Bounce for Joseph R. Biden Jr." => "Joseph R. Biden Jr.", 
    "Convention Bounce for Donald Trump" => "Donald Trump")
insertcols!(f, 2, dateweek = date_week)

# Group by candidate, state and date week perform mean of pct_estimate and pct_trend_adjusted  

f = groupby(f, [:state, :dateweek, :candidate_name])
f = combine(f, :pct_estimate=>mean, :pct_trend_adjusted=>mean)
sort!(f, :dateweek)

# Convert prior data into pre-probabilities  
prior = prior |> @map({state = _.state_abbreviation, c_norm = _.Clinton/(_.Clinton + _.Trump), t_norm = _.Trump/(_.Clinton + _.Trump)}) |> DataFrame

# Convert pre-probabilities into advantage or disadvantage in scores  
prior = prior |> @map({state = _.state, c_score = back_transformation(_.c_norm), t_score = back_transformation(_.t_norm)}) |> DataFrame

CSV.write("prior.csv", prior)
CSV.write("polls_processed.csv", f)

