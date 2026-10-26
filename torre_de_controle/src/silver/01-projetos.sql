-- silver.projetos: o cadastro do PMO. É o de-para da integração das três ferramentas.
-- Limpezas: data em dois formatos, ferramenta escrita de 8 jeitos, código vazio, valores em número.

CREATE OR REFRESH MATERIALIZED VIEW projetos (
  CONSTRAINT data_inicio_valida EXPECT (data_inicio IS NOT NULL) ON VIOLATION FAIL UPDATE,
  CONSTRAINT ferramenta_conhecida EXPECT (ferramenta IN ('excel', 'clickup', 'msproject')) ON VIOLATION FAIL UPDATE
)
COMMENT 'Cadastro dos 60 projetos do PMO (cliente, segmento, contrato, orçamento, prazo, gerente). Traz a ferramenta de controle e o código do projeto nela: é o de-para que liga as tarefas de Excel, ClickUp e MS Project ao projeto_id.'
AS
SELECT
  projeto_id,
  nome_projeto,
  cliente,
  segmento,
  tipo_projeto,
  -- 8 grafias viram 3 valores
  CASE
    WHEN lower(ferramenta) LIKE '%click%' THEN 'clickup'
    WHEN lower(ferramenta) LIKE '%excel%' OR lower(ferramenta) LIKE '%planilha%' THEN 'excel'
    WHEN lower(ferramenta) LIKE '%project%' OR lower(replace(ferramenta, ' ', '')) LIKE 'ms%' THEN 'msproject'
  END AS ferramenta,
  ferramenta AS ferramenta_como_veio,
  nullif(trim(codigo_ferramenta), '') AS codigo_ferramenta,
  CAST(valor_contrato AS DECIMAL(15, 2)) AS valor_contrato,
  CAST(orcamento_custo AS DECIMAL(15, 2)) AS orcamento_custo,
  coalesce(try_to_date(data_inicio, 'yyyy-MM-dd'), try_to_date(data_inicio, 'dd/MM/yyyy')) AS data_inicio,
  coalesce(try_to_date(data_fim_baseline, 'yyyy-MM-dd'), try_to_date(data_fim_baseline, 'dd/MM/yyyy')) AS data_fim_baseline,
  status,
  gerente_projeto
FROM lakehouse_vertice.bronze.projetos;
