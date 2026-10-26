-- Projetos em andamento, do pior para o melhor, com a causa de bloqueio mais frequente
-- nos últimos 90 dias (a partir de 18/07/2026) e os dias de impacto por falta_sre e rotatividade.
WITH causas AS (
  SELECT
    projeto_id,
    causa_bloqueio,
    COUNT(*) AS ocorrencias,
    SUM(COALESCE(dias_impacto, 0)) AS dias
  FROM lakehouse_vertice.gold.status_estruturado
  WHERE data_status >= DATE'2026-07-18'
    AND causa_bloqueio NOT IN ('sem_bloqueio', 'nao_reportado')
  GROUP BY projeto_id, causa_bloqueio
),
por_projeto AS (
  SELECT
    projeto_id,
    MAX_BY(causa_bloqueio, STRUCT(ocorrencias, dias)) AS causa_principal,
    SUM(CASE WHEN causa_bloqueio = 'falta_sre' THEN dias ELSE 0 END) AS dias_falta_sre,
    SUM(CASE WHEN causa_bloqueio = 'rotatividade' THEN dias ELSE 0 END) AS dias_rotatividade
  FROM causas
  GROUP BY projeto_id
)
SELECT
  p.projeto_id,
  concat(p.projeto, ' · ', p.nome_projeto) AS projeto,
  p.cliente,
  p.situacao,
  CAST(p.spi AS DOUBLE) AS spi,
  CAST(p.cpi AS DOUBLE) AS cpi,
  CAST(p.estouro_previsto AS DOUBLE) AS estouro_previsto,
  CAST(p.atraso_projetado_dias AS INT) AS atraso_projetado_dias,
  p.farol_do_gerente,
  p.farol_calculado,
  p.melancia,
  c.causa_principal,
  CAST(COALESCE(c.dias_falta_sre, 0) AS DOUBLE) AS dias_falta_sre,
  CAST(COALESCE(c.dias_rotatividade, 0) AS DOUBLE) AS dias_rotatividade
FROM lakehouse_vertice.gold.projeto_situacao_atual p
LEFT JOIN por_projeto c ON c.projeto_id = p.projeto_id
WHERE p.status = 'em_andamento'
ORDER BY LEAST(p.spi, p.cpi), p.projeto_id
