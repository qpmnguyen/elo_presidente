using StatsFuns
using Statistics
using Distributions

@doc raw"""
win_prob is a function to create win probabilities given an elo ranking   
r1::Int Elo rankings of player 1  
r2::Int Elo rankings of player 2   
Returns p1,p2 Tuple of win probabilities for player 1 and player 2  
"""
function win_prob(r1::Int, r2::Int)
    x1 = log(10)/400 * (r1 - r2)
    p1 = StatsFuns.logistic(x1)
    p2 = 1 - p1
    return(p1,p2)
end

@doc raw"""
update_elo is a function that takes an elo and an outcome for the first player and returns updated elo (first player first)  
r1::Int Elo rankings of player 1  
r2::Int Elo rankings of player 2   
outcome::Int 0 or 1 indicating the win-loss status of player 1  
K::Int Scaling factor for elo   
"""
function update_elo(r1::Int, r2::Int, outcome::Int16, mov::Float64, K::Int=30)
    p1, p2 = win_prob(r1,r2)
    K = K * mov # just K as a proportion of margin of victory 
    r1new = convert(Int, round(r1 + K*(outcome - p1), digits = 0))
    r2new = convert(Int, round(r2 + K*((1 - outcome) - p2), digits = 0))
    return r1new, r2new
end

@doc raw"""
elo_sequence is a function to get all elo sequences for a state given a results dictionary based on 538 data 
"""
function elo_sequence(outcome::Array, mov::Array, init::Tuple=(1000,1000), K::Int=30)
    if length(outcome) != length(mov)
        error("Length outcome has to be equal to mov...")
    end
    output = zeros(Int, length(outcome)+1, 2)
    (r1, r2) = init
    output[1,:] = [r1,r2]
    for i=1:length(outcome)
        r1,r2 = update_elo(r1,r2, outcome[i], mov[i], K)
        output[i+1,:] = [r1,r2]
    end
    return output
end

function back_transformation(prob::Float64)
    logit(prob) * 400 * (1/log(10))
end

# get elo sequence given poll data, K, state abbreviation and prior 
function get_elo(prior::DataFrame, polls::DataFrame, K::Int, abbv::Dict)
    states = unique(polls.state)
    result = DataFrame()
    for i=1:length(states)
        println(i)
        entry = polls |> @filter(_.state == states[i]) |> DataFrame
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
            seq = elo_sequence(outcome.win, outcome.mov, init, K)
            insertcols!(outcome, 4, :biden_elo => seq[2:size(seq,1),1])
            insertcols!(outcome, 4, :trump_elo => seq[2:size(seq,1),2])
            result = vcat(result, outcome)
        end
    end
    return(result)
end

# Simulating draws based on elo data set 
function simulation(result::DataFrame, nsim::Int, electoral_vote::Dict)
    output = DataFrame()
    probs = result.value
    for i=1:length(probs)
        outcome = rand(Bernoulli(probs[i]),nsim) .* electoral_vote[result.state[i]]
        insertcols!(output,1, Symbol(result.state[i]) => outcome, makeunique=true)
    end
    return(output)
end