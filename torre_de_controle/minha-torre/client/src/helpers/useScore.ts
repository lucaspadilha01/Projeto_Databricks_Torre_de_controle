import { useEffect, useState } from 'react';

export type LinhaScore = {
  projeto_id: string;
  prob_estouro_30d: number;
  ranking: number;
  faixa_risco: string;
  principais_fatores: string | null;
};

type EstadoScore =
  | { estado: 'carregando' }
  | { estado: 'indisponivel' }
  | { estado: 'ok'; porProjeto: Map<string, LinhaScore> };

/** Lê /api/score-estouro. Sem a tabela do modelo, devolve "indisponivel" e a tela mostra "—". */
export function useScore(): EstadoScore {
  const [estado, setEstado] = useState<EstadoScore>({ estado: 'carregando' });

  useEffect(() => {
    let ativo = true;
    fetch('/api/score-estouro')
      .then((r) => r.json())
      .then((corpo: { disponivel: boolean; linhas: LinhaScore[] }) => {
        if (!ativo) return;
        if (!corpo.disponivel) {
          setEstado({ estado: 'indisponivel' });
          return;
        }
        const porProjeto = new Map(corpo.linhas.map((l) => [l.projeto_id, { ...l, prob_estouro_30d: Number(l.prob_estouro_30d) }]));
        setEstado({ estado: 'ok', porProjeto });
      })
      .catch(() => {
        if (ativo) setEstado({ estado: 'indisponivel' });
      });
    return () => {
      ativo = false;
    };
  }, []);

  return estado;
}
