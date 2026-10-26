import { Alert, AlertDescription, AlertTitle, Badge, GenieChat } from '@databricks/appkit-ui/react';
import { useEffect, useState } from 'react';

const PERGUNTAS = [
  'Quais projetos estão atrasados, e de quais clientes?',
  'Quanto esse atraso vai me custar?',
  'Tenho gente parada enquanto outro projeto pede gente?',
  'O que vai dar errado no próximo mês, e o que eu faço agora?',
];

export function PerguntarPage() {
  const [email, setEmail] = useState<string | null>(null);

  useEffect(() => {
    fetch('/api/whoami')
      .then((r) => (r.ok ? (r.json() as Promise<{ email: string | null }>) : null))
      .then((corpo) => setEmail(corpo?.email ?? null))
      .catch(() => setEmail(null));
  }, []);

  return (
    <div className="mx-auto w-full max-w-4xl space-y-4">
      <div className="flex flex-wrap items-center gap-3">
        <div>
          <h2 className="text-2xl font-bold text-foreground">Perguntar</h2>
          <p className="text-sm text-muted-foreground">
            Pergunte em português ao Genie “Farol · Diretoria”. Dados da fotografia de 16/10/2026.
          </p>
        </div>
        <Badge variant="secondary" className="ml-auto">
          {email ?? 'usuário não identificado'}
        </Badge>
      </div>

      <Alert>
        <AlertTitle>Resposta gerada por IA: confira antes de decidir</AlertTitle>
        <AlertDescription>
          O Genie escreve o SQL e roda no warehouse. Abra o SQL de cada resposta para ver como o número foi calculado. As
          consultas rodam em nome de quem pergunta, com as permissões do próprio usuário.
        </AlertDescription>
      </Alert>

      <p className="text-sm text-muted-foreground">Sugestões: {PERGUNTAS.join(' · ')}</p>

      <div className="h-[600px] rounded-md border">
        <GenieChat alias="default" placeholder="Pergunte sobre projetos, custos, pessoas ou fornecedores" />
      </div>
    </div>
  );
}
