# Guía para preparar una presentación del proyecto en NotebookLM

Este documento indica qué archivos cargar en NotebookLM y cómo pedirle que genere una presentación sobre el proyecto de migración GIS CEML.

El objetivo de la presentación es mostrar el proceso completo: recuperación de información desde el GIS viejo, migración a PostGIS, reconstrucción de geometrías, consultas espaciales y publicación mediante herramientas web.

## Objetivo de la presentación

La presentación debe explicar cómo el proyecto transforma información GIS heredada en una plataforma moderna, reproducible y consultable.

El relato principal es:

1. Existía información GIS en un sistema viejo basado en SQL Server y archivos CAD/DXF.
2. Se recuperó el backup del sistema anterior en un entorno Docker.
3. Se exportaron tablas relevantes para un piloto de media tensión.
4. Se analizaron los datos exportados y los archivos CAD/DXF.
5. Se diseñó una migración controlada hacia PostgreSQL/PostGIS.
6. Se cargaron datos crudos, se depuraron y se reconstruyeron geometrías.
7. Se publicaron capas GIS finales.
8. Se habilitó la visualización mediante QGIS, pgAdmin, GeoServer y una web con OpenLayers.

## Archivos principales para cargar en NotebookLM

Cargar estos archivos como fuentes principales:

```text
README.md
notebooks/01_extraccion_sqlserver.ipynb
notebooks/02_analisis_datos_exportados.ipynb
notebooks/03_analisis_cad_dxf.ipynb
notebooks/04_diseno_carga_postgis.ipynb
notebooks/05_creacion_postgis_carga_piloto_mt.ipynb
notebooks/06_reconstruccion_geometrias_mt_qgis.ipynb
notebooks/07_consultas_espaciales_mt.ipynb
consultas.txt
docker-compose.yml
web/index.html
web/nginx.conf
```

Estos archivos son suficientes para que NotebookLM entienda:

- el contexto general del proyecto;
- el proceso realizado en cada notebook;
- la arquitectura Docker;
- el flujo desde SQL Server hacia PostGIS;
- la reconstrucción de geometrías;
- las consultas espaciales;
- la publicación y visualización web.

## Archivos opcionales de soporte técnico

Agregar estos archivos solo si se quiere que NotebookLM tenga más detalle sobre automatización, configuración y entorno de ejecución:

```text
scripts/gis_sqlserver.sh
scripts/prepare_docker_dirs.sh
scripts/render_pgadmin_config.sh
scripts/start_jupyter_lab.sh
pgadmin-config/servers.json
requirements.txt
```

Estos archivos ayudan a explicar cómo se preparan los servicios, cómo se restaura SQL Server, cómo se configura pgAdmin y cómo se levanta Jupyter.

## Archivos y carpetas que NO conviene cargar

No cargar estos elementos en NotebookLM:

```text
.git/
.venv/
.env
pgadmin-config/pgpass
notebooks/.ipynb_checkpoints/
sqlserver/data/
postgis/data/
backup/
sqlserver/backup/
dwg/*.dwg
sqlserver/exports/*.tsv
```

Motivos:

- contienen datos locales o generados durante la ejecución;
- pueden incluir credenciales o configuraciones sensibles;
- son archivos pesados o binarios;
- agregan ruido al análisis;
- no son necesarios para explicar el proceso del proyecto.

Los archivos TSV exportados solo deberían cargarse si se quiere mostrar muestras concretas de datos reales. Para una presentación general, es mejor evitarlos.

## Rol de las siete notebooks

| Orden | Archivo | Rol en el proceso |
|---:|---|---|
| 1 | `notebooks/01_extraccion_sqlserver.ipynb` | Restaura el backup del GIS viejo, explora SQL Server y exporta tablas relevantes. |
| 2 | `notebooks/02_analisis_datos_exportados.ipynb` | Analiza los TSV exportados, clasifica tablas y revisa relaciones entre datos. |
| 3 | `notebooks/03_analisis_cad_dxf.ipynb` | Inspecciona archivos CAD/DXF e identifica capas útiles para el piloto. |
| 4 | `notebooks/04_diseno_carga_postgis.ipynb` | Define el diseño de carga a PostGIS, esquemas y estrategia de auditoría. |
| 5 | `notebooks/05_creacion_postgis_carga_piloto_mt.ipynb` | Crea la estructura PostGIS y carga datos crudos del piloto. |
| 6 | `notebooks/06_reconstruccion_geometrias_mt_qgis.ipynb` | Reconstruye geometrías y publica capas finales para QGIS/PostGIS. |
| 7 | `notebooks/07_consultas_espaciales_mt.ipynb` | Ejecuta consultas espaciales para validar y explotar la información migrada. |

## Rol de los servicios Docker

| Servicio | Rol |
|---|---|
| `sqlserver` | Permite restaurar el backup del sistema GIS viejo y exportar tablas. |
| `postgis` | Base de datos espacial destino; almacena datos crudos, depurados y capas finales. |
| `pgadmin` | Interfaz web para administrar PostgreSQL/PostGIS. |
| `geoserver` | Publica capas PostGIS como servicios geográficos consumibles por aplicaciones. |
| `webgis` | Aplicación web con OpenLayers para visualizar capas desde el navegador. |
| `jupyter` | Entorno reproducible para ejecutar las notebooks del proceso. |

## Narrativa sugerida

Usar esta línea narrativa para que la presentación sea clara:

1. **Problema inicial:** información GIS heredada, dispersa y difícil de consultar.
2. **Recuperación controlada:** restauración del backup viejo en SQL Server dentro de Docker.
3. **Exportación:** selección y exportación de tablas clave para el piloto.
4. **Análisis:** revisión de datos tabulares y fuentes CAD/DXF.
5. **Diseño:** separación entre datos crudos, depuración, capas finales y auditoría.
6. **Migración:** carga en PostGIS y normalización progresiva.
7. **Reconstrucción espacial:** conversión de información CAD/tabular en geometrías GIS.
8. **Validación:** consultas espaciales y revisión en QGIS.
9. **Publicación:** GeoServer y web con OpenLayers.
10. **Resultado final:** una base espacial moderna, auditable y consultable desde herramientas web.

## Prompt recomendado para NotebookLM

Copiar y pegar este prompt en NotebookLM después de cargar las fuentes:

```text
Necesito crear una presentación ejecutiva y técnica sobre este proyecto GIS CEML.

El objetivo es explicar el proceso completo:

1. Recuperación de información desde un sistema GIS heredado basado en SQL Server y archivos CAD/DXF.
2. Restauración del backup viejo en un entorno Docker reproducible.
3. Exportación y análisis de tablas relevantes.
4. Diseño de una migración controlada hacia PostgreSQL/PostGIS.
5. Carga de datos crudos, depuración y reconstrucción de geometrías.
6. Publicación de capas GIS finales.
7. Uso de herramientas adicionales como QGIS, pgAdmin, GeoServer y una web con OpenLayers para visualizar la información desde navegador.
8. Explicación detallada del rol de las 7 notebooks.
9. Explicación del rol de cada servicio de docker-compose.

Generá una presentación clara, ordenada y narrativa.

Debe mostrar el problema inicial, la estrategia de recuperación, el piloto de media tensión Montecarlo, la arquitectura técnica, el flujo de datos y el valor final del proyecto.

Usá un tono profesional, apto para explicar el proyecto a responsables técnicos y no técnicos.
```

## Estructura sugerida de slides

1. **Migración GIS CEML: de sistema heredado a PostGIS/Web GIS**
2. **Contexto y desafío:** SQL Server viejo, CAD/DXF y datos no normalizados.
3. **Objetivo del proyecto:** recuperar, ordenar, georreferenciar y publicar información.
4. **Arquitectura del laboratorio:** Docker Compose y servicios principales.
5. **Recuperación del sistema viejo:** backup, restore y exportación.
6. **Piloto de media tensión Montecarlo:** alcance acotado para validar el método.
7. **Flujo de notebooks:** explicación del proceso paso a paso.
8. **Diseño PostGIS:** esquemas `crudo`, `depuracion`, `gis` y `auditoria`.
9. **Reconstrucción de geometrías:** interpretación de datos CAD y publicación espacial.
10. **Capas finales:** cables, postes, elementos, seccionadores y SET.
11. **Visualización:** QGIS, GeoServer y Web GIS.
12. **Consultas espaciales:** proximidad, buffers, intersecciones y clustering.
13. **Resultados:** trazabilidad, reproducibilidad y publicación web.
14. **Próximos pasos:** ampliar la migración a nuevas capas y procesos operativos.

## Recomendación práctica

Primero cargar solo las fuentes principales. Si NotebookLM genera una presentación demasiado general, agregar los archivos opcionales de soporte técnico.

Evitar cargar datos pesados, backups, carpetas de ejecución local o archivos con credenciales. La presentación debe apoyarse en la documentación, las notebooks, la arquitectura y el flujo de trabajo, no en el volumen completo de datos.
