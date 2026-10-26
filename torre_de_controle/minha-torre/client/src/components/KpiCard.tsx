import { Card, CardContent, CardHeader, CardTitle, Skeleton } from '@databricks/appkit-ui/react';

type Props = {
  titulo: string;
  valor: string | null;
  detalhe: string;
  carregando?: boolean;
  destaque?: 'critico' | 'atencao';
};

// KPI = valor + período/fonte. Sem valor (ex.: o score ainda não existe), mostra "—".
export function KpiCard({ titulo, valor, detalhe, carregando, destaque }: Props) {
  const cor = destaque === 'critico' ? 'text-destructive' : destaque === 'atencao' ? 'text-amber-600' : 'text-foreground';
  return (
    <Card className="shadow-sm">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">{titulo}</CardTitle>
      </CardHeader>
      <CardContent>
        {carregando ? <Skeleton className="h-9 w-32" /> : <div className={`text-3xl font-bold ${cor}`}>{valor ?? '—'}</div>}
        <p className="mt-1 text-xs text-muted-foreground">{detalhe}</p>
      </CardContent>
    </Card>
  );
}
