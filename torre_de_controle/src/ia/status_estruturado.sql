-- gold.status_estruturado: o texto livre do status semanal vira coluna.
-- A tabela ACUMULA: cada status é classificado uma vez só (a IA custa ~5 s por texto).
-- Por isso é CREATE IF NOT EXISTS + MERGE, nunca CREATE OR REPLACE.

CREATE TABLE IF NOT EXISTS lakehouse_vertice.gold.status_estruturado (
  projeto_id STRING COMMENT 'Projeto do status (PRJ-xxx)',
  data_status DATE COMMENT 'Sexta-feira do status semanal',
  farol STRING COMMENT 'Farol informado pelo gerente: verde, amarelo ou vermelho',
  causa_bloqueio STRING COMMENT 'Causa do bloqueio: change_freeze, falta_sre, dependencia_fornecedor, rotatividade, mudanca_escopo, bug_retrabalho, aprovacao_cliente, sem_bloqueio ou nao_reportado',
  bloqueio STRING COMMENT 'Descrição do bloqueio extraída do texto (só nos status classificados pela IA)',
  quem_destrava STRING COMMENT 'Quem pode destravar o bloqueio, quando o texto diz (só na IA)',
  dias_impacto DOUBLE COMMENT 'Dias de impacto declarados no texto (1 semana = 7)',
  metodo STRING COMMENT 'Como o status foi estruturado: regra, ia (últimos 90 dias) ou palavra_chave (histórico)',
  texto_status STRING COMMENT 'Texto livre original do status semanal',
  _classificado_em TIMESTAMP COMMENT 'Quando a linha foi classificada'
)
COMMENT 'Status semanal estruturado: causa do bloqueio, quem destrava e dias de impacto extraídos do texto livre. Regra para status sem bloqueio, IA (ai_classify e ai_extract) nos últimos 90 dias e palavra-chave no histórico. Acumula entre execuções.';

MERGE INTO lakehouse_vertice.gold.status_estruturado AS destino
USING (
  WITH novos AS (
    -- só os status que ainda não estão na tabela
    SELECT s.*
    FROM lakehouse_vertice.silver.status_semanal s
    LEFT ANTI JOIN lakehouse_vertice.gold.status_estruturado e
      ON e.projeto_id = s.projeto_id AND e.data_status = s.data_status
  ),
  com_metodo AS (
    SELECT
      *,
      lower(coalesce(texto_status, '')) AS texto_min,
      CASE
        WHEN status_vazio
          OR lower(coalesce(texto_status, '')) RLIKE 'bloqueios: nenhum|sem bloqueios|nada relevante' THEN 'regra'
        WHEN data_status >= DATE'2026-07-18' THEN 'ia'
        ELSE 'palavra_chave'
      END AS metodo
    FROM novos
  ),
  com_ia AS (
    SELECT
      *,
      -- a IA só roda nas linhas com metodo = ia
      CASE WHEN metodo = 'ia' THEN
        ai_classify(texto_status,
          '["change_freeze","falta_sre","dependencia_fornecedor","rotatividade","mudanca_escopo","bug_retrabalho","aprovacao_cliente","sem_bloqueio"]',
          map('version', '2.0')):response[0]::STRING
      END AS causa_ia,
      CASE WHEN metodo = 'ia' THEN
        ai_extract(texto_status,
          '{"bloqueio":{"type":"string"},"quem_destrava":{"type":"string"},"dias_impacto":{"type":"number","description":"dias de impacto declarados, 1 semana = 7"}}',
          map('version', '2.0')):response
      END AS extraido
    FROM com_metodo
  )
  SELECT
    projeto_id,
    data_status,
    farol,
    CASE
      WHEN status_vazio THEN 'nao_reportado'
      WHEN metodo = 'regra' THEN 'sem_bloqueio'
      WHEN metodo = 'ia' THEN causa_ia
      WHEN texto_min RLIKE 'freeze|congelamento|janela de deploy' THEN 'change_freeze'
      WHEN texto_min RLIKE 'sre|infraestrutura|ambiente de homologação' THEN 'falta_sre'
      WHEN texto_min RLIKE 'forge|consultoria|fornecedor' THEN 'dependencia_fornecedor'
      WHEN texto_min RLIKE 'saída de|rotatividade|onboarding' THEN 'rotatividade'
      WHEN texto_min RLIKE 'escopo|change request|regra de negócio' THEN 'mudanca_escopo'
      WHEN texto_min RLIKE 'bugs|regressão|refazendo' THEN 'bug_retrabalho'
      WHEN texto_min RLIKE 'aprovação do cliente|homologação do cliente' THEN 'aprovacao_cliente'
      ELSE 'sem_bloqueio'
    END AS causa_bloqueio,
    extraido:bloqueio::STRING AS bloqueio,
    extraido:quem_destrava::STRING AS quem_destrava,
    CASE
      WHEN metodo = 'ia' THEN extraido:dias_impacto::DOUBLE
      WHEN texto_min RLIKE 'impacto estimado de [0-9]+ dias' THEN CAST(regexp_extract(texto_min, 'impacto estimado de ([0-9]+) dias', 1) AS DOUBLE)
      WHEN texto_min RLIKE 'impacto estimado: 1 semana' THEN 7.0
    END AS dias_impacto,
    metodo,
    texto_status,
    current_timestamp() AS _classificado_em
  FROM com_ia
) AS origem
ON destino.projeto_id = origem.projeto_id AND destino.data_status = origem.data_status
WHEN NOT MATCHED THEN INSERT *;

-- Leitura: quantos status por método e causa
SELECT metodo, causa_bloqueio, count(*) AS status
FROM lakehouse_vertice.gold.status_estruturado
GROUP BY metodo, causa_bloqueio
ORDER BY metodo, status DESC
