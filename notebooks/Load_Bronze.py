# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze load: Cricsheet IPL
# MAGIC
# MAGIC Source: Cricsheet IPL CSV zip, landed in the Azure container `cricsheet-raw`.
# MAGIC
# MAGIC Tables (catalog `ipl_analytics`, schema `bronze`):
# MAGIC - `deliveries_raw`: one row per ball bowled. 295732 rows, 1243 matches.
# MAGIC - `match_info_raw`: one row per line of each match info file. 95690 rows, 1243 files.
# MAGIC
# MAGIC Notes:
# MAGIC - `all_matches.csv` is skipped. It repeats every ball in the per-match files and would double the data.
# MAGIC - The `_info.csv` files have no header and lines of different widths, so they load with a fixed 5-column schema plus `source_file`.
# MAGIC - Re-running this notebook drops and rebuilds both tables.
# MAGIC
# MAGIC Numbers as of: 4th October 2026

# COMMAND ----------

files = dbutils.fs.ls("abfss://cricsheet-raw@iplanalyticsstorage1.dfs.core.windows.net/")

info_paths = []        # paths of the match info files
deliveries_paths = []  # paths of the ball-by-ball files

for f in files:
    if f.name == "all_matches.csv":     # skip the combined file, it repeats every ball
        continue
    if f.name.endswith("_info.csv"):
        info_paths.append(f.path)
    else:
        deliveries_paths.append(f.path)

print(f"Info files: {len(info_paths)}")
print(f"Delivery files: {len(deliveries_paths)}")

# COMMAND ----------

spark.sql("DROP TABLE IF EXISTS ipl_analytics.bronze.deliveries_raw")

deliveries_df = spark.read.csv(deliveries_paths, header=True, inferSchema=True)

deliveries_df.write.format("delta").saveAsTable("ipl_analytics.bronze.deliveries_raw")

# COMMAND ----------

from pyspark.sql.types import StructType, StructField, StringType
from pyspark.sql.functions import col

spark.sql("DROP TABLE IF EXISTS ipl_analytics.bronze.match_info_raw")

spark.sql("""
CREATE TABLE ipl_analytics.bronze.match_info_raw (
    source_file VARCHAR(200),
    info_type VARCHAR(100),
    field VARCHAR(100),
    value1 VARCHAR(100),
    value2 VARCHAR(100),
    value3 VARCHAR(100)
)
USING DELTA
""")

info_schema = StructType([
    StructField("info_type", StringType(), True),
    StructField("field", StringType(), True),
    StructField("value1", StringType(), True),
    StructField("value2", StringType(), True),
    StructField("value3", StringType(), True),
])

info_df = spark.read.csv(info_paths, header=False, schema=info_schema, mode="PERMISSIVE")
info_df = info_df.withColumn("source_file", col("_metadata.file_path"))
info_df = info_df.select("source_file", "info_type", "field", "value1", "value2", "value3")

info_df.write.format("delta").mode("append").saveAsTable("ipl_analytics.bronze.match_info_raw")

# COMMAND ----------

spark.sql("""
SELECT 'deliveries_raw' AS table_name, COUNT(*) AS total_rows, COUNT(DISTINCT match_id) AS matches_or_files
FROM ipl_analytics.bronze.deliveries_raw
UNION ALL
SELECT 'match_info_raw', COUNT(*), COUNT(DISTINCT source_file)
FROM ipl_analytics.bronze.match_info_raw
""").show(truncate=False)