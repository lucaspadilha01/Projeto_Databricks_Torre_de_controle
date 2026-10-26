-- Testes de qualidade: cada teste vira uma linha; se falhar, raise_error() para o job e diz qual.
-- Um SELECT só (a sql_task corta o arquivo em cada ponto e vírgula).

WITH testes AS (
  SELECT 1 AS n, 'os 60 projetos têm cronograma na silver.tarefas' AS descricao,
         (SELECT count(DISTINCT projeto_id) FROM lakehouse_vertice.silver.tarefas) = 60 AS passou,
         CAST((SELECT count(DISTINCT projeto_id) FROM lakehouse_vertice.silver.tarefas) AS STRING) AS obtido

  UNION ALL
  SELECT 2, 'cada projeto veio de UMA ferramenta, a do cadastro do PMO',
         (SELECT count(*) FROM (
            SELECT t.projeto_id
            FROM lakehouse_vertice.silver.tarefas t
            JOIN lakehouse_vertice.silver.projetos p ON p.projeto_id = t.projeto_id
            GROUP BY t.projeto_id, p.ferramenta
            HAVING count(DISTINCT t.ferramenta) > 1 OR max(t.ferramenta) <> p.ferramenta)) = 0,
         'projetos com ferramenta divergente: ' || (SELECT count(*) FROM (
            SELECT t.projeto_id
            FROM lakehouse_vertice.silver.tarefas t
            JOIN lakehouse_vertice.silver.projetos p ON p.projeto_id = t.projeto_id
            GROUP BY t.projeto_id, p.ferramenta
            HAVING count(DISTINCT t.ferramenta) > 1 OR max(t.ferramenta) <> p.ferramenta))

  UNION ALL
  SELECT 3, 'as horas do Excel na silver = soma das linhas de TOTAL das planilhas',
         abs((SELECT sum(horas) FROM lakehouse_vertice.silver.tarefas WHERE ferramenta = 'excel')
           - (SELECT sum(try_cast(replace(horas_previstas, 'h', '') AS DOUBLE))
              FROM lakehouse_vertice.bronze.excel_tarefas WHERE tarefa = 'TOTAL')) < 1,
         'silver ' || (SELECT sum(horas) FROM lakehouse_vertice.silver.tarefas WHERE ferramenta = 'excel')
         || ' x TOTAL ' || (SELECT sum(try_cast(replace(horas_previstas, 'h', '') AS DOUBLE))
                            FROM lakehouse_vertice.bronze.excel_tarefas WHERE tarefa = 'TOTAL')

  UNION ALL
  SELECT 4, 'uma linha por pessoa na silver',
         (SELECT count(*) FROM lakehouse_vertice.silver.colaboradores)
           = (SELECT count(DISTINCT colaborador_id) FROM lakehouse_vertice.silver.colaboradores),
         (SELECT count(*) FROM lakehouse_vertice.silver.colaboradores) || ' linhas x '
         || (SELECT count(DISTINCT colaborador_id) FROM lakehouse_vertice.silver.colaboradores) || ' pessoas'

  UNION ALL
  SELECT 5, 'a CodeForge virou um fornecedor só',
         (SELECT count(DISTINCT fornecedor) FROM lakehouse_vertice.silver.entregas_fornecedor
          WHERE lower(fornecedor) LIKE '%codeforge%') = 1,
         (SELECT count(DISTINCT fornecedor) FROM lakehouse_vertice.silver.entregas_fornecedor
          WHERE lower(fornecedor) LIKE '%codeforge%') || ' grafias'

  UNION ALL
  SELECT 6, 'a limpeza não mudou o custo total (bronze com replace = silver)',
         abs((SELECT sum(CAST(replace(valor, ',', '.') AS DECIMAL(15, 2))) FROM lakehouse_vertice.bronze.custos)
           - (SELECT sum(valor) FROM lakehouse_vertice.silver.custos)) < 0.01,
         'bronze ' || (SELECT sum(CAST(replace(valor, ',', '.') AS DECIMAL(15, 2))) FROM lakehouse_vertice.bronze.custos)
         || ' x silver ' || (SELECT sum(valor) FROM lakehouse_vertice.silver.custos)

  UNION ALL
  SELECT 7, 'os 60 projetos têm fotografia de hoje',
         (SELECT count(*) FROM lakehouse_vertice.gold.projeto_situacao_atual) = 60,
         (SELECT count(*) FROM lakehouse_vertice.gold.projeto_situacao_atual) || ' linhas'

  UNION ALL
  SELECT 8, 'todo projeto em andamento tem SPI e CPI',
         (SELECT count(*) FROM lakehouse_vertice.gold.projeto_situacao_atual
          WHERE status = 'em_andamento' AND (spi IS NULL OR cpi IS NULL)) = 0,
         (SELECT count(*) FROM lakehouse_vertice.gold.projeto_situacao_atual
          WHERE status = 'em_andamento' AND (spi IS NULL OR cpi IS NULL)) || ' projetos sem KPI'

  UNION ALL
  SELECT 9, 'o EV de hoje do status semanal bate com o das ferramentas (diferença < 1%)',
         abs(1 - try_divide(
           (SELECT sum(f.ev) FROM lakehouse_vertice.gold.fato_projeto_semana f
            JOIN lakehouse_vertice.gold.projeto_situacao_atual s ON s.projeto_id = f.projeto_id
            WHERE f.semana = DATE'2026-10-16' AND s.status = 'em_andamento'),
           (SELECT sum(ev) FROM lakehouse_vertice.gold.projeto_situacao_atual WHERE status = 'em_andamento'))) < 0.01,
         'EV status ' || (SELECT sum(f.ev) FROM lakehouse_vertice.gold.fato_projeto_semana f
            JOIN lakehouse_vertice.gold.projeto_situacao_atual s ON s.projeto_id = f.projeto_id
            WHERE f.semana = DATE'2026-10-16' AND s.status = 'em_andamento')
         || ' x ferramentas ' || (SELECT sum(ev) FROM lakehouse_vertice.gold.projeto_situacao_atual WHERE status = 'em_andamento')

  UNION ALL
  SELECT 10, 'AC de hoje no fato = soma dos lançamentos até hoje',
         abs((SELECT sum(ac) FROM lakehouse_vertice.gold.fato_projeto_semana WHERE semana = DATE'2026-10-16')
           - (SELECT sum(valor) FROM lakehouse_vertice.silver.custos WHERE semana <= DATE'2026-10-16')) < 0.01,
         'fato ' || (SELECT sum(ac) FROM lakehouse_vertice.gold.fato_projeto_semana WHERE semana = DATE'2026-10-16')
         || ' x custos ' || (SELECT sum(valor) FROM lakehouse_vertice.silver.custos WHERE semana <= DATE'2026-10-16')
)
SELECT
  n AS teste,
  descricao,
  obtido,
  CASE
    WHEN passou THEN 'ok'
    ELSE raise_error(concat('Teste ', n, ' falhou: ', descricao, ' (', obtido, ')'))
  END AS resultado
FROM testes
ORDER BY n
