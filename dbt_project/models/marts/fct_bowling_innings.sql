{{ config(materialized='table') }}                       -- save as a real table

WITH bowler_figures AS (                                 -- one row per match, innings and bowler
  SELECT
    match_id,
    innings,
    bowling_team_name,
    batting_team_name,
    bowler,
    SUM(is_legal_delivery)        AS legal_balls,
    SUM(bowler_runs)              AS runs_conceded,
    SUM(is_bowler_wicket)         AS wickets,
    SUM(CASE WHEN is_legal_delivery = 1 AND bowler_runs = 0
             THEN 1 ELSE 0 END)   AS dot_balls,
    SUM(is_four)                  AS fours_conceded,
    SUM(is_six)                   AS sixes_conceded,
    COALESCE(SUM(wides), 0)       AS wides,              -- blank in Cricsheet when none, so use 0
    COALESCE(SUM(noballs), 0)     AS noballs             -- same for no-balls
  FROM {{ ref('fct_deliveries') }}                       -- builds after fct_deliveries
  WHERE is_super_over = 0
  GROUP BY match_id, innings, bowling_team_name, batting_team_name, bowler
)

SELECT
  CONCAT_WS('-', match_id, innings, bowler) AS bowling_innings_id,   -- unique key per row
  match_id,
  innings,
  bowling_team_name,
  batting_team_name,
  bowler,
  legal_balls,
  FLOOR(legal_balls / 6) + MOD(legal_balls, 6) / 10.0 AS overs,      -- 22 balls -> 3.4 (display only)
  runs_conceded,
  wickets,
  CASE WHEN legal_balls > 0
       THEN ROUND(runs_conceded * 6.0 / legal_balls, 2)
  END                                 AS economy,                    -- runs per over; blank if 0 balls
  dot_balls,
  fours_conceded,
  sixes_conceded,
  wides,
  noballs,
  CASE WHEN wickets = 4 THEN 1 ELSE 0 END AS is_four_wickets,        -- exactly 4 wickets
  CASE WHEN wickets >= 5 THEN 1 ELSE 0 END AS is_five_wickets        -- 5 or more
FROM bowler_figures