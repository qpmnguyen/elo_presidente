### A Pluto.jl notebook ###
# v0.12.7

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ a8f87970-209e-11eb-1039-75a77cfe4380
begin 
	import Pkg
	Pkg.activate(mktempdir())
	Pkg.add("DataFrames")
	Pkg.add("Distributions")
	Pkg.add("Query")
	Pkg.add("CSV")
	Pkg.add("Statistics")
	Pkg.add("JSON")
	Pkg.add("StatsFuns")
	Pkg.add("Plots")
	Pkg.add("PlutoUI")
	Pkg.add("HTTP")
	using HTTP
	using DataFrames
	using Distributions 
	using Query
	using Plots
	using PlutoUI
	using CSV
	using Statistics
	using JSON
	using StatsFuns
	Pkg.add(url="https://github.com/Pocket-titan/DarkMode")
	import DarkMode
	DarkMode.enable()
end

# ╔═╡ a3348840-207a-11eb-3d58-4ba80583bae5
md"
# Predicting presidential election using weekly polls and the elo model
"

# ╔═╡ ab3fa37e-2110-11eb-2c23-715ad4d6fa2c
md"Below are all the functions used"

# ╔═╡ 56145ae0-2110-11eb-15b0-03b7d581b902
begin
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
end

# ╔═╡ 845465d0-209d-11eb-300e-355ff98531aa
md"
This interactive Pluto.jl notebook also allows users to adjust the basic K factor, as well as viewing charts under different states/conditions. Since this is an interactive notebook, all values will be adjusted as sliders are changed. 
"

# ╔═╡ 0524d4b0-20a3-11eb-19f0-3bc4ca93563f
md" First we can adjust the basic K-factor"

# ╔═╡ f1743320-2057-11eb-2d30-a92fc68ad63c
@bind k Slider(10:10:200; default= 50, show_value=true)

# ╔═╡ be2225b0-2055-11eb-1c54-f1948ccc1fde
begin
	prior = CSV.File(HTTP.get("https://raw.githubusercontent.com/qpmnguyen/elo_presidente/master/prior.csv").body) |> DataFrame
	polls = CSV.File(HTTP.get("https://raw.githubusercontent.com/qpmnguyen/elo_presidente/master/polls_processed.csv").body) |> DataFrame
	electoral_votes = JSON.parse(String(HTTP.get("https://raw.githubusercontent.com/qpmnguyen/elo_presidente/master/electoral_votes.json").body))
	abbv = JSON.parse(String(HTTP.get("https://raw.githubusercontent.com/qpmnguyen/elo_presidente/master/states.json").body))
	result = get_elo(prior, polls, k, abbv)
	result =  result |> @mutate(biden_prob = win_prob(_.biden_elo, _.trump_elo)[1]) |> 
	    @mutate(trump_prob = win_prob(_.biden_elo, _.trump_elo)[2]) |> DataFrame
	result = DataFrames.stack(result, [:biden_prob, :trump_prob])
	head(result)
end

# ╔═╡ 29114d90-20a3-11eb-12e7-492a5eb6d24c
md"Next we can view the trajectory of elo for all states according to our model"

# ╔═╡ ae0e88f0-2076-11eb-364d-e74cbe6b264b
@bind sel_state Select(collect(abbv))

# ╔═╡ ff3d67b0-2057-11eb-1d89-ed847d1d3ebe
begin
	state = result |> @filter(_.state == sel_state) |> DataFrame
	Plots.plot(state.value[state.variable .== "biden_prob"], color = "blue", label = "Biden")
	Plots.plot!(state.value[state.variable .== "trump_prob"],color = "red", label = "Trump")
end 

# ╔═╡ 69d95bc0-207f-11eb-0b21-3fac4f11072d
md"
Next we perform simulations and add in the supposed electoral votes for each state Biden wins according to our model. 
"

# ╔═╡ 96a56810-207f-11eb-2876-11cb81487503
@bind n_sim Slider(1000:1000:100000, default = 1000, show_value=true)

# ╔═╡ 3856f0f0-204b-11eb-1d85-49fb508e85b0
begin
	sim_prop = result |> @filter(_.variable == "biden_prob") |> @filter(_.poll_week == 44) |> DataFrame
	sim = simulation(sim_prop, n_sim, electoral_votes)
	transform!(sim, All() => ByRow(+) => :total)
	sim = sim |> @mutate(win = ifelse(_.total >= 270, 1, 0)) |> DataFrame
	head(sim)
end

# ╔═╡ 44133682-20a3-11eb-0608-e53b36a8aebd
md"Tally up percentage of won states based on simulations"

# ╔═╡ 5db48ebe-2087-11eb-07eb-ed4c6df387aa
begin 
	state_prop = ifelse.(sim .> 0, 1, 0)
	sim_probabilities = []
	for i=1:size(state_prop)[2]
		push!(sim_probabilities, round((sum(state_prop[:,i])/n_sim)*100, digits=2))
	end
	sim_probabilities = DataFrame(states = names(sim), prob = sim_probabilities)
	sim_probabilities = sim_probabilities |> 
		@filter(_.states != "win" && _.states != "total") |> DataFrame
	sort!(sim_probabilities, :prob)
	head(sim_probabilities)
end

# ╔═╡ 78d51be0-208a-11eb-216f-93639be649f0
begin
	plot(sim_probabilities.states, sim_probabilities.prob, seriestype = :scatter, label = "Percentage of simulations resulted in a win")
	
end

# ╔═╡ 9856b700-207e-11eb-37a4-3d04d4dc3698
begin
	i = round(mean(sim.total),digits=2)
	histogram(sim.total, label = "Electoral Votes", title = "Mean Electoral Votes $i")
end

# ╔═╡ 5a518ba0-209d-11eb-0532-41f1c64ab61c
md"
Finally we can ascertain the percentage of simulations where Biden wins and use that as a proxy for probability of winning the election
"

# ╔═╡ 2754c8f0-2081-11eb-2569-3bb0e114409f
perc_win = (sum(sim.win)/size(sim)[1])*100

# ╔═╡ Cell order:
# ╟─a3348840-207a-11eb-3d58-4ba80583bae5
# ╠═a8f87970-209e-11eb-1039-75a77cfe4380
# ╟─ab3fa37e-2110-11eb-2c23-715ad4d6fa2c
# ╟─56145ae0-2110-11eb-15b0-03b7d581b902
# ╟─845465d0-209d-11eb-300e-355ff98531aa
# ╟─0524d4b0-20a3-11eb-19f0-3bc4ca93563f
# ╟─f1743320-2057-11eb-2d30-a92fc68ad63c
# ╠═be2225b0-2055-11eb-1c54-f1948ccc1fde
# ╟─29114d90-20a3-11eb-12e7-492a5eb6d24c
# ╟─ae0e88f0-2076-11eb-364d-e74cbe6b264b
# ╟─ff3d67b0-2057-11eb-1d89-ed847d1d3ebe
# ╟─69d95bc0-207f-11eb-0b21-3fac4f11072d
# ╟─96a56810-207f-11eb-2876-11cb81487503
# ╟─3856f0f0-204b-11eb-1d85-49fb508e85b0
# ╟─44133682-20a3-11eb-0608-e53b36a8aebd
# ╟─5db48ebe-2087-11eb-07eb-ed4c6df387aa
# ╟─78d51be0-208a-11eb-216f-93639be649f0
# ╟─9856b700-207e-11eb-37a4-3d04d4dc3698
# ╟─5a518ba0-209d-11eb-0532-41f1c64ab61c
# ╟─2754c8f0-2081-11eb-2569-3bb0e114409f
