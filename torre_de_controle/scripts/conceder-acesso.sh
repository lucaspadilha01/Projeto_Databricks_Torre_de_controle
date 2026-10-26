#!/usr/bin/env bash
# Dá ao service principal do app o acesso de leitura que ele precisa no Unity Catalog.
# O app nasce como um usuário novo, sem acesso a nada: sem isso o BUILD falha no typegen
# com INSUFFICIENT_PERMISSIONS.
#
# Uso: scripts/conceder-acesso.sh [app] [perfil]
set -euo pipefail

APP="${1:-minha-torre}"
PERFIL="${2:-jornadaaovivo}"
CATALOGO="lakehouse_vertice"

SP=$(databricks apps get "$APP" --profile "$PERFIL" -o json \
  | python -c "import json,sys; print(json.load(sys.stdin)['service_principal_client_id'])")
echo "App $APP -> service principal $SP"

# Com várias queries a CLI exige --output json e devolve um objeto por comando.
# O código de saída não basta: confira o estado de cada um.
databricks experimental aitools tools query --output json --profile "$PERFIL" \
  "GRANT USE CATALOG ON CATALOG $CATALOGO TO \`$SP\`" \
  "GRANT USE SCHEMA, SELECT ON SCHEMA $CATALOGO.gold TO \`$SP\`" \
  "GRANT USE SCHEMA, SELECT ON SCHEMA $CATALOGO.silver TO \`$SP\`" \
  | python -c "
import json, sys
falhas = [r for r in json.load(sys.stdin) if r['state'] != 'SUCCEEDED']
for r in falhas:
    print('FALHOU:', r['sql'], r.get('error'))
sys.exit(1 if falhas else 0)"

echo "Acesso concedido: USE CATALOG em $CATALOGO; USE SCHEMA + SELECT na gold e na silver."
