-- Metric view: a fórmula de cada KPI num lugar só. O Genie, o app e o dashboard leem daqui.
-- ATENÇÃO: nada de ponto e vírgula dentro do YAML (nem em comentário): a sql_task corta o arquivo em todo um.

CREATE OR REPLACE VIEW lakehouse_vertice.gold.mv_projetos
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "KPIs da carteira de projetos em andamento (fotografia de 16/10/2026). Razões são sempre soma sobre soma: nunca a média dos índices dos projetos."
source: lakehouse_vertice.gold.projeto_situacao_atual
filter: status = 'em_andamento'

dimensions:
  - name: projeto_id
    expr: projeto_id
    comment: "Código do projeto, no formato PRJ-000"
    synonyms: ["código do projeto", "id do projeto"]
  - name: projeto
    expr: projeto
    comment: "Código do projeto, igual a projeto_id (o nome está em nome_projeto na projeto_situacao_atual)"
    synonyms: ["código", "projeto"]
  - name: cliente
    expr: cliente
    comment: "Cliente dono do contrato"
    synonyms: ["conta", "empresa cliente"]
  - name: segmento
    expr: segmento
    comment: "Segmento do cliente: varejo, financeiro, saúde, logística ou indústria"
    synonyms: ["setor", "vertical"]
  - name: ferramenta
    expr: ferramenta
    comment: "Ferramenta em que o gerente controla o projeto: excel, clickup ou msproject"
    synonyms: ["ferramenta de gestão", "sistema de gestão"]
  - name: situacao
    expr: situacao
    comment: "Situação pelo número: crítico (SPI ou CPI abaixo de 0,8), atenção (abaixo de 0,9) ou ok"
    synonyms: ["status do projeto", "risco"]
  - name: farol_do_gerente
    expr: farol_do_gerente
    comment: "Farol que o gerente publicou no último status: verde, amarelo ou vermelho"
    synonyms: ["farol informado", "farol declarado"]
  - name: farol_calculado
    expr: farol_calculado
    comment: "Farol pela regra do manual da Vértice: verde com SPI a partir de 0,95, amarelo a partir de 0,90, vermelho abaixo"
    synonyms: ["farol pelo número", "farol real"]
  - name: gerente_projeto
    expr: gerente_projeto
    comment: "Gerente responsável pelo projeto"
    synonyms: ["gerente", "responsável", "PM"]

measures:
  - name: projetos
    expr: COUNT(*)
    comment: "Quantidade de projetos em andamento"
    synonyms: ["quantidade de projetos", "número de projetos"]
  - name: carteira
    expr: SUM(valor_contrato)
    comment: "Valor total dos contratos em reais"
    synonyms: ["valor da carteira", "valor dos contratos", "receita contratada"]
  - name: spi
    expr: SUM(ev) / SUM(pv)
    comment: "Índice de desempenho de prazo: valor agregado dividido pelo valor planejado. Abaixo de 1 é atraso, abaixo de 0,9 é atenção, abaixo de 0,8 é crítico"
    synonyms: ["desempenho de prazo", "schedule performance index"]
  - name: cpi
    expr: SUM(ev) / SUM(ac)
    comment: "Índice de desempenho de custo: valor agregado dividido pelo custo real. Abaixo de 1 é estouro"
    synonyms: ["desempenho de custo", "cost performance index"]
  - name: eac
    expr: SUM(eac)
    comment: "Estimativa no término: orçamento dividido pelo CPI, em reais"
    synonyms: ["custo estimado no término", "previsão de custo final"]
  - name: estouro_previsto
    expr: SUM(estouro_previsto)
    comment: "Quanto o custo deve passar do orçamento, em reais. Só soma projetos com EAC maior que o orçamento"
    synonyms: ["estouro de custo", "quanto vai custar o atraso", "overrun"]
  - name: margem_projetada
    expr: (SUM(valor_contrato) - SUM(eac)) / SUM(valor_contrato)
    comment: "Margem projetada: valor do contrato menos EAC, dividido pelo valor do contrato"
    synonyms: ["margem prevista", "margem final"]
  - name: atraso_projetado_medio_dias
    expr: AVG(atraso_projetado_dias)
    comment: "Média, entre os projetos, do atraso projetado em dias (duração do baseline dividida pelo SPI, menos a duração)"
    synonyms: ["atraso médio", "dias de atraso médio"]
  - name: projetos_em_risco
    expr: COUNT(*) FILTER (WHERE situacao IN ('atenção', 'crítico'))
    comment: "Projetos em situação de atenção ou crítica"
    synonyms: ["projetos em atenção ou críticos", "projetos com risco"]
  - name: projetos_criticos
    expr: COUNT(*) FILTER (WHERE situacao = 'crítico')
    comment: "Projetos com SPI ou CPI abaixo de 0,8"
    synonyms: ["críticos"]
  - name: projetos_melancia
    expr: COUNT(*) FILTER (WHERE melancia)
    comment: "Melancias: o gerente publica farol verde, mas o SPI está abaixo de 0,9 (verde por fora, vermelho por dentro)"
    synonyms: ["melancias", "farol verde com atraso"]
$$
