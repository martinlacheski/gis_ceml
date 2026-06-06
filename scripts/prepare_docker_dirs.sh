#!/usr/bin/env bash

# Script de apoyo para clase: prepara las carpetas locales que Docker monta
# como volúmenes bind. Docker puede recrearlas con dueño root; por eso este
# paso evita errores de permisos antes de iniciar los servicios.

# set -euo pipefail hace que el script falle rápido si un comando falla,
# si se usa una variable no definida o si falla una parte de un pipe.
set -euo pipefail

# Calculamos la raíz del repositorio para que el script funcione aunque se lo
# ejecute desde otra carpeta.
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Usamos una imagen liviana ya disponible en Docker Hub solo como herramienta
# temporal para crear/chmod carpetas desde un contenedor con usuario root.
HELPER_IMAGE="nginx:1.27-alpine"

# Ejecutamos como root dentro del contenedor helper para poder ajustar permisos
# de carpetas que Docker pudo haber creado como root.
# Montamos todo el repositorio en /workspace para operar sobre rutas locales.
docker run --rm \
  --user 0 \
  -v "$BASE_DIR:/workspace" \
  "$HELPER_IMAGE" \
  sh -ceu '
    cd /workspace

    # Solo tocamos directorios generados por el laboratorio. NO modificamos
    # código fuente ni archivos de entrada.
    for dir in \
      sqlserver/data \
      sqlserver/backup \
      sqlserver/exports \
      postgis/data
    do
      mkdir -p "$dir"
      # chmod 777 es aceptable acá porque son carpetas locales generadas para
      # un laboratorio Docker; no debe copiarse como práctica de producción.
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
