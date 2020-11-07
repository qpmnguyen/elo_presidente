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
	using DataFrames
	using Distributions 
	using Query
	using Plots
	using PlutoUI
	using CSV
	using Statistics
	using JSON
	include("elo.jl")
	import Pkg
	Pkg.add(url="https://github.com/Pocket-titan/DarkMode")
	import DarkMode
	DarkMode.enable()
end

# ╔═╡ a3348840-207a-11eb-3d58-4ba80583bae5
md"
# Predicting presidential election using weekly polls and the elo model
"

# ╔═╡ 845465d0-209d-11eb-300e-355ff98531aa
md"
The elo rating system is a method developed by [Arpad Elo](https://en.wikipedia.org/wiki/Arpad_Elo) as a way to rank players in a zero sum game. Elo has been used in various contexts, particuarly notable in chess and more recently, competitive online games. A really nice attribute about Elo is that a difference in scores can be translated to a probability, through the formula:    

$$E_A = \frac{1}{1 + 10^{R_A - R_B}}$$

where $E_A$ is the expected score of player $A$ with rank $R_A$ playing against player $B$ of rank $R_B$. This is equivalent to applying the logistic function to a recaled version of the difference in rankings 

$$logistic\left(\frac{\log(10)}{400} (R_A - R_B)\right)$$

This ensures that the expected values $E_A$ and $E_B$ are bounded between 0 and 1 and hence acts as probabilities.  

In an elo model, after each match, the rankings are updated as:  

$$R_{A_{new}} = R_A + K * (\text{outcome} - E_A)$$   

where $K$ is the $K$-factor controlling the relative gains and losses of elo points. 

The US presidential election is the perfect place to test the elo theory since there is usually 2 candidates who campaigns for a long period of time with lots of polling data. The winner is determined through the electoral college, which follows a winner-take-all system. This further makes the US presidential election closer to a sports match.  

In this instance, we decided to use the elo system to model the probability of winning an election. We take the weekly average of polls to act as \"games\" that then culiminate in a showdown on November 3rd. After each weekly poll, the candidate gains or lose elo based on the elo model presented above. Some **major caveats:**  

* First, this is obviously not considering any fundamental of election forecasting, such as the inclusion of demographic and economical variables as well as state-by-state correlation.  

* Second, this model does not incorporate any outside knowledge other than the way FiveThirtyEight weights the polls (we use average polling data from the site).  

* Third, the model really preferences candidates who are polling well consistently, and rewards them with higher probability of winning. We think this is a pretty good model considering that close polling reduce the gains in elo and narrows the proability of winning, and sudden losses in polling numbers also contribute towards a candidate's poor showing. However, this is very non-traditional and not really an apt approach towards proper modelling of an election.   

Considering those aspects, we further considered some modifications to the model. 
* First, we seeded inital elo based on election results from the 2016 election. using 1000 elo as a baseline, we subtract or add points to candidate's starting elo based on how they (or the candidate belonging to their party) performed previously. We call this our priors.  
* Second, we incorporate margin of victory into our elo update calculation by modifying the $K$-factor. This is a simple linear adjustment $K_{eff} = K * mov$ where $mov$ is the margin of victory. This means that the \"winning\" candidate will gain points as a proportion of K that is equal to their margin of polling victory. As such, we increase values of K significantly to compensate for the low gains in elo when margins can be 1 percent.  
* Finally, we perform elo modelling at the state level, then use those probabilities to randomly draw a number of simulations based on a Bernoulli process. We calculate the final probability of winning as the number of simulations where a focal candidate (in this case Biden) gains 270 or more Electoral Votes.  

This interactive Pluto.jl notebook also allows users to adjust the basic K factor, as well as viewing charts under different states/conditions. Since this is an interactive notebook, all values will be adjusted as sliders are changed. 
"

# ╔═╡ 0524d4b0-20a3-11eb-19f0-3bc4ca93563f
md" First we can adjust the basic K-factor"

# ╔═╡ f1743320-2057-11eb-2d30-a92fc68ad63c
@bind k Slider(10:10:200; default= 50, show_value=true)

# ╔═╡ be2225b0-2055-11eb-1c54-f1948ccc1fde
begin
	prior = CSV.File("prior.csv") |> DataFrame
	polls = CSV.File("polls_processed.csv") |> DataFrame
	abbv = JSON.parsefile("states.json")
	electoral_votes = JSON.parsefile("electoral_votes.json")
	result = get_elo(prior, polls, k, abbv)
	result =  result |> @mutate(biden_prob = win_prob(_.biden_elo, _.trump_elo)[1]) |> 
	    @mutate(trump_prob = win_prob(_.biden_elo, _.trump_elo)[2]) |> DataFrame
	result = stack(result, [:biden_prob, :trump_prob])
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
# ╟─a8f87970-209e-11eb-1039-75a77cfe4380
# ╟─845465d0-209d-11eb-300e-355ff98531aa
# ╟─0524d4b0-20a3-11eb-19f0-3bc4ca93563f
# ╟─f1743320-2057-11eb-2d30-a92fc68ad63c
# ╟─be2225b0-2055-11eb-1c54-f1948ccc1fde
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
