Para borrar y empezar de nuevo sin borrar imagenes, hace esto desde la rai­z del repo:

# 1. Apagar y borrar contenedores/redes/volÃºmenes nombrados
docker compose down -v

# 2. Borrar datos generados por bind mounts
rm -rf sqlserver/data postgis/data sqlserver/backup/*.bak sqlserver/exports/*

# 3. Preparar permisos de carpetas generadas
./scripts/prepare_docker_dirs.sh

# 4. Regenerar pgAdmin pgpass desde .env
./scripts/render_pgadmin_config.sh

# 5. Levantar servicios
docker compose up -d sqlserver postgis pgadmin geoserver webgis

# 6. Ver estado
docker compose ps