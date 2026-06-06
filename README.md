# Bases de Datos Espaciales
## Tecnicatura Universitaria en Sistemas de Información Geográfica y Teledetección  
### Universidad Nacional de Misiones  

**Docente responsable:** Esp. Lic. Martín Aníbal Lacheski.  
**Ayudante de Primera:** Mgter. Ing. Yanina Andrea Caffetti.


# Laboratorio GIS CEML

Este proyecto contiene un laboratorio para analizar datos GIS recibidos desde SQL Server y archivos CAD/DXF, preparar una migración controlada hacia PostgreSQL/PostGIS y visualizar los datos con pgAdmin/QGIS y una web GIS basada en GeoServer/OpenLayers.

El flujo actual trabaja con un **piloto chico de media tensión de Montecarlo**.

## Requisitos

- Docker y Docker Compose.
- Python 3.12 o compatible si se ejecutan notebooks fuera de Docker.
- JupyterLab si se ejecutan notebooks fuera de Docker.
- Un entorno virtual Python recomendado en `.venv/` para ejecución local sin Docker.

## Datos no versionados

El repositorio no incluye el backup original de SQL Server ni archivos derivados pesados, porque superan los límites de GitHub y no deben versionarse junto con el código del laboratorio.

### Archivo obligatorio para el flujo completo

Para replicar el flujo completo desde cero se necesita disponer localmente del backup recibido y ubicarlo exactamente en:

```text
sqlserver/20211020
```

Ese archivo es requerido por la notebook 01 para restaurar la base `CEML_GIS` y volver a exportar los TSV del piloto MT.

### Archivos necesarios si se empieza desde exports TSV

Si no se usa el backup SQL Server, se puede empezar desde exports TSV ya generados. Para el piloto MT deben ubicarse en:

```text
sqlserver/exports/
```

Archivos mínimos esperados:

```text
sqlserver/exports/tmp_shapefile.tsv
sqlserver/exports/objetos_red.tsv
sqlserver/exports/set.tsv
sqlserver/exports/seccionadores.tsv
sqlserver/exports/mt_cables.tsv
```

Con esos archivos se puede continuar desde las notebooks 05 y 06 para cargar PostGIS y generar las capas QGIS/Web.

### Archivos CAD/DXF opcionales

Los archivos CAD/DXF no son necesarios para publicar las capas actuales en PostGIS/QGIS/Web, porque la geometría del piloto se reconstruye desde `tmp_shapefile.tsv`.

Sí son necesarios si se quiere ejecutar la notebook 03 de inspección de fuentes CAD/DXF. En ese caso, ubicarlos en:

```text
dwg/
dxf/
```

Archivos esperados para la práctica CAD/DXF:

```text
dwg/MONTECARLO_CATASTROORIGINAL.dwg
dwg/Montecarlo_MT.dwg
dwg/Montecarlo_SUMINISTRO_Y_BT.dwg
dxf/MONTECARLO_CATASTROORIGINAL.dxf
dxf/Montecarlo_MT.dxf
```

Si no se tiene el backup original, hay dos alternativas:

1. **Replicar solo desde datos ya exportados**: conseguir una copia de `sqlserver/exports/*.tsv` generada previamente y continuar desde las notebooks **02, 05 y 06**.
2. **Usar una base PostGIS ya cargada**: conseguir un dump de PostgreSQL/PostGIS del esquema `crudo`, `depuracion`, `gis` y `auditoria`, restaurarlo y continuar desde QGIS/GeoServer/Web GIS.

Sin el backup SQL Server o sin exports/dump derivados, no es posible reconstruir los datos reales del laboratorio; solo se puede levantar la infraestructura vacía.

Instalar dependencias:

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
```

Si Jupyter no ve el entorno, registrar el kernel:

```bash
python3 -m ipykernel install --user --name ceml-gis --display-name "CEML GIS"
```

## Variables locales del laboratorio

Antes de levantar servicios, crear el archivo local de variables:

```bash
cp .env.example .env
```

Editar `.env` para cambiar puertos o credenciales. Docker Compose lo lee automáticamente desde la raíz del proyecto; el notebook 01 lo usa mediante `scripts/gis_sqlserver.sh` y los notebooks 04, 05 y 06 lo cargan directamente cuando se ejecutan desde el árbol del repo. El archivo `.env` es local y está ignorado por git; `.env.example` es la plantilla compartida y versionable.

Después de cambiar `POSTGRES_DB`, `POSTGRES_USER` o `POSTGRES_PASSWORD`, regenerar el archivo local de credenciales de pgAdmin:

```bash
./scripts/render_pgadmin_config.sh
```

El archivo `pgadmin-config/pgpass` se genera desde `pgadmin-config/pgpass.template`, queda ignorado por git y usa siempre el host Docker `postgis` con el puerto interno `5432`. No usa `POSTGRES_PORT`, porque ese valor corresponde al puerto publicado para conexiones desde la máquina anfitriona.

## Servicios Docker

Levantar SQL Server, PostGIS, pgAdmin, GeoServer, JupyterLab y la web GIS:

```bash
./scripts/render_pgadmin_config.sh
./scripts/prepare_docker_dirs.sh
docker compose up -d
```

`prepare_docker_dirs.sh` crea y corrige permisos de `sqlserver/data`, `sqlserver/backup`, `sqlserver/exports` y `postgis/data` usando un contenedor Docker temporal como root. Esto evita tener que ejecutar `sudo chmod` en la máquina anfitriona cuando los bind mounts se recrean como `root:root`. El script aplica `chmod 777` solo a esos directorios generados del laboratorio local; no es un criterio para producción.

Si se usa `./scripts/gis_sqlserver.sh up`, esta preparación se ejecuta automáticamente antes de `docker compose up -d`.

La primera vez que se descarga los componentes necesarios puede demorar varios minutos.

### JupyterLab con Docker Compose

JupyterLab también se puede ejecutar desde Docker Compose, sin instalar dependencias Python en la máquina anfitriona:

```bash
./scripts/render_pgadmin_config.sh
./scripts/prepare_docker_dirs.sh
docker compose build jupyter
docker compose up -d jupyter
```

Abrir:

```text
http://localhost:8888/lab?token=ceml
```

Si se cambia `JUPYTER_PORT` en `.env`, usar ese puerto en la URL. Por ejemplo, con `JUPYTER_PORT=8890`, abrir `http://localhost:8890`.

Cuando Jupyter pida token, usar el valor de `JUPYTER_TOKEN` definido en `.env` (`ceml` por defecto).

Dentro de Jupyter, el repositorio está montado en:

```text
/home/jovyan/work
```

Las notebooks del laboratorio están en:

```text
/home/jovyan/work/notebooks/
```

Importante sobre hosts:

- Desde Jupyter dentro de Docker, PostGIS se alcanza como `postgis:5432` y SQL Server como `sqlserver:1433`.
- Desde QGIS, pgAdmin en navegador u otras herramientas de la máquina anfitriona, mantener `localhost` y los puertos publicados en `.env`.
- `COMPOSE_PROJECT_NAME=gis_ceml` mantiene el mismo nombre de proyecto Docker Compose dentro y fuera de Jupyter. Sin ese valor, Compose podría calcular otro nombre desde `/home/jovyan/work` y no encontrar los contenedores esperados.
- Jupyter monta el socket Docker del host (`/var/run/docker.sock`) para que las notebooks puedan ejecutar `docker compose` y los scripts del proyecto desde el contenedor.
- Este acceso al socket Docker da permisos altos sobre Docker en la máquina anfitriona. Usarlo solo en el laboratorio local o en una red de confianza; no exponer Jupyter a internet ni a usuarios no confiables.

Ver estado:

```bash
docker compose ps
```

## Credenciales locales por defecto

Los valores siguientes son los defaults de `.env.example`. Se pueden cambiar en `.env` sin modificar notebooks ni `docker-compose.yml`.

### SQL Server

| Dato | Valor |
|---|---|
| Host local | `localhost` |
| Puerto local | `${SQLSERVER_PORT:-1433}` (`1433` por defecto) |
| Usuario | `SA` |
| Contraseña | `CEML_Admin_2026!` |
| Base esperada | `CEML_GIS` |

### PostGIS

| Dato | Valor |
|---|---|
| Host local | `localhost` |
| Puerto local | `${POSTGRES_PORT:-5432}` (`5432` por defecto) |
| Host desde Docker | `postgis` |
| Puerto desde Docker | `5432` |
| Base | `ceml_gis` |
| Usuario | `ceml` |
| Contraseña | `ceml_admin_2026` |

### pgAdmin

| Dato | Valor |
|---|---|
| URL | <http://localhost:8089> (`PGADMIN_PORT`, `8089` por defecto) |
| Email | `postgis@example.com` |
| Contraseña | `ceml_admin_2026` |

pgAdmin carga automáticamente el servidor **CEML PostGIS** desde `pgadmin-config/servers.json` y usa `pgadmin-config/pgpass` para la contraseña local del laboratorio. Ese `pgpass` es generado e ignorado por git; si se cambian las variables `POSTGRES_*`, ejecutar `./scripts/render_pgadmin_config.sh` antes de iniciar pgAdmin.

### JupyterLab

| Dato | Valor |
|---|---|
| URL directa | <http://localhost:8888/lab?token=ceml> (`JUPYTER_PORT`, `8888` por defecto) |
| Ruta del repo dentro de Jupyter | `/home/jovyan/work` |
| Ruta de notebooks | `/home/jovyan/work/notebooks/` |
| Host PostGIS desde Jupyter | `postgis` |
| Host SQL Server desde Jupyter | `sqlserver` |
| Docker desde Jupyter | Disponible mediante `/var/run/docker.sock` del host |
| Token local | `ceml` (`JUPYTER_TOKEN` por defecto) |

La imagen Jupyter del proyecto incluye Docker CLI y Docker Compose v2 para que las notebooks puedan ejecutar comandos Docker contra el host. El servicio instala `requirements.txt` al iniciar el contenedor. El primer build/arranque puede demorar y requiere conexión a internet para descargar paquetes si la imagen no los tiene. No exponer Jupyter directamente a internet; si se abre desde otra computadora de la red local, cambiar `JUPYTER_TOKEN` en `.env`.

Si dentro de una notebook aparece `permission denied` al ejecutar Docker, recrear el contenedor para que vuelva a detectar el grupo del socket Docker:

```bash
docker compose up -d --force-recreate jupyter
```

### QGIS

Crear una conexión PostgreSQL/PostGIS en QGIS con estos datos:

| Dato | Valor |
|---|---|
| Tipo de conexión | PostgreSQL/PostGIS |
| Host | `localhost` |
| Puerto | `${POSTGRES_PORT:-5432}` (`5432` por defecto) |
| Base de datos | `ceml_gis` |
| Usuario | `ceml` |
| Contraseña | `ceml_admin_2026` |
| Esquema a revisar | `gis` |
| CRS de las capas MT | `EPSG:32721` — WGS 84 / UTM zone 21S |

Importante para QGIS Desktop:

- El campo **Servicio** debe quedar vacío. No escribir `PostGIS` ahí.
- QGIS corre fuera de Docker, por eso debe usar `localhost` y el puerto local publicado por `POSTGRES_PORT` (`5432` por defecto).
- Los contenedores Docker también usan `5432` internamente, por ejemplo pgAdmin o GeoServer conectando al servicio `postgis`.
- Si QGIS muestra pestañas de autenticación, usar la pestaña **Básica** y cargar usuario/contraseña:
  - Usuario: `ceml`
  - Contraseña: `ceml_admin_2026`

Capas finales disponibles para el piloto MT:

| Capa PostGIS | Tipo geométrico | Uso |
|---|---|---|
| `gis.mt_cables` | `LINESTRING` | Trazas de media tensión. |
| `gis.mt_postes` | `POINT` | Postes de media tensión. |
| `gis.mt_elementos` | `POINT` | Elementos puntuales de la red MT. |
| `gis.mt_seccionadores` | `POINT` | Seccionadores MT. |
| `gis.set` | `POINT` | SET del piloto MT. |

Para validar ubicación, agregar un mapa base en QGIS, por ejemplo OpenStreetMap como XYZ Tile:

```text
https://tile.openstreetmap.org/{z}/{x}/{y}.png
```

QGIS reproyecta las capas al vuelo. Las capas están guardadas en PostGIS con `EPSG:32721`; si se muestran sobre un mapa web, QGIS normalmente las reproyecta a `EPSG:3857` para visualización.

### GeoServer

| Dato | Valor |
|---|---|
| URL | <http://localhost:8088/geoserver> (`GEOSERVER_PORT`, `8088` por defecto) |
| URL desde la web local | <http://localhost:8090/geoserver> (`WEBGIS_PORT`, `8090` por defecto) |
| Usuario | `admin` |
| Contraseña | `geoserver` |

GeoServer debe conectarse a PostGIS usando el host Docker `postgis` y el puerto `5432`.
El volumen Docker nombrado `geoserver-data` conserva la configuración publicada entre reinicios.

### Web GIS

| Dato | Valor |
|---|---|
| URL | <http://localhost:8090> (`WEBGIS_PORT`, `8090` por defecto) |
| Cliente web | OpenLayers |
| Servicio GIS esperado | WMS de GeoServer vía proxy nginx `/geoserver` |

La web usa un campo **Workspace** y una lista de capas activables. No escribir `workspace:capa`; con `Workspace = CEML` y varias capas activadas, la web solicita un único WMS combinado, por ejemplo `CEML:mt_cables,CEML:mt_postes`.
El cliente OpenLayers llama a GeoServer con una URL relativa (`/geoserver/...`) servida por `webgis`, para evitar depender de `localhost:8088` desde el navegador y reducir problemas de CORS en uso local.

## Acceso desde otra computadora en la red local

Los puertos publicados por Docker quedan disponibles en la máquina anfitriona. Desde otra computadora de la misma red, reemplazar `localhost` por la IP de la máquina donde corre Docker y usar los puertos definidos en `.env`.

Ejemplo, si la máquina anfitriona tiene IP `192.168.1.50`:

| Servicio | URL o conexión desde otra computadora |
|---|---|
| Web GIS | `http://192.168.1.50:8090` con `WEBGIS_PORT=8090` |
| GeoServer | `http://192.168.1.50:8088/geoserver` con `GEOSERVER_PORT=8088` |
| pgAdmin | `http://192.168.1.50:8089` con `PGADMIN_PORT=8089` |
| JupyterLab | `http://192.168.1.50:8888` con `JUPYTER_PORT=8888` |
| PostGIS para QGIS | host `192.168.1.50`, puerto `5432` con `POSTGRES_PORT=5432`, base `ceml_gis`, usuario `ceml` |

Notas:

- La web usa rutas relativas hacia GeoServer (`/geoserver/...`), por eso funciona mejor accediendo por `http://IP_DEL_HOST:8090` que abriendo GeoServer y la web por hosts distintos.
- Si no se puede acceder desde otra computadora, revisar firewall del sistema operativo y permitir los puertos configurados en `.env` (`8090`, `8088`, `8089`, `8888` y, si se usará QGIS remoto, `5432` por defecto).
- No exponer estos servicios directamente a internet con estas contraseñas. Para acceso externo usar VPN, túnel controlado o un proxy con autenticación.

## Estructura importante

| Ruta | Uso |
|---|---|
| `sqlserver/20211020/` | Fuente original del backup recibido. |
| `dwg/` | Archivos DWG originales. |
| `dxf/` | Archivos DXF originales. |
| `sqlserver/exports/` | TSV generados desde SQL Server; carpeta ignorada por git. |
| `postgis/data/` | Datos locales de PostGIS; carpeta ignorada por git. |
| `pgadmin-config/` | Configuración versionable para registrar PostGIS en pgAdmin. |
| `web/` | Cliente web GIS mínimo con OpenLayers. |
| `notebooks/` | Laboratorio paso a paso. |

## Flujo de visualización web GIS

La arquitectura recomendada separa responsabilidades:

```text
QGIS Desktop → PostGIS → GeoServer → OpenLayers/Web GIS
```

- **QGIS Desktop** edita o consulta las capas finales en PostGIS.
- **PostGIS** mantiene la fuente de verdad.
- **GeoServer** publica las capas PostGIS como servicios OGC, inicialmente WMS.
- **OpenLayers** consume el WMS desde la web local.

Para probar el flujo completo:

1. Levantar servicios:

   ```bash
   ./scripts/prepare_docker_dirs.sh
   docker compose up -d postgis geoserver webgis
   ```

2. Entrar a GeoServer: <http://localhost:8088/geoserver>.
3. Crear un workspace, por ejemplo `CEML`.
4. Crear un store PostGIS con estos datos:

   | Dato | Valor |
   |---|---|
   | Host | `postgis` |
   | Puerto | `5432` |
   | Base | `ceml_gis` |
   | Esquema | `gis` |
   | Usuario | `ceml` |
   | Contraseña | `ceml_admin_2026` |

5. Publicar una tabla final con geometría real desde el esquema `gis`, por ejemplo `gis.mt_cables` o `gis.mt_postes`.
6. Abrir la web: <http://localhost:8090>.
7. Cargar una o varias capas desde la lista, por ejemplo `Workspace = CEML` y `mt_cables` activada.

Importante: la web no debe consumir tablas crudas. Primero hay que construir capas finales con geometría PostGIS y SRID correcto en el esquema `gis`.

## Configurar GeoServer para publicar PostGIS

La primera vez GeoServer aparece vacío: `0 workspaces`, `0 stores`, `0 layers`. Hay que crear un workspace, conectar el almacén PostGIS y publicar las capas del esquema `gis`.

Entrar a GeoServer:

```text
http://localhost:8088/geoserver
```

Credenciales:

```text
Usuario: admin
Contraseña: geoserver
```

Los avisos sobre contraseña maestra y contraseña de administrador aparecen porque es un laboratorio local con credenciales por defecto. Para producción hay que cambiarlas; para esta práctica se pueden ignorar.

### 1. Crear espacio de trabajo

En el menú izquierdo:

```text
Datos → Espacios de trabajo → Agregar nuevo espacio de trabajo
```

Completar:

| Campo | Valor |
|---|---|
| Nombre | `CEML` |
| URI del espacio de nombres | `http://ceml.local/gis` |

Guardar.

### 2. Crear almacén PostGIS

En el menú izquierdo:

```text
Datos → Almacenes de datos → Agregar nuevo almacén
```

Elegir:

```text
PostGIS
```

Completar los datos generales:

| Campo | Valor |
|---|---|
| Espacio de trabajo | `ceml` |
| Nombre del origen de datos | `ceml_postgis` |
| Descripción | `Capas GIS CEML desde PostGIS` |

Completar la conexión:

| Campo | Valor |
|---|---|
| host | `postgis` |
| port | `5432` |
| database | `ceml_gis` |
| schema | `gis` |
| user | `ceml` |
| passwd | `ceml_admin_2026` |

Importante: en GeoServer se usa `postgis:5432`, no `localhost:5432`, porque GeoServer corre dentro de Docker y se conecta por la red interna de Compose.

Guardar.

### 3. Publicar capas

Después de guardar el almacén, GeoServer muestra las tablas disponibles para publicar.

Publicar estas capas:

| Tabla PostGIS | Nombre de capa GeoServer | Tipo |
|---|---|---|
| `gis.mt_cables` | `mt_cables` | líneas |
| `gis.mt_postes` | `mt_postes` | puntos |
| `gis.mt_elementos` | `mt_elementos` | puntos |
| `gis.mt_seccionadores` | `mt_seccionadores` | puntos |
| `gis.set` | `set` | puntos |

Para cada capa:

1. Hacer clic en **Publicar**.
2. Verificar que el CRS nativo sea `EPSG:32721`.
3. En la sección de límites:
   - usar **Calcular desde los datos**;
   - usar **Calcular desde los límites nativos**.
4. Guardar.

### 4. Probar capa en GeoServer

En el menú izquierdo:

```text
Datos → Previsualización de capas
```

Buscar, por ejemplo:

```text
CEML:mt_cables
```

Abrir la previsualización OpenLayers.

### 5. Probar desde la web local

Abrir:

```text
http://localhost:8090
```

Usar:

| Campo | Valor |
|---|---|
| Workspace | `CEML` |
| Capas activas | `mt_cables`, `mt_postes`, `mt_elementos`, `mt_seccionadores`, `set` |

Presionar:

```text
Actualizar capas WMS
```

Si se quiere ocultar una capa, desmarcarla en la lista y volver a presionar **Actualizar capas WMS**.

## Flujo recomendado de notebooks

Ejecutar en orden:

1. `notebooks/01_extraccion_sqlserver.ipynb`
   - Levanta/restaura SQL Server.
   - Exporta tablas del piloto MT.
   - Foco: `TMP_SHAPEFILE`, `Objetos_Red`, `SET`, `seccionadores`, `MT_cables`.

2. `notebooks/02_analisis_datos_exportados.ipynb`
   - Analiza TSV exportados.
   - Revisa `TMP_SHAPEFILE.Datos_Objeto`.
   - Evalúa el cruce `Objetos_Red` ↔ `TMP_SHAPEFILE`.

3. `notebooks/03_analisis_cad_dxf.ipynb`
   - Analiza CAD/DXF originales.
   - Prioriza `dxf/Montecarlo_MT.dxf`.
   - Documenta capas MT candidatas.

4. `notebooks/04_diseno_carga_postgis.ipynb`
   - Diseña la carga PostGIS.
   - Define esquemas `crudo`, `depuracion`, `gis`, `auditoria`.
   - Mantiene la migración acotada al piloto MT.

5. `notebooks/05_creacion_postgis_carga_piloto_mt.ipynb`
   - Crea extensión PostGIS.
   - Crea esquemas.
   - Carga TSV crudos del piloto MT en `crudo`.
   - Registra auditoría de carga.

6. `notebooks/06_reconstruccion_geometrias_mt_qgis.ipynb`
   - Reconstruye geometrías desde `crudo.tmp_shapefile`.
   - Usa `Datos_Objeto` para interpretar entidades CAD (`INSERT`, `CIRCLE`, `LINE`, `LWPOLYLINE`).
   - Crea `depuracion.geometrias_cad_mt` como tabla intermedia de control.
   - Publica capas finales en el esquema `gis`.
   - Usa SRID `32721` para que QGIS ubique las capas en Montecarlo, Misiones.
   - Genera las capas `gis.mt_cables`, `gis.mt_postes`, `gis.mt_elementos`, `gis.mt_seccionadores` y `gis.set`.

## Alcance actual del piloto

El primer objetivo no es migrar todo. El piloto se concentra en:

- `dxf/Montecarlo_MT.dxf`
- `TMP_SHAPEFILE`
- `Objetos_Red`
- `SET`
- `seccionadores`
- `MT_cables`

Quedan fuera de la primera geometría:

- BT
- suministros
- alumbrado
- reclamos
- catastro completo
- transformadores derivados desde SET

## Notas para problemas comunes

### PostGIS no conecta

Confirmar que se usa el puerto local correcto definido por `POSTGRES_PORT`:

```text
localhost:5432  # default con POSTGRES_PORT=5432
```

Dentro de Docker, pgAdmin debe conectarse a:

```text
postgis:5432
```

### pgAdmin no arranca por permisos

El estado de pgAdmin usa el volumen Docker nombrado `pgadmin-data`. Si quedó un contenedor viejo con montaje anterior, recrearlo:

```bash
docker compose rm -f pgadmin
docker compose up -d pgadmin
```

### Falta `psycopg` en Jupyter

Instalar dependencias y reiniciar kernel:

```bash
source .venv/bin/activate
python3 -m pip install -r requirements.txt
```

## Apagar servicios

```bash
docker compose down
```

Para eliminar también volúmenes Docker nombrados de Compose, usar con cuidado:

```bash
docker compose down -v
```

Ese comando no borra los directorios bind-mounted del proyecto, como `sqlserver/data/`, `sqlserver/backup/`, `sqlserver/exports/` o `postgis/data/`. Para un reset local completo del laboratorio, borrar esos datos generados explícitamente y volver a preparar permisos:

```bash
rm -rf sqlserver/data postgis/data sqlserver/backup/*.bak sqlserver/exports/*
./scripts/prepare_docker_dirs.sh
./scripts/render_pgadmin_config.sh
docker compose up -d sqlserver postgis pgadmin geoserver webgis
```

No usar `docker compose down --rmi` ni `docker system prune` si se quieren conservar las imágenes descargadas.
