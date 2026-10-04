WITH pivoted AS (
    SELECT
        source_file,
        MAX(CASE WHEN field = 'match_id' THEN value1 END) AS match_id,
        MAX(CASE WHEN field = 'season' THEN value1 END) AS season,
        MAX(CASE WHEN field = 'match_number' THEN value1 END) AS match_number,
        MAX(CASE WHEN field = 'toss_winner' THEN value1 END) AS toss_winner,
        MAX(CASE WHEN field = 'toss_decision' THEN value1 END) AS toss_decision,
        MAX(CASE WHEN field = 'player_of_match' THEN value1 END) AS player_of_match,
        MAX(CASE WHEN field = 'target_overs' THEN value2 END) AS target_overs,
        MAX(CASE WHEN field = 'target_runs' THEN value2 END) AS target_runs,
        MAX(CASE WHEN field = 'winner' THEN value1 END) AS winner,
        MAX(CASE WHEN field = 'winner_runs' THEN value1 END) AS winner_runs,
        MAX(CASE WHEN field = 'winner_wickets' THEN value1 END) AS winner_wickets,
        MAX(CASE WHEN field = 'outcome' THEN value1 END) AS outcome,
        MAX(CASE WHEN field = 'eliminator' THEN value1 END) AS eliminator,
        MAX(CASE WHEN field = 'method' THEN value1 END) AS method   -- new
    FROM {{ source('bronze', 'match_info_raw') }}
    WHERE field IN ('season', 'match_id', 'match_number', 'toss_winner', 'toss_decision', 'player_of_match', 'target_overs', 'target_runs', 'winner', 'winner_runs', 'winner_wickets', 'outcome', 'eliminator', 'method')   -- 'method' added
    GROUP BY source_file
)

SELECT
    source_file,
    TRY_CAST(match_id AS INT) AS match_id,
    season,
    TRY_CAST(match_number AS INT) AS match_number,
    toss_winner,
    toss_decision,
    player_of_match,
    TRY_CAST(target_overs AS DOUBLE) AS target_overs,
    TRY_CAST(target_runs AS INT) AS target_runs,
    winner,
    TRY_CAST(winner_runs AS INT) AS winner_runs,
    TRY_CAST(winner_wickets AS INT) AS winner_wickets,
    outcome,
    eliminator,
    method   -- new
FROM pivoted