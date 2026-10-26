-- gold.fato_projeto_semana: uma linha por projeto e semana (sexta-feira), da semana do início
-- até o "hoje" do dataset (2026-10-16). Aqui está o histórico: o % de cada sexta vem do status semanal.
-- Janelas ficam em CTE próprio: função de janela dentro de agregação dá erro no pipeline.

CREATE OR REFRESH MATERIALIZED VIEW lakehouse_vertice.gold.fato_projeto_semana (
  CONSTRAINT pv_nao_negativo EXPECT (pv >= 0) ON VIOLATION FAIL UPDATE,
  CONSTRAINT ev_ate_o_orcamento EXPECT (ev <= orcamento) ON VIOLATION FAIL UPDATE
)
COMMENT 'Uma linha por projeto e semana (sexta-feira) desde o início até 16/10/2026. pv = valor planejado (orçamento x fração do baseline decorrida), ev = valor agregado (orçamento x % do status semanal), ac = custo real acumulado. spi = ev/pv, cpi = ev/ac, eac = orçamento/cpi. Traz também o último farol do gerente e as horas disponíveis, apontadas e ociosas da semana.'
AS
WITH semanas AS (
  -- uma sexta-feira por semana, da semana do início até hoje
  SELECT
    projeto_id,
    orcamento_custo AS orcamento,
    data_inicio,
    data_fim_baseline,
    explode(sequence(
      date_add(CAST(date_trunc('WEEK', data_inicio) AS DATE), 4),
      DATE'2026-10-16',
      INTERVAL 1 WEEK
    )) AS semana
  FROM projetos
),
custo_acumulado AS (
  -- custo real até a semana (soma de tudo que foi lançado até aquela sexta)
  SELECT s.projeto_id, s.semana, coalesce(sum(c.valor), 0) AS ac
  FROM semanas s
  LEFT JOIN custos c ON c.projeto_id = s.projeto_id AND c.semana <= s.semana
  GROUP BY s.projeto_id, s.semana
),
horas AS (
  SELECT projeto_id, semana,
         sum(horas_disponiveis) AS horas_disponiveis,
         sum(horas_apontadas) AS horas_apontadas
  FROM apontamentos
  GROUP BY projeto_id, semana
),
juntas AS (
  SELECT
    s.projeto_id, s.semana, s.orcamento, s.data_inicio, s.data_fim_baseline,
    st.pct_concluido AS pct_da_semana,
    st.farol AS farol_da_semana,
    ca.ac,
    h.horas_disponiveis, h.horas_apontadas
  FROM semanas s
  LEFT JOIN status_semanal st ON st.projeto_id = s.projeto_id AND st.data_status = s.semana
  LEFT JOIN custo_acumulado ca ON ca.projeto_id = s.projeto_id AND ca.semana = s.semana
  LEFT JOIN horas h ON h.projeto_id = s.projeto_id AND h.semana = s.semana
),
com_ultimo_status AS (
  -- projeto concluído não publica mais status: carrega o último % e o último farol
  SELECT
    *,
    last_value(pct_da_semana, true) OVER (PARTITION BY projeto_id ORDER BY semana) AS pct_concluido,
    last_value(farol_da_semana, true) OVER (PARTITION BY projeto_id ORDER BY semana) AS farol_do_gerente
  FROM juntas
),
kpis AS (
  SELECT
    *,
    -- fração do prazo baseline decorrida até a semana (entre 0 e 1)
    orcamento * greatest(0, least(1, datediff(semana, data_inicio) / datediff(data_fim_baseline, data_inicio))) AS pv,
    orcamento * coalesce(pct_concluido, 0) / 100 AS ev
  FROM com_ultimo_status
)
SELECT
  projeto_id,
  semana,
  CAST(orcamento AS DECIMAL(15, 2)) AS orcamento,
  CAST(pv AS DECIMAL(15, 2)) AS pv,
  CAST(ev AS DECIMAL(15, 2)) AS ev,
  CAST(ac AS DECIMAL(15, 2)) AS ac,
  round(try_divide(ev, pv), 4) AS spi,
  round(try_divide(ev, ac), 4) AS cpi,
  CAST(try_divide(orcamento, round(try_divide(ev, ac), 4)) AS DECIMAL(15, 2)) AS eac,
  pct_concluido,
  farol_do_gerente,
  coalesce(horas_disponiveis, 0) AS horas_disponiveis,
  coalesce(horas_apontadas, 0) AS horas_apontadas,
  coalesce(horas_disponiveis, 0) - coalesce(horas_apontadas, 0) AS horas_ociosas
FROM kpis;
