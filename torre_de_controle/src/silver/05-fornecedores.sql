-- silver.entregas_fornecedor

CREATE OR REFRESH MATERIALIZED VIEW entregas_fornecedor
COMMENT 'Entregas das consultorias e fornecedores: prometido x entregue. A CodeForge (escrita de 4 jeitos) está normalizada. data_entrega vazia significa entrega em aberto (em_aberto), não é sujeira; em_atraso marca as em aberto com prazo prometido antes de 16/10/2026.'
AS
WITH base AS (
  SELECT
    entrega_id,
    projeto_id,
    -- 4 grafias da CodeForge viram uma
    CASE WHEN replace(lower(fornecedor), ' ', '') LIKE '%codeforge%' THEN 'CodeForge Consultoria Ltda'
         ELSE fornecedor END AS fornecedor,
    fornecedor AS fornecedor_como_veio,
    item,
    CAST(valor AS DECIMAL(15, 2)) AS valor,
    try_to_date(data_pedido, 'yyyy-MM-dd') AS data_pedido,
    try_to_date(data_prometida, 'yyyy-MM-dd') AS data_prometida,
    -- vazio = ainda não entregue
    try_to_date(nullif(trim(data_entrega), ''), 'yyyy-MM-dd') AS data_entrega,
    CAST(prazo_contratado_dias AS INT) AS prazo_contratado_dias,
    status
  FROM lakehouse_vertice.bronze.entregas_fornecedor
)
SELECT
  *,
  datediff(data_prometida, data_pedido) AS prazo_prometido_dias,
  datediff(data_entrega, data_pedido) AS prazo_real_dias,
  datediff(data_entrega, data_prometida) AS dias_de_atraso_na_entrega,
  data_entrega IS NULL AS em_aberto,
  data_entrega IS NULL AND data_prometida < DATE'2026-10-16' AS em_atraso
FROM base;
