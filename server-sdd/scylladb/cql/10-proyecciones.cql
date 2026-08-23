-- Placeholder read models and Sink mappings; replace columns and keys from real queries and source DDL.
CREATE TABLE IF NOT EXISTS arify_cqrs.fin_kardex_por_id (
    kardex_id bigint PRIMARY KEY,
    agencia_codigo text,
    canal_codigo text,
    fecha_movimiento timestamp,
    monto decimal,
    estado text,
    actualizado_en timestamp
);

CREATE TABLE IF NOT EXISTS arify_cqrs.fin_agencia_por_codigo (
    agencia_codigo text PRIMARY KEY,
    nombre text,
    estado text,
    actualizado_en timestamp
);

CREATE TABLE IF NOT EXISTS arify_cqrs.fin_canal_por_codigo (
    canal_codigo text PRIMARY KEY,
    nombre text,
    estado text,
    actualizado_en timestamp
);
