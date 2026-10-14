{{ config(materialized='table') }}                       -- save the result as a real table in Databricks

WITH match_dates AS (                                    -- step 1: date and raw venue, one row per match
  SELECT
    match_id,
    CAST(MIN(start_date) AS DATE) AS match_date,
    MIN(venue)                    AS raw_venue
  FROM {{ ref('stg_deliveries') }}                       -- ref() replaces the full table name
  GROUP BY match_id
),

match_venues AS (                                        -- step 2: clean ground name and city
  SELECT
    md.match_id,
    md.match_date,
    vn.venue_name,
    vn.city
  FROM match_dates AS md
  LEFT JOIN {{ ref('venue_names') }} AS vn               -- the venue seed
    ON md.raw_venue = vn.raw_venue
),

match_teams AS (                                         -- step 3a: raw names of the two teams
  SELECT
    match_id,
    MIN(batting_team) AS raw_team_1,                     -- batted first
    MIN(bowling_team) AS raw_team_2                      -- bowled first
  FROM {{ ref('stg_deliveries') }}
  WHERE innings = 1
  GROUP BY match_id
),

match_with_teams AS (                                    -- step 3b: clean team names
  SELECT
    mv.*,
    t1.team_name AS team_1,
    t2.team_name AS team_2
  FROM match_venues AS mv
  LEFT JOIN match_teams AS mt
    ON mv.match_id = mt.match_id
  LEFT JOIN {{ ref('team_names') }} AS t1                -- the team seed, first lookup
    ON mt.raw_team_1 = t1.raw_team
  LEFT JOIN {{ ref('team_names') }} AS t2                -- the team seed, second lookup
    ON mt.raw_team_2 = t2.raw_team
),

match_results AS (                                       -- step 4: match facts, result and winner
  SELECT
    mwt.*,
    mi.season,
    mi.match_number,
    tw.team_name AS toss_winner,                         -- NEW: toss winner, clean name
    mi.toss_decision,                                    -- kept from old file: bat or field
    CASE
      WHEN mi.winner IS NOT NULL    THEN 'win'
      WHEN mi.outcome = 'tie'       THEN 'tie'
      WHEN mi.outcome = 'no result' THEN 'no result'
      ELSE 'unknown'
    END AS match_result,
    w.team_name AS match_winner,
    mi.winner_runs,                                      -- kept: won by X runs
    mi.winner_wickets,                                   -- kept: won by X wickets
    mi.method,                                           -- kept: e.g. D/L for rain-affected
    mi.target_overs,                                     -- kept: revised target overs
    mi.target_runs,                                      -- kept: revised target runs
    mi.player_of_match                                   -- kept
  FROM match_with_teams AS mwt
  LEFT JOIN {{ ref('stg_match_info') }} AS mi
    ON mwt.match_id = mi.match_id
  LEFT JOIN {{ ref('team_names') }} AS w                 -- clean the winner's name
    ON COALESCE(mi.winner, mi.eliminator) = w.raw_team
  LEFT JOIN {{ ref('team_names') }} AS tw                -- NEW: clean the toss winner's name
    ON mi.toss_winner = tw.raw_team
),

playoffs AS (                                            -- step 5a: number playoffs per season
  SELECT
    match_id,
    ROW_NUMBER() OVER (PARTITION BY season ORDER BY match_date) AS playoff_order,
    COUNT(*)     OVER (PARTITION BY season)                     AS playoffs_in_season
  FROM match_results
  WHERE match_number IS NULL
),

match_labels AS (                                        -- step 5b: final flag and label
  SELECT
    mr.*,
    p.playoff_order,
    CASE WHEN p.playoff_order = p.playoffs_in_season
         THEN TRUE ELSE FALSE END AS is_final,
    CASE
      WHEN mr.match_number IS NOT NULL
        THEN CONCAT('Match ', mr.match_number, ': ', mr.team_1, ' vs ', mr.team_2)
      WHEN p.playoff_order = p.playoffs_in_season
        THEN CONCAT('Final: ', mr.team_1, ' vs ', mr.team_2)
      ELSE CONCAT('Playoff ', p.playoff_order, ': ', mr.team_1, ' vs ', mr.team_2)
    END AS match_label
  FROM match_results AS mr
  LEFT JOIN playoffs AS p
    ON mr.match_id = p.match_id
),

season_info AS (                                         -- step 6a: champion, runner-up, year
  SELECT
    season,
    MAX(CASE WHEN is_final THEN match_winner END) AS champion,
    MAX(CASE WHEN is_final THEN
          CASE WHEN match_winner = team_1 THEN team_2 ELSE team_1 END
        END) AS runner_up,
    YEAR(MIN(match_date)) AS season_year
  FROM match_labels
  GROUP BY season
),

final_matches AS (                                       -- step 6b: season facts on every match
  SELECT
    ml.*,
    si.season_year,
    si.champion,
    si.runner_up
  FROM match_labels AS ml
  LEFT JOIN season_info AS si
    ON ml.season = si.season
)

SELECT                                                   -- final column order for Power BI
  match_id,
  season,
  season_year,
  match_date,
  match_number,
  playoff_order,
  is_final,
  match_label,
  venue_name,
  city,
  team_1,
  team_2,
  toss_winner,
  toss_decision,
  match_result,
  match_winner,
  winner_runs,
  winner_wickets,
  method,
  target_overs,
  target_runs,
  player_of_match,
  champion,
  runner_up
FROM final_matches