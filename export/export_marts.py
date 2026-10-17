import csv                                      # Python's built-in tool for writing CSV files
import os                                       # for reading settings and making folders
from dotenv import load_dotenv                  # reads your .env file (same as the ingest script)
from databricks import sql                      # the Databricks connector that came with dbt

load_dotenv()                                   # load DATABRICKS_HOST, HTTP_PATH and TOKEN from .env

host = os.getenv("DATABRICKS_HOST").replace("https://", "").rstrip("/")  # connector wants the bare host name
http_path = os.getenv("DATABRICKS_HTTP_PATH")   # which SQL warehouse to use
token = os.getenv("DATABRICKS_TOKEN")           # your access token (never printed)

TABLES = [                                      # the Gold tables to export
    "dim_matches",
    "dim_teams",
    "dim_venues",
    "fct_deliveries",
    "fct_batting_innings",
    "fct_bowling_innings",
]

OUT_DIR = "exports"                             # folder the CSVs go into
os.makedirs(OUT_DIR, exist_ok=True)             # create it if it doesn't exist yet

with sql.connect(server_hostname=host, http_path=http_path, access_token=token) as conn:  # open the connection
    with conn.cursor() as cur:                  # a cursor sends queries and brings back results
        for table in TABLES:                    # repeat the steps below for each table
            cur.execute(f"SELECT * FROM ipl_analytics.analytics.{table}")  # read the whole table
            rows = cur.fetchall()               # bring all rows back to the Mac
            headers = [col[0] for col in cur.description]  # the column names, for the CSV header row
            path = os.path.join(OUT_DIR, f"{table}.csv")   # e.g. exports/dim_matches.csv
            with open(path, "w", newline="", encoding="utf-8") as f:  # create the CSV file
                writer = csv.writer(f)
                writer.writerow(headers)        # first line: column names
                writer.writerows(rows)          # then every row of data
            print(f"{table}: {len(rows)} rows -> {path}")  # show progress on screen