"""Gera resources/dashboard-portfolio.lvdash.json (dashboard AI/BI "Projeto Farol · Portfólio").

O JSON fica no Git, dentro do bundle: tem diff, revisão e rollback. Não edite o dashboard no
workspace; a mudança vem para este script, que gera o JSON de novo.

As queries da gold usam o nome de tabela PURO (FROM projeto_situacao_atual). Quem completa o
catálogo e o schema é o recurso do bundle (dataset_catalog e dataset_schema). A única exceção é a
silver.entregas_fornecedor, que vai com o nome completo.

Uso: python scripts/gerar_dashboard.py
"""
import json
from pathlib import Path

SAIDA = Path(__file__).resolve().parent.parent / "resources" / "dashboard-portfolio.lvdash.json"

# Cores da Jornada e semáforo de situação
AZUL, CIANO = "#0059DB", "#22C2F4"
CRITICO, ATENCAO, OK = "#FF5F46", "#F6C344", "#22C2F4"
MAPA_SITUACAO = [
    {"value": "crítico", "color": CRITICO},
    {"value": "atenção", "color": ATENCAO},
    {"value": "ok", "color": OK},
]

BRL = {"type": "number-currency", "currencyCode": "BRL", "abbreviation": "compact",
       "decimalPlaces": {"type": "max", "places": 1}}
RAZAO = {"type": "number", "decimalPlaces": {"type": "exact", "places": 2}}
INTEIRO = {"type": "number", "decimalPlaces": {"type": "exact", "places": 0}}
PERCENTUAL = {"type": "number-percent", "decimalPlaces": {"type": "max", "places": 0}}

# ------------------------------------------------------------------ datasets
# Uma lista de linhas por query; cada linha termina com espaço (as linhas são coladas sem separador).
DATASETS = [
    {
        "name": "ds_kpis", "displayName": "KPIs da carteira em andamento",
        "queryLines": [
            "SELECT CAST(SUM(valor_contrato) AS DOUBLE) AS carteira, ",
            "SUM(ev) / SUM(pv) AS spi, ",
            "SUM(ev) / SUM(ac) AS cpi, ",
            "CAST(SUM(estouro_previsto) AS DOUBLE) AS estouro_previsto, ",
            "COUNT_IF(situacao IN ('atenção', 'crítico')) AS projetos_em_risco, ",
            "COUNT_IF(situacao = 'crítico') AS criticos, ",
            "COUNT_IF(melancia) AS melancias ",
            "FROM projeto_situacao_atual ",
            "WHERE status = 'em_andamento'",
        ],
    },
    {
        "name": "ds_estouro", "displayName": "Estouro previsto por projeto",
        "queryLines": [
            "SELECT concat(projeto, ' · ', nome_projeto) AS projeto, CAST(estouro_previsto AS DOUBLE) AS estouro_previsto, situacao ",
            "FROM projeto_situacao_atual ",
            "WHERE status = 'em_andamento' AND estouro_previsto > 0 ",
            "ORDER BY estouro_previsto DESC",
        ],
    },
    {
        "name": "ds_dispersao", "displayName": "SPI x CPI por projeto",
        "queryLines": [
            "SELECT concat(projeto, ' · ', nome_projeto) AS projeto, spi, cpi, situacao ",
            "FROM projeto_situacao_atual ",
            "WHERE status = 'em_andamento'",
        ],
    },
    {
        "name": "ds_semanal", "displayName": "SPI e CPI semanais da carteira",
        "queryLines": [
            "SELECT semana, SUM(ev) / SUM(pv) AS spi, SUM(ev) / SUM(ac) AS cpi ",
            "FROM fato_projeto_semana ",
            "WHERE semana >= DATE'2025-03-07' ",
            "GROUP BY semana ",
            "ORDER BY semana",
        ],
    },
    {
        "name": "ds_projetos", "displayName": "Projetos em andamento",
        "queryLines": [
            "SELECT concat(projeto, ' · ', nome_projeto) AS projeto, cliente, gerente_projeto, ",
            "CAST(estouro_previsto AS DOUBLE) AS estouro_previsto, spi, cpi, situacao, ",
            "farol_do_gerente, farol_calculado, melancia ",
            "FROM projeto_situacao_atual ",
            "WHERE status = 'em_andamento' ",
            "ORDER BY spi",
        ],
    },
    {
        "name": "ds_parados", "displayName": "Top 15 pessoas por custo da hora parada",
        "queryLines": [
            "SELECT concat(colaborador_id, ' · ', nome) AS pessoa, ",
            "CAST(SUM(custo_ocioso) AS DOUBLE) AS custo_parado ",
            "FROM utilizacao_pessoa_semana ",
            "WHERE semana > DATE'2026-07-24' ",
            "GROUP BY colaborador_id, nome ",
            "ORDER BY custo_parado DESC ",
            "LIMIT 15",
        ],
    },
    {
        "name": "ds_utilizacao", "displayName": "Utilização por pessoa e projeto",
        "queryLines": [
            "SELECT concat(colaborador_id, ' · ', nome) AS pessoa, papel, projeto_id, ",
            "SUM(horas_disponiveis) AS horas_disponiveis, SUM(horas_apontadas) AS horas_apontadas, ",
            "SUM(horas_apontadas) / SUM(horas_disponiveis) AS utilizacao, ",
            "CAST(SUM(custo_ocioso) AS DOUBLE) AS custo_ocioso ",
            "FROM utilizacao_pessoa_semana ",
            "WHERE semana > DATE'2026-07-24' ",
            "GROUP BY colaborador_id, nome, papel, projeto_id ",
            "ORDER BY utilizacao",
        ],
    },
    {
        "name": "ds_causas", "displayName": "Causas de bloqueio por projeto",
        "queryLines": [
            "SELECT projeto_id, causa_bloqueio, COUNT(*) AS status ",
            "FROM status_estruturado ",
            "WHERE data_status >= DATE'2026-07-18' ",
            "AND causa_bloqueio NOT IN ('sem_bloqueio', 'nao_reportado') ",
            "GROUP BY projeto_id, causa_bloqueio ",
            "ORDER BY projeto_id",
        ],
    },
    {
        "name": "ds_fornecedores", "displayName": "Fornecedores",
        "queryLines": [
            "SELECT fornecedor, ",
            "COUNT(DISTINCT fornecedor_como_veio) AS grafias_no_cadastro, ",
            "COUNT(*) AS entregas, ",
            "SUM(prazo_real_dias) / SUM(CASE WHEN data_entrega IS NOT NULL THEN prazo_prometido_dias END) AS prazo_real_sobre_prometido, ",
            "COUNT_IF(data_entrega IS NOT NULL AND dias_de_atraso_na_entrega <= 0) / COUNT(data_entrega) AS pct_no_prazo, ",
            "COUNT_IF(em_atraso) AS em_atraso_hoje ",
            "FROM lakehouse_vertice.silver.entregas_fornecedor ",
            "GROUP BY fornecedor ",
            "ORDER BY em_atraso_hoje DESC, fornecedor",
        ],
    },
    {
        "name": "ds_atrasos", "displayName": "Entregas em atraso hoje",
        "queryLines": [
            "SELECT fornecedor, projeto_id, item, data_prometida, ",
            "datediff(DATE'2026-10-16', data_prometida) AS dias_em_atraso, ",
            "CAST(valor AS DOUBLE) AS valor ",
            "FROM lakehouse_vertice.silver.entregas_fornecedor ",
            "WHERE em_atraso ",
            "ORDER BY dias_em_atraso DESC",
        ],
    },
]


# ------------------------------------------------------------------ helpers de widget
def campo(nome, expr=None):
    """Campo de query: o nome TEM que ser igual ao fieldName do encoding."""
    return {"name": nome, "expression": expr or f"`{nome}`"}


def posicao(x, y, w, h):
    return {"x": x, "y": y, "width": w, "height": h}


def item(widget, x, y, w, h):
    return {"widget": widget, "position": posicao(x, y, w, h)}


def texto(nome, titulo, pergunta, x, y, w=12, h=2):
    return item({"name": nome, "multilineTextboxSpec": {"lines": [f"## {titulo}\n", "\n", pergunta]}}, x, y, w, h)


def consulta(dataset, campos, desagregado=True):
    return [{"name": "main_query", "query": {"datasetName": dataset, "fields": campos, "disaggregated": desagregado}}]


def contador(nome, titulo, dataset, campo_nome, formato, x, y, w=3, h=3):
    return item({
        "name": nome,
        "queries": consulta(dataset, [campo(campo_nome)]),
        "spec": {
            "version": 2, "widgetType": "counter",
            "encodings": {"value": {"fieldName": campo_nome, "displayName": titulo, "format": formato}},
            "frame": {"title": titulo, "showTitle": True},
        },
    }, x, y, w, h)


def contador_inteiro(nome, titulo, dataset, campo_nome, x, y, w=3, h=3):
    return contador(nome, titulo, dataset, campo_nome, INTEIRO, x, y, w, h)


def tabela(nome, titulo, dataset, colunas, x, y, w, h):
    """colunas: lista de (campo, titulo, format|None, regras|None)."""
    cols = []
    for fn, dn, fmt, regras in colunas:
        c = {"fieldName": fn, "displayName": dn}
        if fmt:
            c["format"] = fmt
        if regras:
            c["style"] = {"type": "basic", "rules": regras}
        cols.append(c)
    return item({
        "name": nome,
        "queries": consulta(dataset, [campo(c[0]) for c in colunas]),
        "spec": {"version": 2, "widgetType": "table", "encodings": {"columns": cols},
                 "frame": {"title": titulo, "showTitle": True}},
    }, x, y, w, h)


def regras_indice(limite_critico="0.8", limite_atencao="0.9"):
    """Pinta o SPI/CPI: abaixo de 0,8 crítico, abaixo de 0,9 atenção."""
    return [
        {"condition": {"operand": {"type": "data-value", "value": limite_critico}, "operator": "<"},
         "backgroundColor": {"hex": CRITICO}},
        {"condition": {"operand": {"type": "data-value", "value": limite_atencao}, "operator": "<"},
         "backgroundColor": {"hex": ATENCAO}},
    ]


# ------------------------------------------------------------------ páginas
def pagina_portfolio():
    L = [texto("titulo-portfolio", "Portfólio",
               "Quais projetos estão atrasados, de quais clientes, e quanto esse atraso vai me custar? "
               "(carteira em andamento, fotografia de 16/10/2026)", 0, 0)]
    # 7 KPIs: 4 + 3
    L += [
        contador("kpi-carteira", "Carteira em andamento", "ds_kpis", "carteira", BRL, 0, 2),
        contador("kpi-spi", "SPI da carteira", "ds_kpis", "spi", RAZAO, 3, 2),
        contador("kpi-cpi", "CPI da carteira", "ds_kpis", "cpi", RAZAO, 6, 2),
        contador("kpi-estouro", "Estouro previsto", "ds_kpis", "estouro_previsto", BRL, 9, 2),
        contador_inteiro("kpi-risco", "Projetos em risco", "ds_kpis", "projetos_em_risco", 0, 5, 4),
        contador_inteiro("kpi-criticos", "Projetos críticos", "ds_kpis", "criticos", 4, 5, 4),
        contador_inteiro("kpi-melancias", "Melancias", "ds_kpis", "melancias", 8, 5, 4),
    ]
    L.append(item({
        "name": "barra-estouro",
        "queries": consulta("ds_estouro", [campo("projeto"), campo("estouro_previsto"), campo("situacao")]),
        "spec": {
            "version": 3, "widgetType": "bar",
            "encodings": {
                "x": {"fieldName": "estouro_previsto", "displayName": "Estouro previsto (R$)",
                      "scale": {"type": "quantitative"}, "format": BRL},
                "y": {"fieldName": "projeto", "displayName": "Projeto", "scale": {"type": "categorical"}},
                "color": {"fieldName": "situacao", "displayName": "Situação",
                          "scale": {"type": "categorical", "mappings": MAPA_SITUACAO}},
            },
            "frame": {"title": "Estouro previsto por projeto", "showTitle": True},
        },
    }, 0, 8, 6, 8))
    L.append(item({
        "name": "dispersao-spi-cpi",
        "queries": consulta("ds_dispersao", [campo("projeto"), campo("spi"), campo("cpi"), campo("situacao")]),
        "spec": {
            "version": 3, "widgetType": "scatter",
            "encodings": {
                "x": {"fieldName": "spi", "displayName": "SPI", "scale": {"type": "quantitative"}},
                "y": {"fieldName": "cpi", "displayName": "CPI", "scale": {"type": "quantitative"}},
                "color": {"fieldName": "situacao", "displayName": "Situação",
                          "scale": {"type": "categorical", "mappings": MAPA_SITUACAO}},
            },
            "frame": {"title": "SPI × CPI, um ponto por projeto", "showTitle": True},
        },
    }, 6, 8, 6, 8))
    L.append(item({
        "name": "linha-spi-cpi",
        "queries": consulta("ds_semanal", [campo("semana"), campo("spi"), campo("cpi")]),
        "spec": {
            "version": 3, "widgetType": "line",
            "encodings": {
                "x": {"fieldName": "semana", "displayName": "Semana", "scale": {"type": "temporal"}},
                "y": {"scale": {"type": "quantitative"},
                      "fields": [{"fieldName": "spi", "displayName": "SPI"},
                                 {"fieldName": "cpi", "displayName": "CPI"}]},
            },
            "annotations": [{
                "type": "horizontal-line",
                "encodings": {"y": {"dataValue": "0.9", "dataType": "DOUBLE"},
                              "label": {"value": "Atenção (0,9)"}, "color": {"value": ATENCAO}},
            }],
            "frame": {"title": "SPI e CPI semanais da carteira", "showTitle": True},
        },
    }, 0, 16, 12, 6))
    L.append(tabela("tabela-projetos", "Projetos em andamento: o farol do gerente ao lado do farol pelo número",
                    "ds_projetos", [
                        ("projeto", "Projeto", None, None),
                        ("cliente", "Cliente", None, None),
                        ("gerente_projeto", "Gerente", None, None),
                        ("estouro_previsto", "Estouro previsto", BRL, None),
                        ("spi", "SPI", RAZAO, regras_indice()),
                        ("cpi", "CPI", RAZAO, regras_indice()),
                        ("situacao", "Situação", None, None),
                        ("farol_do_gerente", "Farol do gerente", None, None),
                        ("farol_calculado", "Farol pelo número", None, None),
                        ("melancia", "Melancia", None, None),
                    ], 0, 22, 12, 9))
    return {"name": "portfolio", "displayName": "Portfólio", "layout": L,
            "pageType": "PAGE_TYPE_CANVAS", "layoutVersion": "GRID_V1"}


def pagina_pessoas():
    L = [texto("titulo-pessoas", "Pessoas",
               "Tenho gente parada enquanto outro projeto pede gente? "
               "(últimas 12 semanas, a partir de 24/07/2026)", 0, 0)]
    L.append(item({
        "name": "barra-parados",
        "queries": consulta("ds_parados", [campo("pessoa"), campo("custo_parado")]),
        "spec": {
            "version": 3, "widgetType": "bar",
            "encodings": {
                "x": {"fieldName": "custo_parado", "displayName": "Custo da hora parada (R$)",
                      "scale": {"type": "quantitative"}, "format": BRL},
                "y": {"fieldName": "pessoa", "displayName": "Pessoa", "scale": {"type": "categorical"}},
            },
            "frame": {"title": "Top 15 pessoas por custo da hora parada", "showTitle": True},
        },
    }, 0, 2, 6, 9))
    L.append(tabela("tabela-utilizacao", "Utilização por pessoa e projeto, da mais parada à mais ocupada",
                    "ds_utilizacao", [
                        ("pessoa", "Pessoa", None, None),
                        ("papel", "Papel", None, None),
                        ("projeto_id", "Projeto", None, None),
                        ("horas_disponiveis", "Horas disponíveis", INTEIRO, None),
                        ("horas_apontadas", "Horas apontadas", INTEIRO, None),
                        ("utilizacao", "Utilização", PERCENTUAL, None),
                        ("custo_ocioso", "Custo ocioso", BRL, None),
                    ], 6, 2, 6, 9))
    L.append(item({
        "name": "barra-causas",
        "queries": consulta("ds_causas", [campo("projeto_id"), campo("causa_bloqueio"), campo("status")]),
        "spec": {
            "version": 3, "widgetType": "bar",
            "encodings": {
                "x": {"fieldName": "projeto_id", "displayName": "Projeto", "scale": {"type": "categorical"}},
                "y": {"fieldName": "status", "displayName": "Status com bloqueio", "scale": {"type": "quantitative"}},
                "color": {"fieldName": "causa_bloqueio", "displayName": "Causa do bloqueio",
                          "scale": {"type": "categorical"}},
            },
            "frame": {"title": "Causas de bloqueio por projeto (últimos 90 dias)", "showTitle": True},
        },
    }, 0, 11, 12, 8))
    return {"name": "pessoas", "displayName": "Pessoas", "layout": L,
            "pageType": "PAGE_TYPE_CANVAS", "layoutVersion": "GRID_V1"}


def pagina_fornecedores():
    L = [texto("titulo-fornecedores", "Fornecedores",
               "O que vai dar errado no próximo mês? Quem entrega no prazo, e quem está atrasado hoje (16/10/2026)?",
               0, 0)]
    L.append(tabela("tabela-fornecedores", "Fornecedores: prazo real ÷ prometido e entregas no prazo",
                    "ds_fornecedores", [
                        ("fornecedor", "Fornecedor", None, None),
                        ("grafias_no_cadastro", "Grafias no cadastro", INTEIRO, None),
                        ("entregas", "Entregas", INTEIRO, None),
                        ("prazo_real_sobre_prometido", "Prazo real ÷ prometido", RAZAO,
                         [{"condition": {"operand": {"type": "data-value", "value": "1.2"}, "operator": ">"},
                           "backgroundColor": {"hex": CRITICO}}]),
                        ("pct_no_prazo", "% no prazo", PERCENTUAL, None),
                        ("em_atraso_hoje", "Em atraso hoje", INTEIRO, None),
                    ], 0, 2, 12, 6))
    L.append(tabela("tabela-atrasos", "Entregas em atraso hoje", "ds_atrasos", [
        ("fornecedor", "Fornecedor", None, None),
        ("projeto_id", "Projeto", None, None),
        ("item", "Item", None, None),
        ("data_prometida", "Data prometida", None, None),
        ("dias_em_atraso", "Dias em atraso", INTEIRO, None),
        ("valor", "Valor", BRL, None),
    ], 0, 8, 12, 7))
    return {"name": "fornecedores", "displayName": "Fornecedores", "layout": L,
            "pageType": "PAGE_TYPE_CANVAS", "layoutVersion": "GRID_V1"}


# ------------------------------------------------------------------ tema (Jornada: azul, ciano, fundo escuro)
TEMA = {
    "canvasBackgroundColor": {"light": "#F4F6FA", "dark": "#14141A"},
    "widgetBackgroundColor": {"light": "#FFFFFF", "dark": "#1E1E27"},
    "widgetBorderColor": {"light": "#FFFFFF", "dark": "#1E1E27"},
    "fontColor": {"light": "#14141A", "dark": "#F2F4F8"},
    "selectionColor": {"light": AZUL, "dark": CIANO},
    "visualizationColors": [AZUL, CIANO, "#7B61FF", "#F6C344", "#FF5F46", "#2DD4A8", "#C77DFF"],
    "widgetHeaderAlignment": "LEFT",
}


def main():
    dashboard = {
        "datasets": DATASETS,
        "pages": [pagina_portfolio(), pagina_pessoas(), pagina_fornecedores()],
        "uiSettings": {"theme": TEMA},
    }
    SAIDA.write_text(json.dumps(dashboard, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    n = sum(len(p["layout"]) for p in dashboard["pages"])
    print(f"{SAIDA.name}: {len(DATASETS)} datasets, {len(dashboard['pages'])} páginas, {n} widgets")


if __name__ == "__main__":
    main()
