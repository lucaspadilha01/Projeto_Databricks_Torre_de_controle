-- gold.projeto_situacao_atual e gold.utilizacao_pessoa_semana

-- A fotografia de 16/10/2026 de cada projeto. Os KPIs usam as tarefas das ferramentas (o % de hoje).
CREATE OR REFRESH MATERIALIZED VIEW lakehouse_vertice.gold.projeto_situacao_atual
COMMENT 'Fotografia de 16/10/2026 de cada um dos 60 projetos: cadastro (cliente, segmento, tipo, ferramenta, gerente, contrato, prazo) e KPIs calculados sobre as tarefas das ferramentas (pv, ev, ac, spi, cpi, eac, estouro previsto, margem, atraso projetado). situacao: concluído, crítico (SPI ou CPI < 0,8), atenção (< 0,9) ou ok. melancia = em andamento, farol do gerente verde e SPI < 0,9.'
AS
WITH tarefas_hoje AS (
  SELECT
    projeto_id,
    horas,
    pct_concluido,
    -- fração do prazo baseline da tarefa decorrida até hoje
    CASE
      WHEN fim_baseline IS NULL OR inicio_baseline IS NULL THEN NULL
      WHEN DATE'2026-10-16' >= fim_baseline THEN 1.0
      WHEN DATE'2026-10-16' <= inicio_baseline THEN 0.0
      ELSE datediff(DATE'2026-10-16', inicio_baseline) / datediff(fim_baseline, inicio_baseline)
    END AS fracao_baseline
  FROM tarefas
),
por_projeto AS (
  SELECT
    projeto_id,
    sum(horas) AS horas_totais,
    sum(horas * pct_concluido / 100) AS horas_ganhas,
    sum(horas * fracao_baseline) AS horas_planejadas
  FROM tarefas_hoje
  GROUP BY projeto_id
),
custo_hoje AS (
  SELECT projeto_id, sum(valor) AS ac
  FROM custos
  WHERE semana <= DATE'2026-10-16'
  GROUP BY projeto_id
),
ultimo_farol AS (
  SELECT projeto_id, max_by(farol, data_status) AS farol_do_gerente
  FROM status_semanal
  GROUP BY projeto_id
),
base AS (
  SELECT
    p.projeto_id,
    p.projeto_id AS projeto,
    p.nome_projeto, p.cliente, p.segmento, p.tipo_projeto, p.ferramenta, p.gerente_projeto,
    p.valor_contrato,
    p.orcamento_custo AS orcamento,
    p.data_inicio, p.data_fim_baseline,
    datediff(p.data_fim_baseline, p.data_inicio) AS duracao_baseline_dias,
    p.status,
    p.orcamento_custo * try_divide(t.horas_planejadas, t.horas_totais) AS pv,
    p.orcamento_custo * try_divide(t.horas_ganhas, t.horas_totais) AS ev,
    coalesce(c.ac, 0) AS ac,
    f.farol_do_gerente
  FROM projetos p
  LEFT JOIN por_projeto t ON t.projeto_id = p.projeto_id
  LEFT JOIN custo_hoje c ON c.projeto_id = p.projeto_id
  LEFT JOIN ultimo_farol f ON f.projeto_id = p.projeto_id
),
kpis AS (
  SELECT
    *,
    round(try_divide(ev, pv), 4) AS spi,
    round(try_divide(ev, ac), 4) AS cpi
  FROM base
),
projetado AS (
  SELECT
    *,
    try_divide(orcamento, cpi) AS eac
  FROM kpis
)
SELECT
  projeto_id, projeto, nome_projeto, cliente, segmento, tipo_projeto, ferramenta, gerente_projeto,
  valor_contrato, orcamento, data_inicio, data_fim_baseline, duracao_baseline_dias, status,
  CAST(pv AS DECIMAL(15, 2)) AS pv,
  CAST(ev AS DECIMAL(15, 2)) AS ev,
  CAST(ac AS DECIMAL(15, 2)) AS ac,
  spi,
  cpi,
  CAST(eac AS DECIMAL(15, 2)) AS eac,
  CAST(greatest(eac - orcamento, 0) AS DECIMAL(15, 2)) AS estouro_previsto,
  round(try_divide(valor_contrato - eac, valor_contrato), 4) AS margem_projetada,
  CAST(round(try_divide(duracao_baseline_dias, spi) - duracao_baseline_dias) AS INT) AS atraso_projetado_dias,
  date_add(data_inicio, CAST(ceil(try_divide(duracao_baseline_dias, spi)) AS INT)) AS termino_projetado,
  CASE
    WHEN status <> 'em_andamento' THEN 'concluído'
    WHEN spi < 0.8 OR cpi < 0.8 THEN 'crítico'
    WHEN spi < 0.9 OR cpi < 0.9 THEN 'atenção'
    ELSE 'ok'
  END AS situacao,
  farol_do_gerente,
  -- regra do manual da Vértice
  CASE WHEN spi >= 0.95 THEN 'verde' WHEN spi >= 0.90 THEN 'amarelo' ELSE 'vermelho' END AS farol_calculado,
  (status = 'em_andamento' AND farol_do_gerente = 'verde' AND spi < 0.9) AS melancia
FROM projetado;

-- Pessoa x projeto x semana, com o custo da ociosidade e o SPI do projeto naquela semana.
CREATE OR REFRESH MATERIALIZED VIEW lakehouse_vertice.gold.utilizacao_pessoa_semana
COMMENT 'Timesheet por pessoa, projeto e semana (sexta-feira): horas disponíveis, apontadas e ociosas, taxa de utilização, custo da ociosidade (horas ociosas x custo por hora) e o SPI do projeto naquela semana, para cruzar gente parada com projeto atrasado.'
AS
SELECT
  a.colaborador_id,
  c.nome,
  c.papel,
  c.senioridade,
  a.projeto_id,
  a.semana,
  a.horas_disponiveis,
  a.horas_apontadas,
  a.horas_disponiveis - a.horas_apontadas AS horas_ociosas,
  round(try_divide(a.horas_apontadas, a.horas_disponiveis), 4) AS utilizacao,
  CAST((a.horas_disponiveis - a.horas_apontadas) * c.custo_hora AS DECIMAL(15, 2)) AS custo_ocioso,
  f.spi AS spi_do_projeto
FROM apontamentos a
LEFT JOIN colaboradores c ON c.colaborador_id = a.colaborador_id
LEFT JOIN lakehouse_vertice.gold.fato_projeto_semana f
  ON f.projeto_id = a.projeto_id AND f.semana = a.semana;
