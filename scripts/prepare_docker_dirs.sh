#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER_IMAGE="nginx:1.27-alpine"

docker run --rm \
  --user 0 \
  -v "$BASE_DIR:/workspace" \
  "$HELPER_IMAGE" \
  sh -ceu '
    cd /workspace

    for dir in \
      sqlserver/data \
      sqlserver/backup \
      sqlserver/exports \
      postgis/data
    do
      mkdir -p "$dir"
      chmod 777 "$dir"
    done
  '

cat <<'EOF'
Directorios Docker preparados para el laboratorio local:
- sqlserver/data
- sqlserver/backup
- sqlserver/exports
- postgis/data

Nota: se usa chmod 777 solo sobre estos directorios generados para evitar bloqueos
de permisos en bind mounts recreados por Docker. No aplicar este criterio en producción.
EOF
