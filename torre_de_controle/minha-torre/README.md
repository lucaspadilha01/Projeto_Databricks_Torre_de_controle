# minha-torre · App "Projeto Farol"

Databricks App (AppKit, TypeScript, React, Tailwind) que lê a gold do lakehouse e responde as perguntas do dono. Documentação completa no [README da raiz](../../README.md).

| Tela | O que mostra | Fonte |
|---|---|---|
| **Projetos em risco** | 4 KPIs e a tabela dos projetos em andamento, do pior para o melhor, com farol do gerente × farol pelo número e 🍉 nas melancias | `config/queries/kpis.sql`, `projetos_risco.sql` |
| **Simulador** | Quanto vale realocar uma pessoa parada para um projeto que perde dias (horas, ociosidade evitada, dias recuperados, onboarding, saldo) | `config/queries/pessoas_ociosas.sql` |
| **Perguntar** | Chat com o Genie "Farol · Diretoria", rodando em nome de quem pergunta | plugin `genie()` |

- **Leitura** = SQL em `config/queries/*.sql` (tipos gerados pelo typegen). O score do modelo vem de uma rota do servidor (`/api/score-estouro`) que responde `{disponivel:false}` se a tabela não existir, para o build nunca quebrar.
- **Todo número do warehouse chega como texto**: `Number()` antes de formatar e `String(x) === 'true'` para booleano.

## Rodar

```bash
npm install
cp .env.example .env     # preencha DATABRICKS_HOST e DATABRICKS_WAREHOUSE_ID
npm run dev              # desenvolvimento
npm run typecheck && npm run lint
databricks apps validate --profile <perfil>
databricks bundle deploy --profile <perfil>
../scripts/conceder-acesso.sh minha-torre <perfil>   # o service principal do app precisa de SELECT na gold e na silver
databricks apps deploy --profile <perfil>
```
