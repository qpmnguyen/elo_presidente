# Forecasting 2020 Presidential Election using Elo  
## by Quang Nguyen  

In this repo, we attempt to perform forecast of the 2020 Election using Elo (like those used in Chess).   

**NOTE: THIS IS ONLY A SEMI-SERIOUS MODELLING EXERCISE**  

The Elo method is commonly used for sports statsitics, which is a proxy for the relative strengths for two teams in a sports league. The Elo method has a probabilistic interpretation, and difference in Elo scores can translate to win probabilities.  

Presidential elections can be re-formulated conceptually as a competition, owing specifically to the winner takes all nature of Electoral College, as well as the fact that there are generally 2 candidates vying for the presidency. Each poll can be considered a "match", culminating to the final showdown on November 3rd, where one candidate will become the 46th president of the United States.  

Our model is as follows:  
1. First, we use aggregated polling from [FiveThirtyEight](https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/). This is because there is a lot of intricate knowledge required in understanding which polls are important, which polls are good, and which polls are representative. We rely on FiveThirtyEight for the poll weighting procedure.  
2. Second, we average polling results per week for each state. This is because major events usually has full impact within a one week period, and averaging results also stablizes the estimates further.  
3. Third, we seed the starting elo of each candidate based upon the margin of victory in the 2016 election.  
4. Fourth, we scale elo gain/loss based on the margin of victory of the polls. For now the implementation is very simple, since margin of victory (MOV) in head-to-head polls is bounded between 0 and 1, new K would be K * MOV.  
5. Fifth, at the end of the last polling week, the final probability based on elo would be tabulated for each state, and we performed Monte Carlo simuliations similar to that of FiveThirtyEight to show the margins in which a candidate can in the election.  

Some assumptions:  
First, this model essentially gives candidate points for consistent good polling. We assume that voters are influenced partially by good consistent polling, and the increasing (or decreasing) MOV for each candidate's polling results is then a reflection of the increasing victory margin. Here I tried to scale it (by limiting K and scaling to MOV) to allow for points to be gained slowly with a possible saturation point rather than linear or exponential growth in elo points.  

Second, this model does not incorporate any other existing information about the election or the current economical/social/pandemic status. Good statisticians will use external information to enhance forecasting ability and any serious modeller should do so as well. Here I relied on FiveThirtyEight's external knowledge to infuse some of that information into the predictions. 

A implementation is done in Julia as a learning exercise.  