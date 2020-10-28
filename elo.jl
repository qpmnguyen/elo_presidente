using StatsFuns

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

