{{ config(materialized='table') }}   -- store the result as a real table

SELECT
    CONCAT_WS('-', CAST(match_id AS STRING), CAST(innings AS STRING),
              CAST(ball AS STRING), CAST(actual_delivery AS STRING)) AS delivery_id,  -- one unique id per delivery
    match_id,           -- links to dim_matches
    innings,            -- 1 and 2 are the match, 3 and 4 are the super over
    ball,               -- ball number, for example 12.4
    actual_delivery,    -- counts legal balls only
    batting_team,
    bowling_team,
    striker,            -- batter facing
    non_striker,
    bowler,
    runs_off_bat,
    extras,             -- includes wides, no-balls, byes, leg byes and penalty
    wides,
    noballs,
    byes,
    legbyes,
    penalty,
    non_boundary,       -- true when 4 or 6 runs were run, not hit to the boundary
    wicket_type,
    player_dismissed,   -- the batter who was out
    fielder_1,
    fielder_2,
    fielder_3,

    -- calculated columns start here
    runs_off_bat + COALESCE(extras, 0) AS runs_on_ball,   -- team runs on this ball
    runs_off_bat + COALESCE(wides, 0) + COALESCE(noballs, 0) AS bowler_runs,   -- runs charged to the bowler

    CASE WHEN COALESCE(wides, 0) = 0 THEN 1 ELSE 0 END AS is_ball_faced,   -- 1 unless it was a wide
    CASE WHEN COALESCE(wides, 0) = 0 AND COALESCE(noballs, 0) = 0 THEN 1 ELSE 0 END AS is_legal_delivery,   -- 1 unless wide or no-ball

    CASE WHEN runs_off_bat = 4 AND COALESCE(non_boundary, false) = false THEN 1 ELSE 0 END AS is_four,   -- a four hit to the rope
    CASE WHEN runs_off_bat = 6 AND COALESCE(non_boundary, false) = false THEN 1 ELSE 0 END AS is_six,   -- a six hit to the rope

    CASE WHEN innings > 2 THEN 1 ELSE 0 END AS is_super_over,   -- 1 for the super over innings

    CASE WHEN player_dismissed IS NOT NULL AND COALESCE(wicket_type, '') <> 'retired hurt'
         THEN 1 ELSE 0 END AS is_wicket,   -- a batter was out, retired hurt does not count
    CASE WHEN wicket_type IN ('bowled', 'caught', 'caught and bowled', 'lbw', 'stumped', 'hit wicket')
         THEN 1 ELSE 0 END AS is_bowler_wicket   -- wickets credited to the bowler

FROM {{ ref('stg_deliveries') }}   -- read from the staging model