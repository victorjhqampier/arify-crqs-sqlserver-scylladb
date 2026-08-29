# POC CQRS con CDC

## Arquitectura
- Implementar el flujo `SQL Server (CDC) -> Debezium SQL Server Source Connector (Kafka Connect) -> Kafka (KRaft) -> mecanismo de proyeccion -> ScyllaDB (CQL)` para CQRS.

| Componente | Funcion | Regla clave |
| --- | --- | --- |
| SQL Server | Modelo de escritura y fuente CDC. | Escuchar solo `SI_FinKardex`, `SI_FinAgenciaCCE` y `SI_FinCanalCCE`. |
| Kafka Connect Debezium | Ejecuta exclusivamente Debezium Source. | Worker separado para aislar `SQL Server CDC -> Kafka`. |
| Kafka Connect Sink | Ejecuta exclusivamente el Sink CQL. | Worker separado para aislar `Kafka -> ScyllaDB`. |
| Debezium SQL Server Source | Lee CDC de SQL Server y publica eventos. | Es un plugin de Kafka Connect, no un servicio independiente. |
| Kafka con KRaft | Almacena y distribuye eventos; KRaft gestiona metadatos. | Kafka no escribe en ScyllaDB y no se debe desplegar ZooKeeper. |
| Mecanismo de proyeccion | Consume eventos Kafka y crea los modelos de lectura. | El valor predeterminado es Kafka Connect Sink; elegir otro solo si la proyeccion lo requiere. |
| ScyllaDB | Almacena los modelos de lectura mediante CQL. | Disenar tablas por consulta; no replicar literalmente el esquema SQL Server. |

- SQL Server y sus tres tablas fuente ya existen: los scripts solo validan, crean el acceso Debezium y habilitan CDC; nunca crean ni alteran el esquema de escritura.
- Docker Compose es la definicion de despliegue. Las configuraciones heredadas validadas deben conservar imagen, nombre, hostname, reinicio, puertos, variables, limites y bind mounts; no sustituir rutas de datos por volumenes nombrados ni introducir parametros del motor sin validacion.

## Tecnologias Seleccionadas
- Coordinacion Kafka: KRaft.
- Serializacion de eventos: JSON sin esquema; no se requiere Schema Registry.
- Imagen Kafka: `apache/kafka`; usar version compatible con KRaft (3.7+ o 4.x).
- Imagen Kafka Connect: `confluentinc/cp-kafka-connect`; montar plugins de Debezium SQL Server y DataStax Cassandra Sink.
- Sink CQL: DataStax Cassandra Sink Connector; compatible con ScyllaDB via protocolo CQL.

## Mecanismos de Proyeccion
- Elegir y documentar un mecanismo antes de implementar cada proyeccion.
- Por defecto: usar un Kafka Connect Sink compatible con ScyllaDB/CQL directamente desde Kafka hacia ScyllaDB; no agregar un servicio o aplicacion intermedia.
- El camino predeterminado usa dos conectores en Kafka Connect: Debezium SQL Server Source Connector y el Sink compatible con ScyllaDB/CQL.
- Servicio propio: ventaja: desnormalizaciones y reglas complejas. Desventaja: requiere codigo, despliegue y operacion.
- Kafka Streams: ventaja: estado, joins y agregaciones. Desventaja: aumenta la complejidad operativa.
- Kafka Connect Sink: ventaja: mapeos directos sin aplicacion intermedia. Desventaja: limitado para transformaciones complejas.

## Estructura del Repositorio
- Cada componente tiene su propia carpeta para sus scripts, configuracion, variables y archivos montados.

```text
server-hdd/
  sql-server/                     # SQL Server y su preparacion CDC manual
    docker-compose.yml
    init/                         # Scripts SQL para habilitar CDC en las tablas
  kafka/                          # Broker KRaft y topicos CDC
    docker-compose.yml
    topics.env.example             # Contrato sin secretos de nombres de topicos
  kafka-connect-debezium/         # Worker Connect y plugin Debezium SQL Server
    docker-compose.yml
    plugins/
    connectors/                   # JSON Source registrado via API REST en 8083
  kafka-connect-sink/             # Worker Connect y plugin DataStax Cassandra Sink
    docker-compose.yml
    plugins/
    connectors/                   # Plantilla Sink registrada via API REST en 8084
server-sdd/
  scylladb/                       # ScyllaDB, esquemas CQL manuales y valores del componente
    docker-compose.yml
    cql/                          # Scripts CQL ordenados por prefijo numerico
      00-keyspace.cql             # CREATE KEYSPACE arify_cqrs
      10-proyecciones.cql         # Tablas de proyeccion para las tres tablas CDC
```

- `server-hdd/kafka-connect-debezium/register-debezium.sh` registra solo Debezium; `server-hdd/kafka-connect-sink/register-sink.sh` registra solo el Sink.

## Despliegue Compose
- Mantener un Compose por componente: `sql-server/`, `kafka/`, `kafka-connect-debezium/`, `kafka-connect-sink/` y `scylladb/`.
- Cada Compose tiene red, variables y archivos propios; no puede usar `depends_on`, DNS interno, bind mounts ni `.env` de otro componente.
- Los componentes se integran solo por IP/DNS, puertos y contratos de topicos configurables; deben poder moverse a repositorios y servidores distintos.
- SQL Server y ScyllaDB se inician solos; sus restauraciones, esquemas, roles y CDC se aplican manualmente despues del bootstrap. Kafka inicia solo el broker; los topicos se crean manualmente despues de validar que responde.
- `kafka-connect-debezium` recibe endpoints SQL Server y Kafka; `kafka-connect-sink` recibe endpoints Kafka y ScyllaDB en sus `.env` propios.

## Orden de Arranque

| Paso | Servicio | Healthcheck | Condicion para continuar |
| --- | --- | --- | --- |
| 1 | ScyllaDB | `docker compose ps` | Contenedor ScyllaDB en estado `Up`. |
| 2 | Bootstrap CQL manual | Cambia `cassandra/cassandra`, ejecuta `00-keyspace.cql`, `10-proyecciones.cql` y `90-bootstrap-roles.cql` | Keyspace, tablas y roles existen. |
| 3 | SQL Server | Restaura `db_transaction.bak` como `my_db_transaction`, habilita SQL Server Agent y ejecuta `init-cdc.sh` | SQL responde y CDC esta habilitado. |
| 4 | Kafka | `kafka-broker-api-versions.sh --bootstrap-server localhost:9092` | Broker responde y los topicos CDC e internos se crean manualmente. |
| 5 | Kafka Connect Debezium | `curl -s http://localhost:8083/connectors` | API REST responde. |
| 6 | Registrar Debezium y validar Kafka | status del conector y offset del topico CDC | Task RUNNING y offset CDC mayor a `0`. |
| 7 | Kafka Connect Sink | `curl -s http://localhost:8084/connectors` | API REST responde. |
| 8 | Registrar Sink y validar ScyllaDB | status del conector y consulta CQL | Task RUNNING y evento manual escrito en ScyllaDB. |

- SQL Server y Kafka pueden arrancar en paralelo, pero sus Compose no se esperan entre si.
- Kafka Connect Debezium se inicia despues de configurar SQL Server y Kafka; el Sink no se inicia hasta que ScyllaDB tenga el keyspace `arify_cqrs`, las tablas de proyeccion y Debezium haya publicado al menos un evento.
- `my_db_transaction` es el nombre fijo de la base SQL Server capturada por Debezium. Cualquier backup de prueba se restaura con ese nombre; no crear una base vacia antes del restore ni cambiar el nombre de base de los conectores.
- Los nombres logicos del backup pueden variar. Obtenerlos con `RESTORE FILELISTONLY` y usarlos solo en las clausulas `MOVE` del restore.

## Kafka KRaft
- Para esta POC, el unico broker Kafka ejecuta los roles `broker,controller`; no crear un servicio de controlador separado.
- Configurar `node.id`, listeners de broker y controlador, `controller.quorum.voters`, y un `cluster.id` generado una sola vez.
- Formatear el almacenamiento KRaft solo antes del primer arranque y persistir sus logs y metadatos para no reinicializar el cluster.

## Limites de Recursos POC
- Aplicar limites con `cpus` y `mem_limit`; no depender solo de `deploy.resources`.
- SQL Server: conservar su configuracion validada (`mem_limit: 3g`, sin limite CPU adicional) hasta validar un cambio de capacidad en el servidor destino.
- Kafka y cada worker Kafka Connect: maximo 1 CPU y 1 GB; limitar cada heap JVM Connect a 512 MB.
- ScyllaDB: usar `scylladb/scylla:5.4.9` y conservar su configuracion validada (`--smp 2`, `--memory 2G`, `--overprovisioned 1`) hasta validar un cambio de capacidad en el servidor destino.
- `server-hdd` requiere aproximadamente 6 GB para sus contenedores al ejecutar ambos workers y `server-sdd` 2.5 GB, sin contar el sistema operativo.

## Kafka POC
- Aplicar a los topicos CDC `retention.ms=300000`, `segment.ms=60000` y una revision de retencion cada 60 segundos.
- Crear los topicos CDC con esa configuracion antes de registrar el Source Connector; no depender de los valores por defecto del broker.
- No aplicar la retencion de cinco minutos a los topicos internos de Kafka Connect ni al historial de esquema de Debezium. Los topicos internos Connect deben ser compactados; el historial Debezium usa `cleanup.policy=delete` y `retention.ms=-1` porque puede contener registros sin key.

## Registro de Conectores y Puertos
- Guardar el JSON Source en `server-hdd/kafka-connect-debezium/connectors/` y la plantilla Sink en `server-hdd/kafka-connect-sink/connectors/`; registrar cada uno solo cuando sus dependencias esten sanas.
- Restringir las API REST de Kafka Connect Debezium (`8083`) y Sink (`8084`) a administracion; Kafka (`9092`) solo requiere acceso de sus clientes; el listener controlador KRaft no se expone.
- SQL Server usa `1433`; ScyllaDB debe exponer CQL (`9042`) y permitir acceso desde `server-hdd`.

## Convencion de Topicos
- Debezium nombra los topicos como `{topic.prefix}.{database}.{schema}.{table}`.
- Ejemplo: si `topic.prefix=sqlserver` y la base es `my_db_transaction`, el topico para `dbo.SI_FinKardex` sera `sqlserver.my_db_transaction.dbo.SI_FinKardex`.
- El DataStax Sink debe mapear cada topico a la tabla CQL correspondiente en el keyspace `arify_cqrs`.

## Configuracion de Conectores

### Debezium SQL Server Source (propiedades minimas)
- `connector.class`: `io.debezium.connector.sqlserver.SqlServerConnector`
- `database.hostname`, `database.port`, `database.user`, `database.password`
- `database.names`: base de datos a capturar
- `table.include.list`: `dbo.SI_FinKardex,dbo.SI_FinAgenciaCCE,dbo.SI_FinCanalCCE` para los identificadores CDC comparados por Debezium en esta POC.
- `topic.prefix`: prefijo para los topicos
- `schema.history.internal.kafka.topic`: topico para historial de esquema durable no compactado (`cleanup.policy=delete`, `retention.ms=-1`)
- `schema.history.internal.kafka.bootstrap.servers`

### DataStax Cassandra Sink (propiedades minimas)
- `connector.class`: `com.datastax.oss.kafka.sink.CassandraSinkConnector`
- `contactPoints`: IP o DNS de ScyllaDB
- `loadBalancing.localDc`: datacenter local (por defecto `datacenter1`)
- `topics`: lista de topicos a consumir
- `topic.{topic}.{keyspace}.{table}.mapping`: mapeo de campos del evento a columnas CQL

## Consideraciones Criticas
- Cinco minutos de retencion no permiten recuperarse de una caida prolongada del Sink: medir el lag y definir reconstruccion mediante snapshot de Debezium o recarga desde SQL Server.
- El Sink debe tolerar reintentos, duplicados y borrados con escrituras idempotentes en ScyllaDB.
- CDC requiere una edicion de SQL Server compatible, distinta de Express, y SQL Server Agent habilitado; validar ambos antes de desplegar Debezium.
- Los campos del origen no se configuran en Debezium; se usan solo para disenar CQL y los mapeos del Sink a partir del DDL y consultas reales.
- ScyllaDB usa `PasswordAuthenticator` y `CassandraAuthorizer`; el Sink y cada microservicio usan roles CQL propios con privilegios minimos, nunca el superusuario `cassandra`.
- No versionar contraseñas: sustituir la clave en texto plano de la referencia SQL Server por secretos o variables de entorno no versionadas en Compose.
- Aplicar los esquemas CQL y esperar la salud de los servicios antes de registrar o iniciar el Sink.
- Persistir los datos de SQL Server, los logs y metadatos KRaft de Kafka, y los datos de ScyllaDB en volumenes.
- Debezium realiza un snapshot inicial por defecto (`snapshot.mode=initial`); si las tablas SQL Server tienen datos, el snapshot los captura antes del streaming CDC. Para omitir el snapshot, usar `snapshot.mode=no_data`.

## Reglas Operativas
- Usar Docker Compose como definicion principal de despliegue; Podman Compose es una alternativa aceptable.
- Mantener Compose, configuracion de conectores, esquemas CQL y valores por entorno en archivos separados y montados por cada componente, sin rutas relativas hacia otro componente.
- Cambiar Compose solo despues de validar el impacto en los servidores destino.
- No ejecutar contenedores directamente en este servidor; validar en los servidores destino mediante SSH.
- Los servicios nuevos usan `restart: unless-stopped`, `TZ=America/Lima` y la red Compose por defecto; no declarar redes personalizadas. Los componentes existentes conservan su reinicio configurado.

## Documentacion Interna
- Incluir comentarios explicativos en componentes clave: archivos Compose, JSON de conectores, scripts de inicializacion CDC y esquemas CQL.
- No documentar exhaustivamente todo el proyecto; priorizar los puntos de integracion y decisiones no obvias.
- Cada archivo clave debe tener al menos una linea de comentario que explique su proposito; para JSON, usar un archivo Markdown acompanante porque JSON no admite comentarios.
