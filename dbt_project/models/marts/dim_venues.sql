{{ config(materialized='table') }}   -- store as a real table

WITH venues AS (
    SELECT DISTINCT venue_name, city   -- one row per ground, from the seed
    FROM {{ ref('venue_names') }}
),

venue_stats AS (
    SELECT v.venue_name,
           MIN(d.start_date) AS first_match_date,       -- first match at the ground
           MAX(d.start_date) AS last_match_date,        -- most recent match
           COUNT(DISTINCT d.match_id) AS matches        -- matches played there
    FROM {{ ref('stg_deliveries') }} d
    JOIN {{ ref('venue_names') }} v ON v.raw_venue = d.venue   -- raw name to clean name
    GROUP BY v.venue_name
)

SELECT ve.venue_name,
       ve.city,
       vs.first_match_date,
       vs.last_match_date,
       vs.matches
FROM venues ve
JOIN venue_stats vs ON vs.venue_name = ve.venue_name