using DataFrames
using CSV
using Dates
using Statistics
using Distributions
using Query
using JSON
using Serialize
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
states = unique(f.state)
results = Dict()
abbv = JSON.parsefile("states.json")

# Convert prior data into pre-probabilities  
prior = prior |> @map({state = _.state_abbreviation, c_norm = _.Clinton/(_.Clinton + _.Trump), t_norm = _.Trump/(_.Clinton + _.Trump)}) |> DataFrame

# Convert pre-probabilities into advantage or disadvantage in scores  
prior = prior |> @map({state = _.state, c_score = back_transformation(_.c_norm), t_score = back_transformation(_.t_norm)}) |> DataFrame

# start the loop 
result = DataFrame()
for i=1:length(states)
    println(i)
    entry = f |> @filter(_.state == states[i]) |> DataFrame
    pos_dates = unique(entry.dateweek)
    outcome = DataFrame(win = Int16[], mov = Float64[])
    for j=1:length(pos_dates)
        week_df = entry |> @filter(_.dateweek == pos_dates[j]) |> DataFrame
        max = maximum(week_df.pct_estimate_mean)
        mov =  abs(week_df.pct_estimate_mean[1] - week_df.pct_estimate_mean[2])/100
        idx = findall(x -> x == max, week_df.pct_estimate_mean)
        if (mov == 0)
            push!(outcome, [rand(Binomial(1,0.5)) rand(Uniform(0,0.01))])
        else
            push!(outcome, [ifelse(week_df.candidate_name[idx][1] == "Joseph R. Biden Jr.",1,0) mov])
        end
    end
    insertcols!(outcome,1, :poll_week => pos_dates)
    
    if states[i] in values(abbv)
        state_abb = [k for (k,v) in abbv if v == states[i]][1]
        insertcols!(outcome, 1, :state => vec(fill(state_abb, (1,length(outcome.win)))))
        init = Int.(round.(tuple(convert(Array, prior[prior.state .== state_abb,2:3] .+ 1000)...)))
        seq = elo_sequence(outcome.win, outcome.mov, init, 50)
        insertcols!(outcome, 4, :biden_elo => seq[2:size(seq,1),1])
        insertcols!(outcome, 4, :trump_elo => seq[2:size(seq,1),2])
        result = vcat(result, outcome)
    end
end

serialize("results.jds", result)

