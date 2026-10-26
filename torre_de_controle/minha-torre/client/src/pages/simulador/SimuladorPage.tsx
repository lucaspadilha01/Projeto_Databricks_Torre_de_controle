import {
  Alert,
  AlertDescription,
  AlertTitle,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Empty,
  EmptyDescription,
  EmptyTitle,
  Input,
  Label,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
  useAnalyticsQuery,
} from '@databricks/appkit-ui/react';
import { useMemo, useState } from 'react';
import { KpiCard } from '../../components/KpiCard';
import { formatarDecimal, formatarInteiro, formatarPercentual, formatarReais, formatarReaisCurto } from '../../helpers/formatters';

const SEMANAS_NO_MES = 4;
const DIAS_DA_JANELA = 90; // a causa é medida em 90 dias; o mês tem 30

export function SimuladorPage() {
  const pessoas = useAnalyticsQuery('pessoas_ociosas');
  const projetos = useAnalyticsQuery('projetos_risco');
  const [pessoaEscolhida, setPessoaEscolhida] = useState<string>('');
  const [projetoEscolhido, setProjetoEscolhido] = useState<string>('');
  const [horasOnboarding, setHorasOnboarding] = useState<number>(40);

  const pessoa = pessoas.data?.find((p) => `${p.colaborador_id}|${p.projeto_id}` === pessoaEscolhida) ?? pessoas.data?.[0];
  const ehSre = pessoa?.papel === 'sre';

  // Só projetos em atenção ou crítico. Para SRE, os que mais perderam dias por falta_sre vêm primeiro;
  // para os demais papéis, a causa comparável é a rotatividade.
  const destinos = useMemo(() => {
    const dias = (p: { dias_falta_sre: number; dias_rotatividade: number }) =>
      Number(ehSre ? p.dias_falta_sre : p.dias_rotatividade);
    return (projetos.data ?? [])
      .filter((p) => (p.situacao === 'atenção' || p.situacao === 'crítico') && p.projeto_id !== pessoa?.projeto_id)
      .sort((a, b) => dias(b) - dias(a) || Number(b.estouro_previsto) - Number(a.estouro_previsto));
  }, [projetos.data, ehSre, pessoa?.projeto_id]);

  const destino = destinos.find((p) => p.projeto_id === projetoEscolhido) ?? destinos[0];

  const carregando = pessoas.loading || projetos.loading;
  const erro = pessoas.error ?? projetos.error;

  // A conta
  const horasNoMes = pessoa ? Number(pessoa.horas_paradas_semana) * SEMANAS_NO_MES : 0;
  const ociosidadeEvitada = pessoa ? Number(pessoa.custo_ocioso_semana) * SEMANAS_NO_MES : 0;
  const diasImpacto = destino ? Number(ehSre ? destino.dias_falta_sre : destino.dias_rotatividade) : 0;
  const diasRecuperados = (diasImpacto / DIAS_DA_JANELA) * 30;
  const mobilizacao = pessoa ? horasOnboarding * Number(pessoa.custo_hora) : 0;
  const saldo = ociosidadeEvitada - mobilizacao;
  const causa = ehSre ? 'falta_sre' : 'rotatividade';

  return (
    <div className="mx-auto w-full max-w-5xl space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-foreground">Simulador de realocação</h2>
        <p className="text-sm text-muted-foreground">
          Quanto vale mover uma pessoa parada para um projeto que está perdendo dias · fonte: gold (últimas 12 semanas)
        </p>
      </div>

      {erro && (
        <Alert variant="destructive">
          <AlertTitle>Não foi possível carregar os dados</AlertTitle>
          <AlertDescription>{String(erro)}</AlertDescription>
        </Alert>
      )}

      {carregando && <Skeleton className="h-40 w-full" />}

      {!carregando && !erro && (!pessoas.data || pessoas.data.length === 0) && (
        <Empty>
          <EmptyTitle>Ninguém com utilização abaixo de 20%</EmptyTitle>
          <EmptyDescription>Nas últimas 12 semanas não há pessoas ociosas para realocar.</EmptyDescription>
        </Empty>
      )}

      {pessoa && (
        <>
          <Card className="shadow-sm">
            <CardHeader>
              <CardTitle>Escolha</CardTitle>
            </CardHeader>
            <CardContent className="grid grid-cols-1 gap-4 md:grid-cols-[2fr_1.5fr_1fr]">
              <div className="min-w-0 space-y-2">
                <Label htmlFor="pessoa">Pessoa ociosa (utilização &lt; 20%)</Label>
                <Select
                  value={`${pessoa.colaborador_id}|${pessoa.projeto_id}`}
                  onValueChange={(v) => {
                    setPessoaEscolhida(v);
                    setProjetoEscolhido('');
                  }}
                >
                  <SelectTrigger id="pessoa" className="w-full">
                    <SelectValue placeholder="Escolha uma pessoa" />
                  </SelectTrigger>
                  <SelectContent>
                    {pessoas.data?.map((p) => (
                      <SelectItem key={`${p.colaborador_id}|${p.projeto_id}`} value={`${p.colaborador_id}|${p.projeto_id}`}>
                        {p.colaborador_id} · {p.nome} ({p.papel}, {p.projeto_id}, uso {formatarPercentual(p.utilizacao)})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="min-w-0 space-y-2">
                <Label htmlFor="destino">Projeto destino (atenção ou crítico)</Label>
                <Select value={destino?.projeto_id ?? ''} onValueChange={setProjetoEscolhido}>
                  <SelectTrigger id="destino" className="w-full">
                    <SelectValue placeholder="Escolha um projeto" />
                  </SelectTrigger>
                  <SelectContent>
                    {destinos.map((p) => (
                      <SelectItem key={p.projeto_id} value={p.projeto_id}>
                        {p.projeto_id} · {formatarInteiro(ehSre ? p.dias_falta_sre : p.dias_rotatividade)} dias de {causa}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="onboarding">Horas de onboarding</Label>
                <Input
                  id="onboarding"
                  type="number"
                  min={0}
                  value={horasOnboarding}
                  onChange={(e) => setHorasOnboarding(Math.max(0, Number(e.target.value)))}
                />
              </div>
            </CardContent>
          </Card>

          {destino ? (
            <>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
                <KpiCard
                  titulo="Horas no mês"
                  valor={`${formatarInteiro(horasNoMes)} h`}
                  detalhe={`${formatarDecimal(pessoa.horas_paradas_semana)} h paradas por semana × ${SEMANAS_NO_MES}`}
                />
                <KpiCard
                  titulo="Ociosidade que deixa de ser paga"
                  valor={formatarReaisCurto(ociosidadeEvitada)}
                  detalhe={`${formatarReais(pessoa.custo_ocioso_semana)} por semana × ${SEMANAS_NO_MES}`}
                />
                <KpiCard
                  titulo="Dias de cronograma recuperados"
                  valor={`${formatarDecimal(diasRecuperados)} dias`}
                  detalhe={`${formatarInteiro(diasImpacto)} dias de ${causa} em 90 dias ÷ 90 × 30`}
                />
                <KpiCard
                  titulo="Custo de mobilização"
                  valor={formatarReaisCurto(mobilizacao)}
                  detalhe={`${formatarInteiro(horasOnboarding)} h × ${formatarReais(pessoa.custo_hora)}/h`}
                  destaque="atencao"
                />
                <KpiCard
                  titulo="Saldo"
                  valor={formatarReaisCurto(saldo)}
                  detalhe="ociosidade evitada − mobilização"
                  destaque={saldo < 0 ? 'critico' : undefined}
                />
              </div>

              <details className="rounded-md border p-4 text-sm text-muted-foreground">
                <summary className="cursor-pointer font-medium text-foreground">Como a conta é feita</summary>
                <ul className="mt-3 list-disc space-y-1 pl-5">
                  <li>
                    <strong>Horas no mês</strong> = horas paradas por semana (média das últimas 12 semanas) × 4 semanas.
                  </li>
                  <li>
                    <strong>Ociosidade que deixa de ser paga</strong> = custo ocioso médio por semana × 4. É dinheiro que a
                    empresa já gasta com a pessoa parada e passa a render trabalho.
                  </li>
                  <li>
                    <strong>Dias recuperados</strong> = dias de impacto declarados na causa ({causa}) nos últimos 90 dias
                    ÷ 90 × 30. Para SRE a causa é falta_sre; para os demais papéis, rotatividade.
                  </li>
                  <li>
                    <strong>Mobilização</strong> = horas de onboarding (editável, padrão 40) × custo por hora da pessoa.
                  </li>
                  <li>
                    <strong>Saldo</strong> = ociosidade evitada − mobilização. Os dias recuperados não entram em reais:
                    são o ganho de cronograma, somado ao saldo.
                  </li>
                </ul>
              </details>
            </>
          ) : (
            <Empty>
              <EmptyTitle>Nenhum projeto destino</EmptyTitle>
              <EmptyDescription>Não há projetos em atenção ou crítico para receber a pessoa.</EmptyDescription>
            </Empty>
          )}
        </>
      )}
    </div>
  );
}
