# Databricks notebook source
# DBTITLE 1,Ingestão de feriados
import requests
url = "https://brasilapi.com.br/api/feriados/v1/2026"
import json, os
from datetime import datetime
pasta = "/Volumes/lakehouse_vertice/bronze/raw/feriado"
agora = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")  

resposta = requests.get(url)
feriados = resposta.json()

with open(f"{pasta}/feriados_{agora}.json", "w") as arquivo:
    json.dump(feriados, arquivo, ensure_ascii=False)


# COMMAND ----------

# DBTITLE 1,Cell 2
# MAGIC %sql
# MAGIC
# MAGIC  CREATE OR REPLACE TABLE lakehouse_vertice.bronze.raw_feriado AS
# MAGIC    SELECT date AS data, name AS feriado, type AS tipo, weekday AS dia_da_semana,
# MAGIC           _metadata.file_name AS arquivo,
# MAGIC           _metadata.file_modification_time AS coletado_em
# MAGIC    FROM read_files('/Volumes/lakehouse_vertice/bronze/raw/feriado/', format => 'json', multiLine => true)
# MAGIC