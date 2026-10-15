{{ config(materialized='table') }}                       -- save as a real table

WITH batter_balls AS (                                   -- step 1: runs and balls for balls faced
  SELECT
    match_id,
    innings,
    striker              AS batter,
    SUM(runs_off_bat)    AS runs,
    SUM(is_ball_faced)   AS balls_faced,
    SUM(is_four)         AS fours,
    SUM(is_six)          AS sixes
  FROM {{ ref('fct_deliveries') }}                       -- builds after fct_deliveries
  WHERE is_super_over = 0
  GROUP BY match_id, innings, striker
),

all_batters AS (                                         -- step 2a: everyone at the crease
  SELECT match_id, innings, batting_team_name, bowling_team_name, striker AS batter
  FROM {{ ref('fct_deliveries') }}
  WHERE is_super_over = 0
  UNION                                                  -- each batter once per innings
  SELECT match_id, innings, batting_team_name, bowling_team_name, non_striker AS batter
  FROM {{ ref('fct_deliveries') }}
  WHERE is_super_over = 0
),

batter_innings AS (                                      -- step 2b: 0 for batters who never faced
  SELECT
    ab.match_id,
    ab.innings,
    ab.batting_team_name,
    ab.bowling_team_name,                                -- NEW: the opposition
    ab.batter,
    COALESCE(bb.runs, 0)         AS runs,
    COALESCE(bb.balls_faced, 0)  AS balls_faced,
    COALESCE(bb.fours, 0)        AS fours,
    COALESCE(bb.sixes, 0)        AS sixes
  FROM all_batters AS ab
  LEFT JOIN batter_balls AS bb
    ON  ab.match_id = bb.match_id
    AND ab.innings  = bb.innings
    AND ab.batter   = bb.batter
),

dismissals AS (                                          -- step 3a: who was out and how
  SELECT
    match_id,
    innings,
    player_dismissed   AS batter,
    MIN(wicket_type)   AS dismissal_type
  FROM {{ ref('fct_deliveries') }}
  WHERE is_super_over = 0
    AND is_wicket = 1
  GROUP BY match_id, innings, player_dismissed
),

batting_scorecard AS (                                   -- step 3b: out / not out and strike rate
  SELECT
    bi.*,
    CASE WHEN d.batter IS NOT NULL THEN 1 ELSE 0 END AS is_out,
    d.dismissal_type,
    CASE WHEN bi.balls_faced > 0
         THEN ROUND(bi.runs * 100.0 / bi.balls_faced, 2)
    END AS strike_rate
  FROM batter_innings AS bi
  LEFT JOIN dismissals AS d
    ON  bi.match_id = d.match_id
    AND bi.innings  = d.innings
    AND bi.batter   = d.batter
)

SELECT
  CONCAT_WS('-', match_id, innings, batter) AS batting_innings_id,  -- NEW: unique key per row
  match_id,
  innings,
  batting_team_name,
  bowling_team_name,
  batter,
  runs,
  balls_faced,
  fours,
  sixes,
  strike_rate,
  is_out,
  dismissal_type,
  CASE WHEN runs >= 50 AND runs < 100 THEN 1 ELSE 0 END AS is_fifty,    -- NEW: 50 to 99
  CASE WHEN runs >= 100               THEN 1 ELSE 0 END AS is_hundred   -- NEW: 100 or more
FROM batting_scorecard