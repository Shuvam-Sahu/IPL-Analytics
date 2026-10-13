{{ config(materialized='table') }}   -- store as a real table

WITH teams AS (
    SELECT DISTINCT team_name        -- one row per franchise, taken from the seed
    FROM {{ ref('team_names') }}
),

team_dates AS (
    SELECT t.team_name,
           MIN(d.start_date) AS first_match_date,   -- first match the franchise played
           MAX(d.start_date) AS last_match_date     -- most recent match
    FROM {{ ref('stg_deliveries') }} d
    JOIN {{ ref('team_names') }} t ON t.raw_team = d.batting_team   -- raw name to clean name
    GROUP BY t.team_name
)

SELECT te.team_name,
       td.first_match_date,
       td.last_match_date
FROM teams te
JOIN team_dates td ON td.team_name = te.team_name