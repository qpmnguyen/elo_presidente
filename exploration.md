# Predicting presidental election using Elo method with Julia 
## Quang Nguyen


```julia
using Gadfly
using StatsPlots
using Distributions
using Serialization 
using DataFrames
using Query

include("elo.jl")
result = deserialize("results.jds")
result =  result |> @mutate(biden_prob = win_prob(_.biden_elo, _.trump_elo)[1]) |> 
    @mutate(trump_prob = win_prob(_.biden_elo, _.trump_elo)[2]) |> DataFrame
result = stack(result, [:biden_prob, :trump_prob])
```

```
2868×8 DataFrame. Omitted printing of 2 columns
│ Row  │ state  │ poll_week │ win   │ trump_elo │ biden_elo │ mov         │
│      │ String │ Int64     │ Int16 │ Int64     │ Int64     │ Float64     │
├──────┼────────┼───────────┼───────┼───────────┼───────────┼─────────────┤
│ 1    │ WI     │ 9         │ 0     │ 1003      │ 997       │ 0.00592403  │
│ 2    │ WI     │ 10        │ 0     │ 1003      │ 997       │ 0.00678533  │
│ 3    │ WI     │ 11        │ 0     │ 1003      │ 997       │ 0.0028796   │
│ 4    │ WI     │ 12        │ 0     │ 1003      │ 997       │ 0.00221007  │
│ 5    │ WI     │ 13        │ 0     │ 1003      │ 997       │ 0.000335071 │
│ 6    │ WI     │ 14        │ 1     │ 1003      │ 997       │ 0.00447397  │
│ 7    │ WI     │ 15        │ 1     │ 1003      │ 997       │ 0.00498906  │
⋮
│ 2861 │ NE     │ 42        │ 0     │ 1097      │ 903       │ 0.042591    │
│ 2862 │ NE     │ 43        │ 0     │ 1097      │ 903       │ 0.0365505   │
│ 2863 │ NE     │ 44        │ 0     │ 1097      │ 903       │ 0.0333956   │
│ 2864 │ IL     │ 40        │ 1     │ 937       │ 1063      │ 0.0709938   │
│ 2865 │ IL     │ 41        │ 1     │ 936       │ 1064      │ 0.0830685   │
│ 2866 │ IL     │ 42        │ 1     │ 935       │ 1065      │ 0.0850051   │
│ 2867 │ IL     │ 43        │ 1     │ 934       │ 1066      │ 0.0816402   │
│ 2868 │ IL     │ 44        │ 1     │ 933       │ 1067      │ 0.0791235   │
```





First, let's plot the win probability (based on elo) for both candidates of a state across all weeks of polling for a swing state such as Pensylvania   

```julia
state = result |> @filter(_.state == "PA") |> DataFrame
Gadfly.plot(state, x = :poll_week, y = :value, color = :variable, Geom.line, Geom.point)
```

```
Error: The Cairo and Fontconfig packages are necessary for saving as PNG.
Add them with the package manager if necessary, then run `import Cairo,
Fontconfig` before invoking `PNG`.
```


![](figures/exploration_2_1.png)



Initially, Biden was disadvantaged because of what happened in the 2016 election. However, consistent polls have improved his chances significantly, culminating in the current win probability of 52 to 48, which isn't that bad for Trump.  Let's consider a second state that is more conservative, West Virginia.  

```julia
state = result |> @filter(_.state == "WV") |> DataFrame
Gadfly.plot(state, x = :poll_week, y = :value, color = :variable, Geom.line, Geom.point)
```

```
Error: The Cairo and Fontconfig packages are necessary for saving as PNG.
Add them with the package manager if necessary, then run `import Cairo,
Fontconfig` before invoking `PNG`.
```


![](figures/exploration_3_1.png)



Here, given an early disadvantage, Biden's polling was never good enough to ensure that he will be able to win the state. His changes dipped below 20% as Trump's polling got stronger.   

Conversely, 
