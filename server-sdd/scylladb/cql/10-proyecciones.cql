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

CREATE TABLE IF NOT EXISTS arify_cqrs.si_fin_agencia_cce (
    idAgenciaCCE int PRIMARY KEY,
    cCodigoRegistro text,
    cNumeroEntidad text,
    cNumeroOficina text,
    cNumeroOficinaPlaza text,
    cUbigeoPlazaCAnexo text,
    cUbigeoPlazaCTransf text,
    cNombreOficina text,
    cNombreDomicilioOfi text,
    cNombreLocalidad text,
    cCodigoPostDistrito text,
    cNombrePlaza text,
    cTipoOficina text,
    cUbigeoINEI text,
    cPlazaExclusiva text,
    cPrefTelef text,
    cNumTelef1 text,
    cNumTelef2 text,
    cNumTelefFax text,
    cNumTelefCentral text,
    cNumExtension text,
    cMotivoActualizacion text,
    cFechaActualizacion text,
    lVigente boolean
);

CREATE TABLE IF NOT EXISTS arify_cqrs.si_fin_canal_cce (
    idCanalCCE int PRIMARY KEY ,
    cCanalCCE text,
    cCodigo text,
    lVigente boolean
);

CREATE TABLE IF NOT EXISTS arify_cqrs.si_fin_kardex (
    IdKardex int PRIMARY KEY,
    dFechaOpe date,
    dFecHoraOpe timestamp,
    idProducto int,
    idCanal int,
    idMoneda int,
    IdUsuario int,
    idCuenta int,
    idTipoOperacion int,
    idEstadoKardex int,
    IdKardexExtorno int,

    nMontoOperacion decimal,
    nMontoCapital decimal,
    nMontoInteres decimal,
    nMontoMora decimal,
    nMontoOtros decimal,
    nITFNormal decimal,

    idTipoIngresoEgreso int,
    IdMotivoExt int,
    cObservaExt text,
    idAgeSaldo int,
    idAgeOpera int,
    idModulo int,
    idTipoAfeCaj int,
    nAtrasoPago smallint,
    idTipoPago int,
    idTipoPersona int,
    idCliAfeITF int,
    cNroDNI text,
    cNomCliente text,
    cDireccion text,
    idKardexRelacionado int,
    cObservacion text,
    nMontoIntComp decimal,
    idMotivoOperacion int,
    idEstablecimiento int,
    idTipoTrxOpe int,
    dFechaValor date
);