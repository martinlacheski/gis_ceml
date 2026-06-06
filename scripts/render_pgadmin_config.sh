#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

ENV_FILE=""
if [[ -f "${REPO_ROOT}/.env" ]]; then
  ENV_FILE="${REPO_ROOT}/.env"
elif [[ -f "${REPO_ROOT}/.env.example" ]]; then
  ENV_FILE="${REPO_ROOT}/.env.example"
fi

if [[ -n "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

POSTGRES_DB="${POSTGRES_DB:-ceml_gis}"
POSTGRES_USER="${POSTGRES_USER:-ceml}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-ceml_admin_2026}"

TEMPLATE_PATH="${REPO_ROOT}/pgadmin-config/pgpass.template"
PGPASS_PATH="${REPO_ROOT}/pgadmin-config/pgpass"

if [[ ! -f "${TEMPLATE_PATH}" ]]; then
  printf 'Error: no se encontró %s\n' "${TEMPLATE_PATH}" >&2
  exit 1
fi

template="$(<"${TEMPLATE_PATH}")"
rendered="${template//\$\{POSTGRES_DB\}/${POSTGRES_DB}}"
rendered="${rendered//\$\{POSTGRES_USER\}/${POSTGRES_USER}}"
rendered="${rendered//\$\{POSTGRES_PASSWORD\}/${POSTGRES_PASSWORD}}"

if [[ "${rendered}" != postgis:5432:* ]]; then
  printf 'Error: pgpass debe usar el host Docker postgis y el puerto interno 5432\n' >&2
  exit 1
fi

printf '%s\n' "${rendered}" > "${PGPASS_PATH}"
chmod 600 "${PGPASS_PATH}" 2>/dev/null || true

printf 'pgAdmin pgpass generado en %s\n' "${PGPASS_PATH}"
