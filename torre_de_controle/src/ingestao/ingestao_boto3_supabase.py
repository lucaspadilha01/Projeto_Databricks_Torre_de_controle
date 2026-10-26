# Databricks notebook source
import os

VARIAVEIS = ["S3_ENDPOINT", "AWS_DEFAULT_REGION", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"]
SECRET_KEYS = {
    "S3_ENDPOINT": "s3_endpoint",
    "AWS_DEFAULT_REGION": "s3_region",
    "AWS_ACCESS_KEY_ID": "s3_access_key",
    "AWS_SECRET_ACCESS_KEY": "s3_secret_key",
}

for nome in VARIAVEIS:
    if os.environ.get(nome):                       # já veio do job (Environment variables)? usa esse
        continue
    try:                                            # senão, tenta Databricks Secrets
        os.environ[nome] = dbutils.secrets.get(scope="supabase", key=SECRET_KEYS[nome])
        continue
    except Exception:
        pass
    dbutils.widgets.text(nome, "")                 # senão, a caixinha (o job preenche pelos Parameters)
    os.environ[nome] = dbutils.widgets.get(nome)   # e o valor vira variável de ambiente

faltando = [nome for nome in VARIAVEIS if not os.environ[nome]]
assert not faltando, f"preencha: {faltando}"      # para aqui se faltar alguma chave

S3_BUCKET = "DataLakeVertice"
RAW = "/Volumes/lakehouse_vertice/bronze/raw"
print("ambiente pronto:", os.environ["S3_ENDPOINT"])

# COMMAND ----------

import boto3
from botocore.config import Config

s3 = boto3.client(
    "s3",
    endpoint_url=os.environ["S3_ENDPOINT"],
    config=Config(s3={"addressing_style": "path"}),   # o Supabase só entende o bucket no caminho da URL
)

for bucket in s3.list_buckets()["Buckets"]:
    print(bucket["Name"])

# COMMAND ----------

S3_BUCKET = dbutils.secrets.get(scope="supabase", key="s3_bucket")
objetos = []
for pagina in s3.get_paginator("list_objects_v2").paginate(Bucket=S3_BUCKET):
    objetos += pagina.get("Contents", [])

# só arquivos (o storage cria um objeto vazio de marcação em cada pasta)
arquivos = [o["Key"] for o in objetos if not o["Key"].endswith("/") and o["Size"] > 0
            and not o["Key"].endswith(".emptyFolderPlaceholder")]

from collections import Counter
for pasta, n in sorted(Counter(k.split("/")[0] for k in arquivos).items()):
    print(f"{pasta:<12} {n:>3} arquivos")
print(f"{'total':<12} {len(arquivos):>3}")

# COMMAND ----------

import os

def baixar(key):
    destino = f"{RAW}/{key}"                                   # o mesmo caminho do bucket
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    conteudo = s3.get_object(Bucket=S3_BUCKET, Key=key)["Body"].read()   # 1 · extrair
    with open(destino, "wb") as f:                                        # 2 · pousar
        f.write(conteudo)
    return len(conteudo)

total = 0
for key in arquivos:
    total += baixar(key)
print(f"{len(arquivos)} arquivos, {total/1e6:.1f} MB no raw")

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE OR REPLACE TABLE lakehouse_vertice.bronze.projetos AS
# MAGIC SELECT * EXCEPT (_rescued_data)
# MAGIC FROM read_files('/Volumes/lakehouse_vertice/bronze/raw/pmo/projetos.csv',
# MAGIC                 format => 'csv', header => true, inferColumnTypes => false);
# MAGIC
# MAGIC CREATE OR REPLACE TABLE lakehouse_vertice.bronze.status_semanal AS
# MAGIC SELECT * EXCEPT (_rescued_data)
# MAGIC FROM read_files('/Volumes/lakehouse_vertice/bronze/raw/pmo/status_semanal.csv',
# MAGIC                 format => 'csv', header => true, inferColumnTypes => false);
# MAGIC
# MAGIC CREATE OR REPLACE TABLE lakehouse_vertice.bronze.colaboradores AS
# MAGIC SELECT * EXCEPT (_rescued_data)
# MAGIC FROM read_files('/Volumes/lakehouse_vertice/bronze/raw/rh/colaboradores.csv',
# MAGIC                 format => 'csv', header => true, inferColumnTypes => false);
# MAGIC
# MAGIC CREATE OR REPLACE TABLE lakehouse_vertice.bronze.apontamentos AS
# MAGIC SELECT * EXCEPT (_rescued_data)
# MAGIC FROM read_files('/Volumes/lakehouse_vertice/bronze/raw/timesheet/apontamentos.csv',
# MAGIC                 format => 'csv', header => true, inferColumnTypes => false);
# MAGIC
# MAGIC CREATE OR REPLACE TABLE lakehouse_vertice.bronze.custos AS
# MAGIC SELECT * EXCEPT (_rescued_data)
# MAGIC FROM read_files('/Volumes/lakehouse_vertice/bronze/raw/financeiro/custos.csv',
# MAGIC                 format => 'csv', header => true, inferColumnTypes => false);
# MAGIC
# MAGIC CREATE OR REPLACE TABLE lakehouse_vertice.bronze.entregas_fornecedor AS
# MAGIC SELECT * EXCEPT (_rescued_data)
# MAGIC FROM read_files('/Volumes/lakehouse_vertice/bronze/raw/compras/entregas_fornecedor.csv',
# MAGIC                 format => 'csv', header => true, inferColumnTypes => false);

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE OR REPLACE TABLE lakehouse_vertice.bronze.excel_tarefas AS
# MAGIC SELECT `ID`               AS id,
# MAGIC        `Fase`             AS fase,
# MAGIC        `Tarefa`           AS tarefa,
# MAGIC        `Responsável`      AS responsavel,
# MAGIC        `Início previsto`  AS inicio_previsto,
# MAGIC        `Término previsto` AS termino_previsto,
# MAGIC        `Início real`      AS inicio_real,
# MAGIC        `Término real`     AS termino_real,
# MAGIC        `% Concluído`      AS pct_concluido,
# MAGIC        `Horas previstas`  AS horas_previstas,
# MAGIC        url_decode(_metadata.file_name) AS arquivo
# MAGIC FROM read_files('/Volumes/lakehouse_vertice/bronze/raw/excel/',
# MAGIC                 format => 'excel', headerRows => 1, inferColumnTypes => false);
# MAGIC
# MAGIC CREATE OR REPLACE TABLE lakehouse_vertice.bronze.clickup_tarefas AS
# MAGIC SELECT list.id   AS list_id,
# MAGIC        list.name AS list_name,
# MAGIC        t.*,
# MAGIC        url_decode(_metadata.file_name) AS arquivo
# MAGIC FROM (
# MAGIC     SELECT list, explode(tasks) AS t, _metadata
# MAGIC     FROM read_files('/Volumes/lakehouse_vertice/bronze/raw/clickup/',
# MAGIC                     format => 'json', multiLine => true)
# MAGIC );
# MAGIC
# MAGIC CREATE OR REPLACE TABLE lakehouse_vertice.bronze.msproject_tarefas AS
# MAGIC SELECT * EXCEPT (_rescued_data),
# MAGIC        url_decode(_metadata.file_name) AS arquivo
# MAGIC FROM read_files('/Volumes/lakehouse_vertice/bronze/raw/msproject/',
# MAGIC                 format => 'xml', rowTag => 'Task');

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE OR REPLACE TABLE lakehouse_vertice.bronze.excel_tarefas AS
# MAGIC SELECT `ID`               AS id,
# MAGIC        `Fase`             AS fase,
# MAGIC        `Tarefa`           AS tarefa,
# MAGIC        `Responsável`      AS responsavel,
# MAGIC        `Início previsto`  AS inicio_previsto,
# MAGIC        `Término previsto` AS termino_previsto,
# MAGIC        `Início real`      AS inicio_real,
# MAGIC        `Término real`     AS termino_real,
# MAGIC        `% Concluído`      AS pct_concluido,
# MAGIC        `Horas previstas`  AS horas_previstas,
# MAGIC        url_decode(_metadata.file_name) AS arquivo
# MAGIC FROM read_files('/Volumes/lakehouse_vertice/bronze/raw/excel/',
# MAGIC                 format => 'excel', headerRows => 1, inferColumnTypes => false);
# MAGIC
# MAGIC CREATE OR REPLACE TABLE lakehouse_vertice.bronze.clickup_tarefas AS
# MAGIC SELECT list.id   AS list_id,
# MAGIC        list.name AS list_name,
# MAGIC        t.*,
# MAGIC        url_decode(_metadata.file_name) AS arquivo
# MAGIC FROM (
# MAGIC     SELECT list, explode(tasks) AS t, _metadata
# MAGIC     FROM read_files('/Volumes/lakehouse_vertice/bronze/raw/clickup/',
# MAGIC                     format => 'json', multiLine => true)
# MAGIC );
# MAGIC
# MAGIC CREATE OR REPLACE TABLE lakehouse_vertice.bronze.msproject_tarefas AS
# MAGIC SELECT * EXCEPT (_rescued_data),
# MAGIC        url_decode(_metadata.file_name) AS arquivo
# MAGIC FROM read_files('/Volumes/lakehouse_vertice/bronze/raw/msproject/',
# MAGIC                 format => 'xml', rowTag => 'Task');

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Deve aparecer o mesmo de ontem:
# MAGIC -- apontamentos 30.883 · custos 23.640 · status_semanal 3.911 · clickup_tarefas 2.119 · excel_tarefas 1.663
# MAGIC -- msproject_tarefas 1.260 · entregas_fornecedor 640 · colaboradores 523 · projetos 60
# MAGIC SELECT 'projetos' AS tabela, COUNT(*) AS linhas FROM lakehouse_vertice.bronze.projetos
# MAGIC UNION ALL SELECT 'status_semanal', COUNT(*) FROM lakehouse_vertice.bronze.status_semanal
# MAGIC UNION ALL SELECT 'excel_tarefas', COUNT(*) FROM lakehouse_vertice.bronze.excel_tarefas
# MAGIC UNION ALL SELECT 'clickup_tarefas', COUNT(*) FROM lakehouse_vertice.bronze.clickup_tarefas
# MAGIC UNION ALL SELECT 'msproject_tarefas', COUNT(*) FROM lakehouse_vertice.bronze.msproject_tarefas
# MAGIC UNION ALL SELECT 'colaboradores', COUNT(*) FROM lakehouse_vertice.bronze.colaboradores
# MAGIC UNION ALL SELECT 'apontamentos', COUNT(*) FROM lakehouse_vertice.bronze.apontamentos
# MAGIC UNION ALL SELECT 'custos', COUNT(*) FROM lakehouse_vertice.bronze.custos
# MAGIC UNION ALL SELECT 'entregas_fornecedor', COUNT(*) FROM lakehouse_vertice.bronze.entregas_fornecedor
# MAGIC ORDER BY linhas DESC