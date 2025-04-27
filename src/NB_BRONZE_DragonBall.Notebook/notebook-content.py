# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "e45b8ac4-6ef0-495c-9d25-52914450d119",
# META       "default_lakehouse_name": "LH_FT_BRONZE_DragonBall",
# META       "default_lakehouse_workspace_id": "9778e6b7-9e9c-4f55-8779-a6160c6151db",
# META       "known_lakehouses": [
# META         {
# META           "id": "e45b8ac4-6ef0-495c-9d25-52914450d119"
# META         }
# META       ]
# META     }
# META   }
# META }

# MARKDOWN ********************

# # Notebook para la limpieza de datos

# MARKDOWN ********************

# ## Librerias


# CELL ********************

!pip install kagglehub[pandas-datasets]

# Install dependencies as needed:
# pip install kagglehub[pandas-datasets]
import kagglehub
from kagglehub import KaggleDatasetAdapter
import pandas as pd


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# # Carga de datos

# CELL ********************

# Set the path to the file you'd like to load
file_path_char = "dragon_ball_z.csv"

# Load the latest version
df_char = kagglehub.load_dataset(
  KaggleDatasetAdapter.PANDAS,
  "sujithmandala/dragon-ball-z-characters-information",
  file_path_char,
  # Provide any additional arguments like 
  # sql_query or pandas_kwargs. See the 
  # documenation for more information:
  # https://github.com/Kaggle/kagglehub/blob/main/README.md#kaggledatasetadapterpandas
)


# Set the path to the file you'd like to load
file_path_char_info = "dragon_ball_z_characters.csv"

# Load the latest version
df_char_info = kagglehub.load_dataset(
  KaggleDatasetAdapter.PANDAS,
  "shreyasur965/dragon-ball-z-character-database",
  file_path_char_info,
  # Provide any additional arguments like 
  # sql_query or pandas_kwargs. See the 
  # documenation for more information:
  # https://github.com/Kaggle/kagglehub/blob/main/README.md#kaggledatasetadapterpandas
)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

display(df_char_info)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

display(df_char)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# # Limpieza de datos

# CELL ********************

df_char = df_char.drop_duplicates(keep='last')
df_char.columns = df_char.columns.str.lower()

display(df_char)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# # Transformación de los datos

# CELL ********************

char_info_full = pd.merge(df_char_info[['name', 'ki', 'maxKi', 'race', 'gender', 'description', 'image',
       'affiliation']], df_char[['name', 'ki blast', 'melee combat',
       'speed', 'special attack', 'transformation']], on='name', how='left')

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

char_info_full = spark.createDataFrame(char_info_full)
for col in char_info_full.columns:
    char_info_full = char_info_full.withColumnRenamed(col, col.replace(' ', '_'))

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

display(char_info_full)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# # Guardar tabla

# CELL ********************

spark.sql("CREATE SCHEMA IF NOT EXISTS LH_FT_BRONZE_DragonBall")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Guardar el DataFrame como tabla en el Lakehouse
char_info_full.write \
    .format("delta") \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .saveAsTable("LH_FT_BRONZE_DragonBall.DragonBall")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

char_info_full.write \
    .format("delta") \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .save("Files/DragonBall/char_info_full")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
