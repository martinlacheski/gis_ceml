#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$BASE_DIR/docker-compose.yml"
SA_PASSWORD="${MSSQL_SA_PASSWORD:-CEML_Admin_2026!}"

usage() {
  cat <<'EOF'
Uso:
  ./scripts/gis_sqlserver.sh prepare-backup
  ./scripts/gis_sqlserver.sh up
  ./scripts/gis_sqlserver.sh down
  ./scripts/gis_sqlserver.sh info-backup [ruta_backup]
  ./scripts/gis_sqlserver.sh restore [ruta_backup] [db_name] [logical_data_name] [logical_log_name]
  ./scripts/gis_sqlserver.sh restore-auto [ruta_backup] [db_name]
  ./scripts/gis_sqlserver.sh list-tables [db_name]
  ./scripts/gis_sqlserver.sh export-table [db_name] [schema] [table] [output_csv]
  ./scripts/gis_sqlserver.sh export-candidates [db_name]

Notas:
- ruta_backup por defecto: /var/opt/mssql/backup/ceml_gis.bak
- db_name por defecto: CEML_GIS
- output_csv se escribe dentro de /exports del contenedor (montado en sqlserver/exports)
- prepare-backup copia sqlserver/20211020 a sqlserver/backup/ceml_gis.bak
- restore-auto lee los logical names del backup y ejecuta restore automáticamente
- export-table genera archivos con encabezados; para texto libre se recomienda extensión .tsv
- export-candidates exporta las tablas iniciales para explorar puntos, líneas, polígonos y contexto operativo
EOF
}

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

sqlcmd_query() {
  local database="$1"
  local query="$2"

  compose exec -T sqlserver /bin/bash -lc "SQLCMD=\$([ -x /opt/mssql-tools18/bin/sqlcmd ] && echo /opt/mssql-tools18/bin/sqlcmd || echo /opt/mssql-tools/bin/sqlcmd); SQLCMD_TLS=\$([ \"\$SQLCMD\" = /opt/mssql-tools18/bin/sqlcmd ] && echo -C || echo ''); \"\$SQLCMD\" \$SQLCMD_TLS -S localhost -U SA -P '$SA_PASSWORD' -d '$database' -Q \"$query\" -W -s \$'\t'"
}

cmd_prepare_backup() {
  local source_file="$BASE_DIR/sqlserver/20211020"
  local target_dir="$BASE_DIR/sqlserver/backup"
  local target_file="$target_dir/ceml_gis.bak"

  if [ ! -f "$source_file" ]; then
    echo "❌ No se encontró el archivo recibido: $source_file"
    exit 1
  fi

  mkdir -p "$target_dir"

  if [ -f "$target_file" ] && [ "$(stat -c%s "$target_file")" = "$(stat -c%s "$source_file")" ]; then
    echo "✅ Backup ya preparado en: sqlserver/backup/ceml_gis.bak"
    return 0
  fi

  cp -a "$source_file" "$target_file"
  echo "✅ Backup preparado en: sqlserver/backup/ceml_gis.bak"
}

wait_ready() {
  local max=40
  local i=1

  while [ "$i" -le "$max" ]; do
    if compose exec -T sqlserver /bin/bash -lc "SQLCMD=\$([ -x /opt/mssql-tools18/bin/sqlcmd ] && echo /opt/mssql-tools18/bin/sqlcmd || echo /opt/mssql-tools/bin/sqlcmd); SQLCMD_TLS=\$([ \"\$SQLCMD\" = /opt/mssql-tools18/bin/sqlcmd ] && echo -C || echo ''); \"\$SQLCMD\" \$SQLCMD_TLS -S localhost -U SA -P '$SA_PASSWORD' -Q 'SELECT 1' -b -o /dev/null" >/dev/null 2>&1; then
      echo "✅ SQL Server listo."
      return 0
    fi
    sleep 3
    i=$((i + 1))
  done

  echo "❌ SQL Server no respondió a tiempo."
  exit 1
}

cmd_up() {
  mkdir -p "$BASE_DIR/sqlserver/data" "$BASE_DIR/sqlserver/backup" "$BASE_DIR/sqlserver/exports"
  chmod a+rwx "$BASE_DIR/sqlserver/data" "$BASE_DIR/sqlserver/backup" "$BASE_DIR/sqlserver/exports" || true
  compose up -d
  wait_ready
}

cmd_down() {
  compose down
}

cmd_info_backup() {
  local backup_path="${1:-/var/opt/mssql/backup/ceml_gis.bak}"

  compose exec -T sqlserver /bin/bash -lc "SQLCMD=\$([ -x /opt/mssql-tools18/bin/sqlcmd ] && echo /opt/mssql-tools18/bin/sqlcmd || echo /opt/mssql-tools/bin/sqlcmd); SQLCMD_TLS=\$([ \"\$SQLCMD\" = /opt/mssql-tools18/bin/sqlcmd ] && echo -C || echo ''); \"\$SQLCMD\" \$SQLCMD_TLS -S localhost -U SA -P '$SA_PASSWORD' -Q \"RESTORE FILELISTONLY FROM DISK = N'$backup_path';\" -W"
}

detect_logical_names() {
  local backup_path="${1:-/var/opt/mssql/backup/ceml_gis.bak}"

  compose exec -T sqlserver /bin/bash -lc "SQLCMD=\$([ -x /opt/mssql-tools18/bin/sqlcmd ] && echo /opt/mssql-tools18/bin/sqlcmd || echo /opt/mssql-tools/bin/sqlcmd); SQLCMD_TLS=\$([ \"\$SQLCMD\" = /opt/mssql-tools18/bin/sqlcmd ] && echo -C || echo ''); \"\$SQLCMD\" \$SQLCMD_TLS -S localhost -U SA -P '$SA_PASSWORD' -Q \"RESTORE FILELISTONLY FROM DISK = N'$backup_path';\" -h -1 -W -s \$'\t'" \
    | awk -F'\t' 'NF >= 3 && ($3 == "D" || $3 == "L") { print $1 "\t" $3 }'
}

cmd_restore() {
  local backup_path="${1:-/var/opt/mssql/backup/ceml_gis.bak}"
  local db_name="${2:-CEML_GIS}"
  local logical_data_name="${3:-}"
  local logical_log_name="${4:-}"

  if [ -z "$logical_data_name" ] || [ -z "$logical_log_name" ]; then
    echo "❌ Faltan logical names. Ejecutá primero:"
    echo "   ./scripts/gis_sqlserver.sh info-backup $backup_path"
    echo "   y luego pasá logical_data_name y logical_log_name al restore."
    exit 1
  fi

  local sql
  sql="RESTORE DATABASE [$db_name] FROM DISK = N'$backup_path' WITH MOVE N'$logical_data_name' TO N'/var/opt/mssql/data/${db_name}.mdf', MOVE N'$logical_log_name' TO N'/var/opt/mssql/data/${db_name}_log.ldf', REPLACE, STATS = 10;"

  compose exec -T sqlserver /bin/bash -lc "SQLCMD=\$([ -x /opt/mssql-tools18/bin/sqlcmd ] && echo /opt/mssql-tools18/bin/sqlcmd || echo /opt/mssql-tools/bin/sqlcmd); SQLCMD_TLS=\$([ \"\$SQLCMD\" = /opt/mssql-tools18/bin/sqlcmd ] && echo -C || echo ''); \"\$SQLCMD\" \$SQLCMD_TLS -S localhost -U SA -P '$SA_PASSWORD' -Q \"$sql\" -b"
  compose exec -T sqlserver /bin/bash -lc "SQLCMD=\$([ -x /opt/mssql-tools18/bin/sqlcmd ] && echo /opt/mssql-tools18/bin/sqlcmd || echo /opt/mssql-tools/bin/sqlcmd); SQLCMD_TLS=\$([ \"\$SQLCMD\" = /opt/mssql-tools18/bin/sqlcmd ] && echo -C || echo ''); \"\$SQLCMD\" \$SQLCMD_TLS -S localhost -U SA -P '$SA_PASSWORD' -Q \"SELECT name FROM sys.databases ORDER BY name;\" -W"
}

cmd_restore_auto() {
  local backup_path="${1:-/var/opt/mssql/backup/ceml_gis.bak}"
  local db_name="${2:-CEML_GIS}"
  local logical_data_name=""
  local logical_log_name=""

  while IFS=$'\t' read -r logical_name file_type; do
    case "$file_type" in
      D) logical_data_name="$logical_name" ;;
      L) logical_log_name="$logical_name" ;;
    esac
  done < <(detect_logical_names "$backup_path")

  if [ -z "$logical_data_name" ] || [ -z "$logical_log_name" ]; then
    echo "❌ No se pudieron detectar logical names automáticamente."
    echo "   Ejecutá: ./scripts/gis_sqlserver.sh info-backup $backup_path"
    echo "   Luego usá: ./scripts/gis_sqlserver.sh restore $backup_path $db_name <LOGICAL_DATA_NAME> <LOGICAL_LOG_NAME>"
    exit 1
  fi

  echo "✅ Logical data detectado: $logical_data_name"
  echo "✅ Logical log detectado: $logical_log_name"
  cmd_restore "$backup_path" "$db_name" "$logical_data_name" "$logical_log_name"
}

cmd_list_tables() {
  local db_name="${1:-CEML_GIS}"

  compose exec -T sqlserver /bin/bash -lc "SQLCMD=\$([ -x /opt/mssql-tools18/bin/sqlcmd ] && echo /opt/mssql-tools18/bin/sqlcmd || echo /opt/mssql-tools/bin/sqlcmd); SQLCMD_TLS=\$([ \"\$SQLCMD\" = /opt/mssql-tools18/bin/sqlcmd ] && echo -C || echo ''); \"\$SQLCMD\" \$SQLCMD_TLS -S localhost -U SA -P '$SA_PASSWORD' -d '$db_name' -Q \"SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' ORDER BY TABLE_SCHEMA, TABLE_NAME;\" -W"
}

cmd_export_table() {
  local db_name="${1:-CEML_GIS}"
  local schema_name="${2:-dbo}"
  local table_name="${3:-}"
  local output_csv="${4:-}"

  if [ -z "$table_name" ] || [ -z "$output_csv" ]; then
    echo "❌ Uso: ./scripts/gis_sqlserver.sh export-table [db] [schema] [table] [output_csv]"
    exit 1
  fi

  local query="SET NOCOUNT ON; SELECT * FROM [$db_name].[$schema_name].[$table_name];"
  local tmp_csv="${output_csv}.tmp"

  mkdir -p "$BASE_DIR/sqlserver/exports"

  # Usamos sqlcmd en vez de bcp para que el proceso sea más transparente en clase.
  # sqlcmd genera encabezados y una línea separadora; luego quitamos esa línea separadora.
  # Usamos tabulador como separador para no romper textos que contienen comas.
  compose exec -T sqlserver /bin/bash -lc "SQLCMD=\$([ -x /opt/mssql-tools18/bin/sqlcmd ] && echo /opt/mssql-tools18/bin/sqlcmd || echo /opt/mssql-tools/bin/sqlcmd); SQLCMD_TLS=\$([ \"\$SQLCMD\" = /opt/mssql-tools18/bin/sqlcmd ] && echo -C || echo ''); \"\$SQLCMD\" \$SQLCMD_TLS -S localhost -U SA -P '$SA_PASSWORD' -d '$db_name' -Q \"$query\" -W -s \$'\t' -o \"/exports/$tmp_csv\""

  awk 'NR == 2 && $0 ~ /^[-\t]+$/ { next } NF { print }' "$BASE_DIR/sqlserver/exports/$tmp_csv" > "$BASE_DIR/sqlserver/exports/$output_csv"
  rm -f "$BASE_DIR/sqlserver/exports/$tmp_csv"
  echo "✅ Export generado en: sqlserver/exports/$output_csv"
}

cmd_export_candidates() {
  local db_name="${1:-CEML_GIS}"

  echo "📦 Exportando tablas candidatas para análisis GIS..."
  cmd_export_table "$db_name" dbo AP_ALUMBRADO ap_alumbrado.tsv
  cmd_export_table "$db_name" dbo AP_alumbrado_luminarias ap_alumbrado_luminarias.tsv
  cmd_export_table "$db_name" dbo catastro catastro.tsv
  cmd_export_table "$db_name" dbo suministro suministro.tsv
  cmd_export_table "$db_name" dbo Trafos trafos.tsv
  cmd_export_table "$db_name" dbo BT_cables bt_cables.tsv
  cmd_export_table "$db_name" dbo BT_cables_cat bt_cables_cat.tsv
  cmd_export_table "$db_name" dbo MT_cables mt_cables.tsv
  cmd_export_table "$db_name" dbo MT_cables_cat mt_cables_cat.tsv
  cmd_export_table "$db_name" dbo RCL_Reclamos rcl_reclamos.tsv
  cmd_export_table "$db_name" dbo RCL_Reclamos_Descripcion rcl_reclamos_descripcion.tsv
  cmd_export_table "$db_name" dbo RCL_Motivos rcl_motivos.tsv
  echo "✅ Exportación de candidatas finalizada en sqlserver/exports/"
}

main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    prepare-backup) cmd_prepare_backup "$@" ;;
    up) cmd_up "$@" ;;
    down) cmd_down "$@" ;;
    info-backup) cmd_info_backup "$@" ;;
    restore) cmd_restore "$@" ;;
    restore-auto) cmd_restore_auto "$@" ;;
    list-tables) cmd_list_tables "$@" ;;
    export-table) cmd_export_table "$@" ;;
    export-candidates) cmd_export_candidates "$@" ;;
    *) usage ; exit 1 ;;
  esac
}

main "$@"
