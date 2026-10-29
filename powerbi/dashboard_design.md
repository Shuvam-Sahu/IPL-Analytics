# Power BI dashboard design

## Data
Six CSVs from exports/ (created by export/export_marts.py): dim_matches, dim_teams, dim_venues, fct_deliveries, fct_batting_innings, fct_bowling_innings.

## Relationships (all Many to one, Single direction, active)
| From | To |
|---|---|
| fct_batting_innings[match_id] | dim_matches[match_id] |
| fct_bowling_innings[match_id] | dim_matches[match_id] |
| fct_deliveries[match_id] | dim_matches[match_id] |
| dim_matches[venue_name] | dim_venues[venue_name] |
| fct_batting_innings[batting_team_name] | dim_teams[team_name] |
| fct_bowling_innings[bowling_team_name] | dim_teams[team_name] |

## Measures
### fct_batting_innings
Total Runs = SUM ( fct_batting_innings[runs] )

Strike Rate = DIVIDE ( SUM ( fct_batting_innings[runs] ) * 100, SUM ( fct_batting_innings[balls_faced] ) )
