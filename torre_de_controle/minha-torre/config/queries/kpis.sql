-- KPIs da carteira em andamento (fotografia de 16/10/2026). Nada do score aqui.
SELECT
  CAST(COUNT(*) AS INT) AS projetos_em_andamento,
  CAST(COUNT_IF(situacao IN ('atenção', 'crítico')) AS INT) AS em_risco,
  CAST(COUNT_IF(situacao = 'crítico') AS INT) AS criticos,
  CAST(COUNT_IF(melancia) AS INT) AS melancias,
  CAST(SUM(estouro_previsto) AS DOUBLE) AS estouro_previsto,
  CAST(SUM(valor_contrato) AS DOUBLE) AS carteira
FROM lakehouse_vertice.gold.projeto_situacao_atual
WHERE status = 'em_andamento'
