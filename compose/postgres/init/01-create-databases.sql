-- =============================================================================
-- Inicialización de bases de datos en Postgres compartido
-- =============================================================================
-- Se ejecuta automáticamente la primera vez que Postgres arranca,
-- gracias al volumen montado en /docker-entrypoint-initdb.d/

CREATE DATABASE n8n;
CREATE DATABASE listmonk;
CREATE DATABASE docuseal;
CREATE DATABASE postiz;
CREATE DATABASE umami;
CREATE DATABASE vikunja;

-- El usuario por defecto (POSTGRES_USER) ya tiene permisos completos
-- sobre todas las DBs porque es el superuser definido al inicializar
-- el cluster. No se necesita GRANT adicional.
