-- silver.status_semanal e silver.custos

CREATE OR REFRESH MATERIALIZED VIEW status_semanal (
  CONSTRAINT farol_valido EXPECT (farol IN ('verde', 'amarelo', 'vermelho')) ON VIOLATION FAIL UPDATE
)
COMMENT 'Status semanal de cada projeto (toda sexta): % concluído e farol informados pelo gerente, mais o texto livre. status_vazio marca os textos sem informação ("", N/A, "ver ata da reunião"); a linha não é descartada.'
AS
SELECT
  projeto_id,
  coalesce(try_to_date(data_status, 'yyyy-MM-dd'), try_to_date(data_status, 'dd/MM/yyyy')) AS data_status,
  gerente,
  lower(trim(farol)) AS farol,
  CAST(CAST(pct_concluido AS DOUBLE) AS INT) AS pct_concluido,
  texto_status,
  coalesce(trim(texto_status) IN ('', 'N/A', 'ver ata da reunião'), true) AS status_vazio
FROM lakehouse_vertice.bronze.status_semanal;

CREATE OR REFRESH MATERIALIZED VIEW custos
COMMENT 'Lançamentos de custo real por projeto (pessoal, consultoria, cloud, licenças, despesas). O valor é líquido: estornos (negativos) ficam e são sinalizados em estorno. semana é a sexta-feira da semana do lançamento.'
AS
SELECT
  lancamento_id,
  projeto_id,
  data,
  -- sexta-feira da semana (a segunda + 4)
  date_add(CAST(date_trunc('WEEK', data) AS DATE), 4) AS semana,
  categoria,
  descricao,
  valor,
  valor < 0 AS estorno,
  centro_custo
FROM (
  SELECT
    lancamento_id,
    projeto_id,
    coalesce(try_to_date(data, 'yyyy-MM-dd'), try_to_date(data, 'dd/MM/yyyy')) AS data,
    categoria,
    descricao,
    -- vírgula decimal ('12345,67'): troca ANTES do CAST. Nunca try_cast: jogaria valor fora em silêncio
    CAST(replace(valor, ',', '.') AS DECIMAL(15, 2)) AS valor,
    centro_custo
  FROM lakehouse_vertice.bronze.custos
);
