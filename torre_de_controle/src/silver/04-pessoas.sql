-- silver.colaboradores e silver.apontamentos

CREATE OR REFRESH MATERIALIZED VIEW colaboradores
COMMENT 'Cadastro das 520 pessoas: papel, senioridade, custo por hora, admissão e desligamento. Os 3 cadastros duplicados (nome e papel em CAIXA ALTA) foram resolvidos mantendo a linha com papel em minúsculas.'
AS
SELECT
  colaborador_id,
  nome,
  papel,
  senioridade,
  CAST(custo_hora AS DECIMAL(10, 2)) AS custo_hora,
  try_to_date(data_admissao, 'yyyy-MM-dd') AS data_admissao,
  try_to_date(nullif(trim(data_desligamento), ''), 'yyyy-MM-dd') AS data_desligamento
FROM (
  SELECT
    *,
    -- na duplicata, fica a linha com papel já em minúsculas
    row_number() OVER (
      PARTITION BY colaborador_id
      ORDER BY CASE WHEN papel = lower(papel) THEN 0 ELSE 1 END
    ) AS ordem
  FROM lakehouse_vertice.bronze.colaboradores
)
WHERE ordem = 1;

CREATE OR REFRESH MATERIALIZED VIEW apontamentos
COMMENT 'Timesheet semanal: horas disponíveis e horas apontadas por pessoa e projeto. semana é a sexta-feira da semana (semana_inicio, que é segunda, mais 4 dias).'
AS
SELECT
  colaborador_id,
  projeto_id,
  CAST(semana_inicio AS DATE) AS semana_inicio,
  date_add(CAST(semana_inicio AS DATE), 4) AS semana,
  CAST(horas_disponiveis AS DOUBLE) AS horas_disponiveis,
  CAST(horas_apontadas AS DOUBLE) AS horas_apontadas
FROM lakehouse_vertice.bronze.apontamentos;
