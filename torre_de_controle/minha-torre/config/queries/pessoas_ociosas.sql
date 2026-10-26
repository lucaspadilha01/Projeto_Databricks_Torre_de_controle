-- Pessoas com utilização < 20% nas últimas 12 semanas (semana > 24/07/2026), por projeto.
-- Horas paradas e custo ocioso são MÉDIAS por semana.
SELECT
  u.colaborador_id,
  u.nome,
  u.papel,
  u.senioridade,
  u.projeto_id,
  CAST(SUM(u.horas_apontadas) / SUM(u.horas_disponiveis) AS DOUBLE) AS utilizacao,
  CAST(SUM(u.horas_ociosas) / COUNT(DISTINCT u.semana) AS DOUBLE) AS horas_paradas_semana,
  CAST(SUM(u.custo_ocioso) / COUNT(DISTINCT u.semana) AS DOUBLE) AS custo_ocioso_semana,
  CAST(MAX(c.custo_hora) AS DOUBLE) AS custo_hora
FROM lakehouse_vertice.gold.utilizacao_pessoa_semana u
LEFT JOIN lakehouse_vertice.silver.colaboradores c ON c.colaborador_id = u.colaborador_id
WHERE u.semana > DATE'2026-07-24'
GROUP BY u.colaborador_id, u.nome, u.papel, u.senioridade, u.projeto_id
HAVING SUM(u.horas_apontadas) / SUM(u.horas_disponiveis) < 0.2
ORDER BY utilizacao
