"""Gera resources/farol.geniespace.json: o Genie "Farol · Diretoria" como código.

O espaço (tabelas, instruções, exemplos) fica no Git, dentro do bundle: tem diff, revisão e
rollback. Não edite o Genie no workspace: o próximo `bundle deploy` recusa ("modified remotely").
A mudança vem para este script, que gera o JSON.

A tabela do modelo (gold.score_estouro_30d) entra SÓ se existir: sem ela, nada de instrução nem
exemplo sobre score, para o Genie não prometer o que não tem.

Uso: python scripts/gerar_genie.py [--profile PERFIL]
"""
import argparse
import json
import subprocess
from pathlib import Path

SAIDA = Path(__file__).resolve().parent.parent / "resources" / "farol.geniespace.json"
CAT = "lakehouse_vertice"
SCORE = f"{CAT}.gold.score_estouro_30d"


def score_existe(perfil: str) -> bool:
    r = subprocess.run(["databricks", "tables", "exists", SCORE, "--profile", perfil],
                       capture_output=True, text=True, encoding="utf-8")
    try:
        return bool(json.loads(r.stdout).get("table_exists"))
    except (json.JSONDecodeError, AttributeError):
        return False


def id32(grupo: int, n: int) -> str:
    """Id de 32 caracteres hex, único e em ordem: o grupo (1 a 4) vem primeiro, depois o número."""
    return f"{grupo:x}{n:031x}"


def col(nome: str, **kw) -> dict:
    return {"column_name": nome, **kw}


def montar(com_score: bool) -> dict:
    # ------------------------------------------------------------------ perguntas de exemplo
    perguntas = [
        "Quais projetos estão atrasados, e de quais clientes?",
        "Quanto esse atraso vai me custar?",
        "Tenho gente parada enquanto outro projeto pede gente?",
        "O que vai dar errado no próximo mês?",
    ]
    if com_score:
        perguntas.append("Qual a chance de o PRJ-024 estourar o orçamento?")

    # ------------------------------------------------------------------ tabelas
    tabelas = [
        {"identifier": f"{CAT}.gold.fato_projeto_semana"},
        {"identifier": f"{CAT}.gold.projeto_situacao_atual", "column_configs": [
            col("cliente", enable_entity_matching=True),
            col("farol_calculado", enable_format_assistance=True),
            col("farol_do_gerente", enable_format_assistance=True),
            col("ferramenta", enable_format_assistance=True),
            col("projeto_id", enable_entity_matching=True),
            col("situacao", enable_format_assistance=True),
        ]},
        {"identifier": f"{CAT}.gold.status_estruturado", "column_configs": [
            col("causa_bloqueio", enable_format_assistance=True),
        ]},
        {"identifier": f"{CAT}.gold.utilizacao_pessoa_semana", "column_configs": [
            col("papel", enable_format_assistance=True),
        ]},
        {"identifier": f"{CAT}.silver.entregas_fornecedor", "column_configs": [
            col("fornecedor", enable_entity_matching=True, enable_format_assistance=True),
        ]},
    ]
    if com_score:
        tabelas.append({"identifier": SCORE})
    tabelas.sort(key=lambda t: t["identifier"])

    # ------------------------------------------------------------------ instruções de texto
    texto = [
        "QUEM PERGUNTA: o dono e a diretoria da Vértice Tecnologia, que não escrevem SQL. Responda em português, com R$ e índices com 2 casas.",
        "HOJE é 2026-10-16 (sexta). Nunca use current_date(). 'Últimos 90 dias' = data_status >= DATE'2026-07-18'. 'Últimas 12 semanas' = semana > DATE'2026-07-24'. 'Próximo mês' = de 2026-10-17 a 2026-11-16.",
        "FÓRMULAS: SPI = EV / PV (menor que 1 é atraso). CPI = EV / AC (menor que 1 é estouro). EAC = orçamento / CPI. Estouro previsto = EAC menos orçamento, só quando positivo. Margem projetada = (valor do contrato - EAC) / valor do contrato. Atraso projetado (dias) = duração do baseline / SPI - duração do baseline. Razão nunca é média: a razão da carteira é SUM(ev) / SUM(pv), nunca a média dos SPIs.",
        "REGRAS DE CORTE: SPI ou CPI < 0,9 = atenção. SPI ou CPI < 0,8 = crítico. Projetos 'em risco' = atenção + crítico. Farol calculado (regra do manual): verde com SPI >= 0,95, amarelo >= 0,90, vermelho abaixo.",
        "ONDE BUSCAR: para totais e KPIs da carteira de hoje use a metric view mv_projetos (MEASURE). Para ranking, lista e detalhe por projeto use projeto_situacao_atual (uma linha por projeto, a fotografia de hoje). Para histórico semanal use fato_projeto_semana. 'Projetos em andamento' = status = 'em_andamento'. O código do projeto (PRJ-000) está em projeto_id e também na coluna projeto (iguais). O nome está em nome_projeto. Os valores de ferramenta são sempre em minúsculas: 'excel', 'clickup' e 'msproject'.",
        "PV, EV e AC no fato_projeto_semana são ACUMULADOS até a semana: NUNCA some semanas. Para um valor numa data, filtre a semana (sexta-feira) e leia a linha.",
        "FAROL E MELANCIA: farol_do_gerente é o que o gerente publicou. farol_calculado é pelo número. Melancia = projeto em andamento com farol do gerente verde e SPI < 0,9 (a coluna melancia). 'Posso confiar no farol?' compara os dois.",
        "'POR QUE O PROJETO X ATRASOU': responda com a causa_bloqueio do status_estruturado nos últimos 90 dias, ignorando sem_bloqueio e nao_reportado, ordenada por quantidade de ocorrências, com a soma de dias_impacto e o SPI do projeto. Se a causa for falta_sre, acrescente os SREs ociosos (papel = 'sre', utilização < 20% em 12 semanas).",
        "GENTE PARADA: utilização < 20% nas últimas 12 semanas, em utilizacao_pessoa_semana (SUM(horas_apontadas) / SUM(horas_disponiveis) por pessoa e projeto). Custo da hora parada = custo_ocioso.",
        "FORNECEDOR: prazo real dividido por prometido = SUM(prazo_real_dias) / SUM(prazo_prometido_dias) em silver.entregas_fornecedor, só entregas já feitas. Entrega em atraso hoje = coluna em_atraso. A CodeForge já vem normalizada como 'CodeForge Consultoria Ltda'.",
        "'O QUE VAI DAR ERRADO NO PRÓXIMO MÊS': junte (1) as entregas de consultoria em atraso hoje (silver.entregas_fornecedor, em_atraso) e (2) o change freeze do varejo de 01/11/2026 a 10/01/2027, que trava os projetos de e-commerce em andamento (tipo_projeto de e-commerce, checkout ou marketplace). Cite os projetos e quanto está em jogo. Termine com o que fazer agora.",
        "'QUAIS CLIENTES': devolva cada cliente uma única vez (SELECT DISTINCT), com a contagem de projetos se ajudar.",
    ]
    if com_score:
        texto += [
            f"SCORE DE ESTOURO: {SCORE} traz prob_estouro_30d (chance de o projeto fechar o mês abaixo de 0,9), faixa_risco (alto >= 0,5, medio >= 0,2, baixo), ranking e principais_fatores. Use sempre a data_referencia mais recente. Em 'o que vai dar errado no próximo mês' inclua os projetos com situacao = 'ok' hoje e faixa_risco alto ou medio, com os principais_fatores.",
        ]

    # ------------------------------------------------------------------ exemplos de SQL
    gold = f"{CAT}.gold"
    exemplos = [
        ("Quais projetos estão atrasados, e de quais clientes?",
         f"SELECT projeto_id, cliente, situacao, ROUND(spi, 2) AS spi, ROUND(cpi, 2) AS cpi, atraso_projetado_dias "
         f"FROM {gold}.projeto_situacao_atual WHERE status = 'em_andamento' AND situacao IN ('atenção', 'crítico') "
         f"ORDER BY LEAST(spi, cpi)"),
        ("Quais clientes têm projetos críticos?",
         f"SELECT DISTINCT cliente FROM {gold}.projeto_situacao_atual WHERE status = 'em_andamento' AND situacao = 'crítico'"),
        ("Quanto esse atraso vai me custar?",
         f"SELECT situacao, MEASURE(projetos) AS projetos, ROUND(MEASURE(estouro_previsto), 2) AS estouro_previsto "
         f"FROM {gold}.mv_projetos GROUP BY situacao ORDER BY estouro_previsto DESC"),
        ("Tenho gente parada enquanto outro projeto pede gente?",
         f"SELECT colaborador_id, nome, papel, projeto_id, ROUND(SUM(horas_apontadas) / SUM(horas_disponiveis), 3) AS utilizacao, "
         f"ROUND(SUM(custo_ocioso), 2) AS custo_ocioso FROM {gold}.utilizacao_pessoa_semana WHERE semana > DATE'2026-07-24' "
         f"GROUP BY colaborador_id, nome, papel, projeto_id HAVING SUM(horas_apontadas) / SUM(horas_disponiveis) < 0.2 "
         f"ORDER BY utilizacao"),
        ("O que vai dar errado no próximo mês?",
         f"SELECT 'entrega de consultoria em atraso' AS risco, projeto_id, fornecedor AS detalhe, "
         f"CAST(datediff(DATE'2026-10-16', data_prometida) AS STRING) || ' dias de atraso' AS situacao "
         f"FROM {CAT}.silver.entregas_fornecedor WHERE em_atraso "
         f"UNION ALL SELECT 'change freeze do varejo (01/11/2026 a 10/01/2027)', projeto_id, tipo_projeto, situacao "
         f"FROM {gold}.projeto_situacao_atual WHERE status = 'em_andamento' "
         f"AND (lower(tipo_projeto) LIKE '%commerce%' OR lower(tipo_projeto) LIKE '%checkout%' OR lower(tipo_projeto) LIKE '%marketplace%') "
         f"ORDER BY risco, projeto_id"),
    ]
    if com_score:
        exemplos.append((
            "Qual a chance de o PRJ-024 estourar o orçamento?",
            f"SELECT projeto_id, ROUND(prob_estouro_30d, 2) AS prob_estouro_30d, faixa_risco, principais_fatores "
            f"FROM {SCORE} WHERE projeto_id = 'PRJ-024' AND data_referencia = (SELECT MAX(data_referencia) FROM {SCORE})"))

    return {
        "version": 2,
        "config": {"sample_questions": [{"id": id32(1, i + 1), "question": [q]} for i, q in enumerate(perguntas)]},
        "data_sources": {
            "metric_views": [{"identifier": f"{gold}.mv_projetos"}],
            "tables": tabelas,
        },
        "instructions": {
            "example_question_sqls": [{"id": id32(2, i + 1), "question": [q], "sql": [s]} for i, (q, s) in enumerate(exemplos)],
            "text_instructions": [{"id": id32(3, 1), "content": texto}],
        },
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", default="jornadaaovivo")
    perfil = ap.parse_args().profile
    com_score = score_existe(perfil)
    espaco = montar(com_score)
    SAIDA.write_text(json.dumps(espaco, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{SAIDA.name}: {len(espaco['data_sources']['tables'])} tabelas + 1 metric view, "
          f"{len(espaco['instructions']['example_question_sqls'])} exemplos, score {'incluído' if com_score else 'ausente (a tabela não existe)'}")


if __name__ == "__main__":
    main()
