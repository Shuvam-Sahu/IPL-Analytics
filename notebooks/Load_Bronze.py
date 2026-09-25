# Databricks notebook source
files = dbutils.fs.ls("abfss://cricsheet-raw@iplanalyticsstorage1.dfs.core.windows.net/")

info_paths = []
deliveries_paths = []

for f in files:
    if f.name == "all_matches.csv":          # skip the combined file entirely
        continue
    if f.name.endswith("_info.csv"):
        info_paths.append(f.path)
    else:
        deliveries_paths.append(f.path)

print(f"Info files: {len(info_paths)}")
print(f"Delivery files: {len(deliveries_paths)}")

# COMMAND ----------

spark.sql("DROP TABLE IF EXISTS ipl_analytics.bronze.deliveries_raw")
spark.sql("DROP TABLE IF EXISTS ipl_analytics.bronze.match_info_raw")

deliveries_df = spark.read.csv(deliveries_paths, header=True, inferSchema=True)
info_df = spark.read.csv(info_paths, header=True, inferSchema=True)

deliveries_df.write.format("delta").saveAsTable("ipl_analytics.bronze.deliveries_raw")
info_df.write.format("delta").saveAsTable("ipl_analytics.bronze.match_info_raw")

# COMMAND ----------

spark.sql("""
SELECT *
FROM ipl_analytics.bronze.deliveries_raw
WHERE match_id = 1082591
""").show()

# COMMAND ----------

spark.sql("""
SELECT match_id,
batting_team, 
SUM(runs_off_bat) + SUM(extras)  AS runs
FROM ipl_analytics.bronze.deliveries_raw
WHERE match_id = 1082591
GROUP BY match_id, batting_team
""").show()

# COMMAND ----------

print(f"Total paths: {len(deliveries_paths)}")
print(f"Unique paths: {len(set(deliveries_paths))}")