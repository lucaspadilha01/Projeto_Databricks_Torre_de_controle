-- silver.tarefas: AS TRÊS FERRAMENTAS VIRAM UMA.
-- Uma visão temporária por ferramenta, todas com as MESMAS colunas, e um UNION ALL no fim.

-- ---------------------------------------------------------------- Excel
CREATE TEMPORARY VIEW tarefas_excel AS
SELECT
  -- projeto pelo de-para (nome do arquivo) ou, se não casar, pelo PRJ-xxx do nome do arquivo
  p.projeto_id,
  'excel' AS ferramenta,
  CAST(e.id AS STRING) AS id_na_ferramenta,
  e.fase,
  e.tarefa,
  e.responsavel,
  -- data com '/' é dd/MM/yyyy; senão é o número de série do Excel
  CASE WHEN e.inicio_previsto LIKE '%/%' THEN try_to_date(e.inicio_previsto, 'dd/MM/yyyy')
       ELSE date_add(DATE'1899-12-30', try_cast(e.inicio_previsto AS INT)) END AS inicio_baseline,
  CASE WHEN e.termino_previsto LIKE '%/%' THEN try_to_date(e.termino_previsto, 'dd/MM/yyyy')
       ELSE date_add(DATE'1899-12-30', try_cast(e.termino_previsto AS INT)) END AS fim_baseline,
  CASE WHEN e.inicio_real LIKE '%/%' THEN try_to_date(e.inicio_real, 'dd/MM/yyyy')
       ELSE date_add(DATE'1899-12-30', try_cast(e.inicio_real AS INT)) END AS inicio_real,
  CASE WHEN e.termino_real LIKE '%/%' THEN try_to_date(e.termino_real, 'dd/MM/yyyy')
       ELSE date_add(DATE'1899-12-30', try_cast(e.termino_real AS INT)) END AS fim_real,
  -- com '%': tira o '%' e troca vírgula por ponto; sem '%': é fração (x 100)
  CASE WHEN e.pct_concluido LIKE '%\%%' THEN try_cast(replace(replace(e.pct_concluido, '%', ''), ',', '.') AS DOUBLE)
       ELSE try_cast(e.pct_concluido AS DOUBLE) * 100 END AS pct_como_veio,
  try_cast(replace(e.horas_previstas, 'h', '') AS DOUBLE) AS horas,
  CAST(NULL AS STRING) AS status_na_ferramenta
FROM lakehouse_vertice.bronze.excel_tarefas e
LEFT JOIN projetos p
  ON p.ferramenta = 'excel'
 AND (p.codigo_ferramenta = e.arquivo
      OR p.projeto_id = nullif(regexp_extract(e.arquivo, 'PRJ-[0-9]{3}', 0), ''))
WHERE e.tarefa <> 'TOTAL';

-- ---------------------------------------------------------------- ClickUp
CREATE TEMPORARY VIEW tarefas_clickup AS
SELECT
  p.projeto_id,
  'clickup' AS ferramenta,
  c.id AS id_na_ferramenta,
  lower(filter(c.custom_fields, f -> f.name = 'Fase')[0].value) AS fase,
  c.name AS tarefa,
  c.assignees[0].username AS responsavel,
  to_date(timestamp_millis(try_cast(filter(c.custom_fields, f -> f.name = 'Início baseline')[0].value AS BIGINT))) AS inicio_baseline,
  to_date(timestamp_millis(try_cast(filter(c.custom_fields, f -> f.name = 'Fim baseline')[0].value AS BIGINT))) AS fim_baseline,
  to_date(timestamp_millis(try_cast(c.start_date AS BIGINT))) AS inicio_real,
  to_date(timestamp_millis(try_cast(c.date_done AS BIGINT))) AS fim_real,
  try_cast(filter(c.custom_fields, f -> f.name = 'Progresso (%)')[0].value AS DOUBLE) AS pct_como_veio,
  c.time_estimate / 3600000.0 AS horas,
  -- status escrito de 12 jeitos -> 3
  CASE
    WHEN c.status.type = 'closed' OR lower(c.status.status) RLIKE 'done|conclu|complete|closed|finaliz' THEN 'concluida'
    WHEN lower(c.status.status) RLIKE 'progress|andamento|doing|review|revis|wip|em curso' THEN 'em_andamento'
    ELSE 'a_fazer'
  END AS status_na_ferramenta
FROM lakehouse_vertice.bronze.clickup_tarefas c
LEFT JOIN projetos p
  ON p.ferramenta = 'clickup'
 AND (p.codigo_ferramenta = c.list_id OR p.nome_projeto = c.list_name);

-- ---------------------------------------------------------------- MS Project
-- A fase é a última tarefa-resumo de OutlineLevel 1 antes da tarefa. A janela precisa ver
-- as linhas-resumo, então ela roda antes do filtro Summary = 0.
CREATE TEMPORARY VIEW msproject_com_fase AS
SELECT
  *,
  last_value(CASE WHEN OutlineLevel = 1 THEN Name END, true)
    OVER (PARTITION BY arquivo ORDER BY UID) AS fase
FROM lakehouse_vertice.bronze.msproject_tarefas;

CREATE TEMPORARY VIEW tarefas_msproject AS
SELECT
  p.projeto_id,
  'msproject' AS ferramenta,
  CAST(m.UID AS STRING) AS id_na_ferramenta,
  m.fase,
  m.Name AS tarefa,
  CAST(NULL AS STRING) AS responsavel,
  to_date(m.Baseline.Start) AS inicio_baseline,
  to_date(m.Baseline.Finish) AS fim_baseline,
  to_date(m.ActualStart) AS inicio_real,
  to_date(m.ActualFinish) AS fim_real,
  CAST(m.PercentComplete AS DOUBLE) AS pct_como_veio,
  try_cast(regexp_extract(m.Work, 'PT([0-9]+)H', 1) AS DOUBLE) AS horas,
  CAST(NULL AS STRING) AS status_na_ferramenta
FROM msproject_com_fase m
LEFT JOIN projetos p
  ON p.ferramenta = 'msproject'
 AND p.codigo_ferramenta = m.arquivo
-- as tarefas-resumo somam as de baixo: ficam de fora
WHERE m.Summary = 0;

-- ---------------------------------------------------------------- A integração
CREATE OR REFRESH MATERIALIZED VIEW tarefas (
  CONSTRAINT achou_o_projeto EXPECT (projeto_id IS NOT NULL) ON VIOLATION FAIL UPDATE,
  CONSTRAINT pct_entre_0_e_100 EXPECT (pct_concluido BETWEEN 0 AND 100) ON VIOLATION FAIL UPDATE,
  CONSTRAINT horas_positivas EXPECT (horas > 0) ON VIOLATION FAIL UPDATE
)
COMMENT 'Todas as tarefas dos 60 projetos num modelo só, vindas de Excel, ClickUp e MS Project. Uma linha por tarefa, com datas de baseline e reais, % concluído (0 a 100) e horas previstas. Linhas de TOTAL (Excel) e tarefas-resumo (MS Project) ficam de fora.'
AS
WITH todas AS (
  SELECT * FROM tarefas_excel
  UNION ALL
  SELECT * FROM tarefas_clickup
  UNION ALL
  SELECT * FROM tarefas_msproject
)
SELECT
  concat_ws('-', projeto_id, ferramenta, id_na_ferramenta) AS tarefa_id,
  projeto_id,
  ferramenta,
  id_na_ferramenta,
  fase,
  tarefa,
  responsavel,
  inicio_baseline,
  fim_baseline,
  inicio_real,
  fim_real,
  pct_como_veio,
  -- alguns % vêm acima de 100: limita e sinaliza
  least(pct_como_veio, 100) AS pct_concluido,
  pct_como_veio > 100 AS pct_veio_acima_de_100,
  horas,
  status_na_ferramenta
FROM todas;
