#!/usr/bin/env bash

# Script de apoyo para clase: genera el archivo pgpass que usa pgAdmin para
# conectarse a PostGIS sin escribir credenciales duplicadas a mano.

# set -euo pipefail hace que el script falle rápido si un comando falla,
# si se usa una variable no definida o si falla una parte de un pipe.
set -euo pipefail

# Ubicamos la raíz del repositorio a partir de la ruta real del script.
# Así el comando funciona desde cualquier directorio.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

# Preferimos .env porque representa la configuración local del estudiante.
# Si no existe, usamos .env.example para mantener valores de demostración.
ENV_FILE=""
if [[ -f "${REPO_ROOT}/.env" ]]; then
  ENV_FILE="${REPO_ROOT}/.env"
elif [[ -f "${REPO_ROOT}/.env.example" ]]; then
  ENV_FILE="${REPO_ROOT}/.env.example"
fi

# Cargamos las variables del archivo elegido y las exportamos temporalmente.
# set -a exporta automáticamente cada variable definida durante el source.
if [[ -n "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

# Defaults seguros para clase si no hay archivo .env disponible.
POSTGRES_DB="${POSTGRES_DB:-ceml_gis}"
POSTGRES_USER="${POSTGRES_USER:-ceml}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-ceml_admin_2026}"

TEMPLATE_PATH="${REPO_ROOT}/pgadmin-config/pgpass.template"
PGPASS_PATH="${REPO_ROOT}/pgadmin-config/pgpass"

if [[ ! -f "${TEMPLATE_PATH}" ]]; then
  printf 'Error: no se encontró %s\n' "${TEMPLATE_PATH}" >&2
  exit 1
fi

# Bash no expande variables dentro de un template automáticamente, así que
# reemplazamos los placeholders explícitamente con sustitución de cadenas.
template="$(<"${TEMPLATE_PATH}")"
rendered="${template//\$\{POSTGRES_DB\}/${POSTGRES_DB}}"
rendered="${rendered//\$\{POSTGRES_USER\}/${POSTGRES_USER}}"
rendered="${rendered//\$\{POSTGRES_PASSWORD\}/${POSTGRES_PASSWORD}}"

# pgAdmin corre dentro de Docker: desde ahí debe conectarse al servicio
# llamado postgis y al puerto interno 5432, no al puerto publicado en el host.
if [[ "${rendered}" != postgis:5432:* ]]; then
  printf 'Error: pgpass debe usar el host Docker postgis y el puerto interno 5432\n' >&2
  exit 1
fi

# pgpass exige permisos restrictivos. Si chmod falla en algún sistema de
# archivos, no cortamos la generación porque el archivo igualmente queda escrito.
printf '%s\n' "${rendered}" > "${PGPASS_PATH}"
chmod 600 "${PGPASS_PATH}" 2>/dev/null || true

printf 'pgAdmin pgpass generado en %s\n' "${PGPASS_PATH}"
