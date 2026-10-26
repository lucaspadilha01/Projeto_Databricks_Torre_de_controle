import {
  Alert,
  AlertDescription,
  AlertTitle,
  Badge,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Empty,
  EmptyDescription,
  EmptyTitle,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useAnalyticsQuery,
} from '@databricks/appkit-ui/react';
import { KpiCard } from '../../components/KpiCard';
import {
  formatarIndice,
  formatarInteiro,
  formatarPercentual,
  formatarReais,
  formatarReaisCurto,
} from '../../helpers/formatters';
import { useScore } from '../../helpers/useScore';

const NOMES_CAUSA: Record<string, string> = {
  change_freeze: 'Change freeze',
  falta_sre: 'Falta de SRE',
  dependencia_fornecedor: 'Fornecedor',
  rotatividade: 'Rotatividade',
  mudanca_escopo: 'Mudança de escopo',
  bug_retrabalho: 'Bug / retrabalho',
  aprovacao_cliente: 'Aprovação do cliente',
};

function Situacao({ valor }: { valor: string }) {
  if (valor === 'crítico') return <Badge variant="destructive">Crítico</Badge>;
  if (valor === 'atenção') return <Badge className="bg-amber-500 text-white hover:bg-amber-500">Atenção</Badge>;
  return <Badge variant="secondary">OK</Badge>;
}

export function RiscoPage() {
  const kpis = useAnalyticsQuery('kpis');
  const projetos = useAnalyticsQuery('projetos_risco');
  const score = useScore();

  const kpi = kpis.data?.[0];
  const altoRisco =
    score.estado === 'ok' ? [...score.porProjeto.values()].filter((l) => l.faixa_risco === 'alto').length : null;

  return (
    <div className="mx-auto w-full max-w-7xl space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-foreground">Projetos em risco</h2>
        <p className="text-sm text-muted-foreground">
          Carteira em andamento · fotografia de 16/10/2026 · fonte: gold.projeto_situacao_atual
        </p>
      </div>

      {kpis.error && (
        <Alert variant="destructive">
          <AlertTitle>Não foi possível carregar os indicadores</AlertTitle>
          <AlertDescription>{String(kpis.error)}</AlertDescription>
        </Alert>
      )}

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KpiCard
          titulo="Projetos em risco"
          valor={kpi ? `${formatarInteiro(kpi.em_risco)} de ${formatarInteiro(kpi.projetos_em_andamento)}` : null}
          detalhe={
            kpi
              ? `${formatarInteiro(kpi.criticos)} críticos · ${formatarInteiro(kpi.melancias)} melancias (atenção + crítico)`
              : 'atenção + crítico'
          }
          carregando={kpis.loading}
          destaque="atencao"
        />
        <KpiCard
          titulo="Estouro previsto"
          valor={kpi ? formatarReaisCurto(kpi.estouro_previsto) : null}
          detalhe="EAC − orçamento, projetos em andamento"
          carregando={kpis.loading}
          destaque="critico"
        />
        <KpiCard
          titulo="Carteira em andamento"
          valor={kpi ? formatarReaisCurto(kpi.carteira) : null}
          detalhe="valor dos contratos em andamento"
          carregando={kpis.loading}
        />
        <KpiCard
          titulo="Alto risco em 30 dias"
          valor={altoRisco === null ? null : formatarInteiro(altoRisco)}
          detalhe={
            score.estado === 'indisponivel'
              ? 'modelo de score ainda não disponível'
              : 'projetos com P(estouro) ≥ 50% (modelo)'
          }
          carregando={score.estado === 'carregando'}
        />
      </div>

      <Card className="shadow-sm">
        <CardHeader>
          <CardTitle>Do pior para o melhor</CardTitle>
          <p className="text-sm text-muted-foreground">
            Ordenado pelo menor entre SPI e CPI. 🍉 = melancia: o gerente diz verde, o número diz atraso (SPI &lt; 0,90).
          </p>
        </CardHeader>
        <CardContent>
          {projetos.loading && (
            <div className="space-y-2">
              <Skeleton className="h-8 w-full" />
              <Skeleton className="h-8 w-full" />
              <Skeleton className="h-8 w-full" />
            </div>
          )}
          {projetos.error && (
            <Alert variant="destructive">
              <AlertTitle>Não foi possível carregar os projetos</AlertTitle>
              <AlertDescription>{String(projetos.error)}</AlertDescription>
            </Alert>
          )}
          {projetos.data && projetos.data.length === 0 && (
            <Empty>
              <EmptyTitle>Nenhum projeto em andamento</EmptyTitle>
              <EmptyDescription>A gold não trouxe projetos com status em_andamento.</EmptyDescription>
            </Empty>
          )}
          {projetos.data && projetos.data.length > 0 && (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Projeto</TableHead>
                  <TableHead>Situação</TableHead>
                  <TableHead className="text-right">SPI</TableHead>
                  <TableHead className="text-right">CPI</TableHead>
                  <TableHead className="text-right">Estouro previsto</TableHead>
                  <TableHead className="text-right">Atraso (dias)</TableHead>
                  <TableHead>Farol do gerente</TableHead>
                  <TableHead>Farol pelo número</TableHead>
                  <TableHead>Causa mais frequente</TableHead>
                  <TableHead className="text-right">P(estouro)</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {projetos.data.map((p) => {
                  // o warehouse devolve o booleano como texto: "false" seria verdadeiro no JavaScript
                  const linhaScore = score.estado === 'ok' ? score.porProjeto.get(p.projeto_id) : undefined;
                  return (
                    <TableRow key={p.projeto_id}>
                      <TableCell>
                        <div className="font-medium">{p.projeto}</div>
                        <div className="text-xs text-muted-foreground">{p.cliente}</div>
                      </TableCell>
                      <TableCell>
                        <Situacao valor={p.situacao} />
                      </TableCell>
                      <TableCell className="text-right">{formatarIndice(p.spi)}</TableCell>
                      <TableCell className="text-right">{formatarIndice(p.cpi)}</TableCell>
                      <TableCell className="text-right">{formatarReais(p.estouro_previsto)}</TableCell>
                      <TableCell className="text-right">{formatarInteiro(p.atraso_projetado_dias)}</TableCell>
                      <TableCell>
                        {p.farol_do_gerente}
                        {String(p.melancia) === 'true' ? ' 🍉' : ''}
                      </TableCell>
                      <TableCell>{p.farol_calculado}</TableCell>
                      <TableCell>{NOMES_CAUSA[p.causa_principal] ?? '—'}</TableCell>
                      <TableCell className="text-right">
                        {linhaScore ? formatarPercentual(linhaScore.prob_estouro_30d) : '—'}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
