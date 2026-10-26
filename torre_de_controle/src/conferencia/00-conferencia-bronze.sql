-- Conferência da bronze: 9 tabelas contra a contagem esperada (seed 42).
-- bronze.feriados fica de fora: cresce a cada execução.
-- Se alguma divergir, raise_error() para o job e diz qual tabela e onde olhar.

WITH conferencia AS (
  SELECT 'projetos' AS tabela, 60 AS esperado, (SELECT count(*) FROM lakehouse_vertice.bronze.projetos) AS obtido
  UNION ALL SELECT 'status_semanal', 3911, (SELECT count(*) FROM lakehouse_vertice.bronze.status_semanal)
  UNION ALL SELECT 'excel_tarefas', 1663, (SELECT count(*) FROM lakehouse_vertice.bronze.excel_tarefas)
  UNION ALL SELECT 'clickup_tarefas', 2119, (SELECT count(*) FROM lakehouse_vertice.bronze.clickup_tarefas)
  UNION ALL SELECT 'msproject_tarefas', 1260, (SELECT count(*) FROM lakehouse_vertice.bronze.msproject_tarefas)
  UNION ALL SELECT 'colaboradores', 523, (SELECT count(*) FROM lakehouse_vertice.bronze.colaboradores)
  UNION ALL SELECT 'apontamentos', 30883, (SELECT count(*) FROM lakehouse_vertice.bronze.apontamentos)
  UNION ALL SELECT 'custos', 23640, (SELECT count(*) FROM lakehouse_vertice.bronze.custos)
  UNION ALL SELECT 'entregas_fornecedor', 640, (SELECT count(*) FROM lakehouse_vertice.bronze.entregas_fornecedor)
)
SELECT
  tabela,
  esperado,
  obtido,
  CASE
    WHEN esperado = obtido THEN 'ok'
    ELSE raise_error(concat('bronze.', tabela, ' divergente: esperado ', esperado, ', obtido ', obtido,
                            '. Olhe a saída da tarefa ingestao_data_lake.'))
  END AS resultado
FROM conferencia
ORDER BY tabela
