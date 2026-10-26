import { createApp, analytics, genie, server, getExecutionContext } from '@databricks/appkit';
import { z } from 'zod';

// A probabilidade de estouro vem do modelo (gold.score_estouro_30d), que PODE NÃO EXISTIR.
// Por isso nenhuma query de config/queries depende dela: o typegen do build quebraria.
// Esta rota lê a tabela e, se ela não existir, responde {disponivel:false} e a tela mostra "—".
const linhaScore = z.object({
  projeto_id: z.string(),
  prob_estouro_30d: z.coerce.number(),
  ranking: z.coerce.number(),
  faixa_risco: z.string(),
  principais_fatores: z.string().nullable(),
});

const COLUNAS = ['projeto_id', 'prob_estouro_30d', 'ranking', 'faixa_risco', 'principais_fatores'];

async function lerScore() {
  // Fora de asUser(req), o contexto é o do service principal do app
  const { client, warehouseId } = getExecutionContext();
  const resposta = await client.statementExecution.executeStatement({
    warehouse_id: (await warehouseId) ?? process.env.DATABRICKS_WAREHOUSE_ID ?? '',
    statement: `SELECT ${COLUNAS.join(', ')} FROM lakehouse_vertice.gold.score_estouro_30d ORDER BY ranking`,
    wait_timeout: '30s',
  });
  if (resposta.status?.state !== 'SUCCEEDED') {
    // TABLE_OR_VIEW_NOT_FOUND (ou qualquer falha): o score não está disponível
    return { disponivel: false, linhas: [] };
  }
  const linhas = (resposta.result?.data_array ?? []).map((valores) =>
    linhaScore.parse(Object.fromEntries(COLUNAS.map((coluna, i) => [coluna, valores[i]]))),
  );
  return { disponivel: true, linhas };
}

createApp({
  plugins: [analytics(), genie(), server()],
  onPluginsReady(appkit) {
    appkit.server.extend((app) => {
      // Quem está perguntando: a tela Perguntar mostra o e-mail que a plataforma injeta
      app.get('/api/whoami', (req, res) => {
        res.json({ email: req.header('x-forwarded-email') ?? null });
      });

      app.get('/api/score-estouro', async (_req, res) => {
        try {
          res.json(await lerScore());
        } catch (erro) {
          console.error('score-estouro indisponível:', erro);
          res.json({ disponivel: false, linhas: [] });
        }
      });
    });
  },
}).catch(console.error);
