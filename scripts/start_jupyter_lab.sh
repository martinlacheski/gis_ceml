#!/usr/bin/env bash

# Script de arranque para el contenedor Jupyter del laboratorio.
# Además de instalar dependencias Python, prepara Docker CLI para que las
# notebooks puedan ejecutar comandos como `docker compose ps` o los scripts
# del proyecto que usan Docker.

# set -euo pipefail hace que el script falle rápido si un comando falla,
# si se usa una variable no definida o si falla una parte de un pipe.
set -euo pipefail

NOTEBOOK_USER="${NB_USER:-jovyan}"
SUDO=""

if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

if ! command -v docker >/dev/null 2>&1; then
  ${SUDO} apt-get update
  ${SUDO} apt-get install -y --no-install-recommends docker.io

  if ! docker compose version >/dev/null 2>&1; then
    ${SUDO} apt-get install -y --no-install-recommends docker-compose-v2 \
      || ${SUDO} apt-get install -y --no-install-recommends docker-compose-plugin \
      || ${SUDO} apt-get install -y --no-install-recommends docker-compose
  fi

  ${SUDO} rm -rf /var/lib/apt/lists/*
fi

DOCKER_GROUP=""

if [ -S /var/run/docker.sock ]; then
  DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)"
  DOCKER_GROUP="$(getent group "${DOCKER_GID}" | cut -d: -f1 || true)"

  if [ -z "${DOCKER_GROUP}" ]; then
    DOCKER_GROUP="docker-host"
    ${SUDO} groupadd --gid "${DOCKER_GID}" "${DOCKER_GROUP}"
  fi

  ${SUDO} usermod -aG "${DOCKER_GROUP}" "${NOTEBOOK_USER}"
fi

cd /home/jovyan/work
python -m pip install --no-cache-dir -r requirements.txt

if [ -n "${DOCKER_GROUP}" ]; then
  exec sg "${DOCKER_GROUP}" -c 'cd /home/jovyan/work && start-notebook.py --IdentityProvider.token="${JUPYTER_TOKEN}" --ServerApp.password=""'
fi

exec start-notebook.py --IdentityProvider.token="${JUPYTER_TOKEN}" --ServerApp.password=""
