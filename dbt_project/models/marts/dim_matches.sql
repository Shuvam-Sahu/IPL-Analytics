{{ config(materialized='table') }}   -- store the result as a real table, not a view

SELECT
    match_id,                         -- one row per match, this is the key
    season,                           -- for example 2017
    match_number,                     -- NULL for playoff matches
    toss_winner,                      -- team that won the toss
    toss_decision,                    -- bat or field
    player_of_match,                  -- player of the match award
    winner,                           -- NULL when there was a tie or no result
    winner_runs,                      -- margin when the winner won by runs
    winner_wickets,                   -- margin when the winner won by wickets
    outcome,                          -- tie or no result, NULL for a normal result
    eliminator AS super_over_winner,  -- Cricsheet's eliminator field is the super over winner
    method,                           -- D/L for rain-affected matches
    target_overs,                     -- overs in the revised target, if any
    target_runs                       -- runs in the revised target, if any
FROM {{ ref('stg_match_info') }}      -- read from the staging model