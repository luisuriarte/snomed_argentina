-- =============================================================================
-- SNOMED CT Edición Argentina - OpenEMR
-- 01_esquema.sql  ::  crea las tablas de trabajo y las tablas auxiliares
-- =============================================================================
--
-- Edición de referencia: Argentina 2026-08-20 (Release Note 20260820).
--
-- QUÉ HACE ESTE SCRIPT
--   Borra y vuelve a crear las tablas `sct2_*`. No toca ninguna tabla clínica
--   de OpenEMR (patient_data, forms, prescriptions, codes, ...). Las tablas
--   sct2_* son un depósito de terminología: el único código de OpenEMR que las
--   usa es library/standard_tables_capture.inc.php, que no se ejecuta si la
--   carga se hace a mano como se describe en el readme.
--
-- ORDEN DE EJECUCIÓN
--   01_esquema.sql   -> este archivo
--   02_carga.sql     -> generado con scripts/generar_carga.php
--   03_postcarga.sql -> índices, tablas derivadas y vistas
--   04_codigos_opcional.sql (opcional)
--   99_verificacion.sql
--
-- DECISIÓN DE RENDIMIENTO
--   Las tablas se crean SOLO con su clave primaria. Los índices secundarios se
--   agregan en 03_postcarga.sql, después de la carga. Cargar 6,4 millones de
--   filas del refset de idioma con los índices puestos tarda varias veces más
--   que cargar en una tabla limpia y construir los índices al final.
--
-- RESPALDO ANTES DE EJECUTAR EN UN SERVIDOR CON DATOS
--   DROP TABLE/sct2_* es destructivo. Si tiene una carga anterior que quiere
--   conservar:
--     mysqldump --single-transaction openemr sct2_concept sct2_description \
--       sct2_relationship sct2_statedrelationship sct2_textdefinition \
--       sct2_identifier sct2_refset_simple sct2_refset_language \
--       > respaldo_sct2_$(date +%F).sql
--
-- REQUISITOS
--   MySQL 8.0.14+ o MariaDB 10.4+ (se usan funciones de ventana ROW_NUMBER).
--   utf8mb4. El término más largo de esta edición mide 482 bytes, por eso
--   sct2_description.term es VARCHAR(1024) y no VARCHAR(255).
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- Vistas del proyecto anterior (se vuelven a crear en 03_postcarga.sql)
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v_sct_refset_miembro;
DROP VIEW IF EXISTS v_sct_refset_resumen;
DROP VIEW IF EXISTS v_sct_generico_marca;
DROP VIEW IF EXISTS v_sct_generico;
DROP VIEW IF EXISTS v_sct_marca;
DROP VIEW IF EXISTS v_sct_medicamento;
DROP VIEW IF EXISTS v_sct_eno;
DROP VIEW IF EXISTS v_sct_cie10;
DROP VIEW IF EXISTS v_sct_practica_lab;
DROP VIEW IF EXISTS v_sct_practica_imagen;
DROP VIEW IF EXISTS v_sct_odonto_dx;
DROP VIEW IF EXISTS v_sct_odonto_pr;
DROP VIEW IF EXISTS v_sct_vacuna;
DROP VIEW IF EXISTS v_sct_prestacion;
DROP VIEW IF EXISTS v_sct_dispositivo;

-- =============================================================================
-- 1. Terminología (mismos nombres de tabla que usa OpenEMR)
-- =============================================================================

DROP TABLE IF EXISTS `sct2_concept`;
CREATE TABLE `sct2_concept` (
  `id`                 BIGINT UNSIGNED NOT NULL COMMENT 'conceptId',
  `effectiveTime`      DATE            NOT NULL,
  `active`             TINYINT UNSIGNED NOT NULL,
  `moduleId`           BIGINT UNSIGNED NOT NULL,
  `definitionStatusId` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

DROP TABLE IF EXISTS `sct2_description`;
CREATE TABLE `sct2_description` (
  `id`                  BIGINT UNSIGNED NOT NULL COMMENT 'descriptionId',
  `effectiveTime`       DATE            NOT NULL,
  `active`              TINYINT UNSIGNED NOT NULL,
  `moduleId`            BIGINT UNSIGNED NOT NULL,
  `conceptId`           BIGINT UNSIGNED NOT NULL,
  `languageCode`        VARCHAR(8)      NOT NULL,
  `typeId`              BIGINT UNSIGNED NOT NULL COMMENT 'FSN / sinónimo / definición',
  `term`                VARCHAR(1024)   NOT NULL,
  `caseSignificanceId`  BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- RF2 tiene 10 columnas. La tabla de OpenEMR tiene 9 (omite relationshipGroup)
-- y eso corre las columnas: relationshipGroup termina guardado en typeId.
-- Acá se usa el layout real del RF2.
DROP TABLE IF EXISTS `sct2_relationship`;
CREATE TABLE `sct2_relationship` (
  `id`                   BIGINT UNSIGNED NOT NULL,
  `effectiveTime`        DATE            NOT NULL,
  `active`               TINYINT UNSIGNED NOT NULL,
  `moduleId`             BIGINT UNSIGNED NOT NULL,
  `sourceId`             BIGINT UNSIGNED NOT NULL,
  `destinationId`        BIGINT UNSIGNED NOT NULL,
  `relationshipGroup`    SMALLINT UNSIGNED NOT NULL,
  `typeId`               BIGINT UNSIGNED NOT NULL,
  `characteristicTypeId` BIGINT UNSIGNED NOT NULL,
  `modifierId`           BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- En esta edición las 1.172.419 relaciones declaradas están TODAS inactivas
-- (active = 0), igual que en la edición internacional. Se cargan solo si se
-- pide explícitamente con --con-stated en el generador.
DROP TABLE IF EXISTS `sct2_statedrelationship`;
CREATE TABLE `sct2_statedrelationship` (
  `id`                   BIGINT UNSIGNED NOT NULL,
  `effectiveTime`        DATE            NOT NULL,
  `active`               TINYINT UNSIGNED NOT NULL,
  `moduleId`             BIGINT UNSIGNED NOT NULL,
  `sourceId`             BIGINT UNSIGNED NOT NULL,
  `destinationId`        BIGINT UNSIGNED NOT NULL,
  `relationshipGroup`    SMALLINT UNSIGNED NOT NULL,
  `typeId`               BIGINT UNSIGNED NOT NULL,
  `characteristicTypeId` BIGINT UNSIGNED NOT NULL,
  `modifierId`           BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- El archivo de esta edición viene vacío (0 filas) y con las columnas en otro
-- orden que la tabla de OpenEMR. La tabla se crea con el orden real del RF2.
DROP TABLE IF EXISTS `sct2_identifier`;
CREATE TABLE `sct2_identifier` (
  `alternateIdentifier`   VARCHAR(255)    NOT NULL,
  `effectiveTime`         DATE            NOT NULL,
  `active`                TINYINT UNSIGNED NOT NULL,
  `moduleId`              BIGINT UNSIGNED NOT NULL,
  `identifierSchemeId`    BIGINT UNSIGNED NOT NULL,
  `referencedComponentId` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`identifierSchemeId`, `alternateIdentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

DROP TABLE IF EXISTS `sct2_textdefinition`;
CREATE TABLE `sct2_textdefinition` (
  `id`                  BIGINT UNSIGNED NOT NULL,
  `effectiveTime`       DATE            NOT NULL,
  `active`              TINYINT UNSIGNED NOT NULL,
  `moduleId`            BIGINT UNSIGNED NOT NULL,
  `conceptId`           BIGINT UNSIGNED NOT NULL,
  `languageCode`        VARCHAR(8)      NOT NULL,
  `typeId`              BIGINT UNSIGNED NOT NULL,
  `term`                TEXT            NOT NULL COMMENT 'hasta 1.922 bytes en esta edición',
  `caseSignificanceId`  BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Valores concretos de atributos (152.675 filas). Sin esta tabla hay
-- relaciones con destinationId = 0 que no se pueden interpretar.
DROP TABLE IF EXISTS `sct2_rel_concrete`;
CREATE TABLE `sct2_rel_concrete` (
  `id`                   BIGINT UNSIGNED NOT NULL,
  `effectiveTime`        DATE            NOT NULL,
  `active`               TINYINT UNSIGNED NOT NULL,
  `moduleId`             BIGINT UNSIGNED NOT NULL,
  `sourceId`             BIGINT UNSIGNED NOT NULL,
  `value`                VARCHAR(255)    NOT NULL,
  `relationshipGroup`    SMALLINT UNSIGNED NOT NULL,
  `typeId`               BIGINT UNSIGNED NOT NULL,
  `characteristicTypeId` BIGINT UNSIGNED NOT NULL,
  `modifierId`           BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- =============================================================================
-- 2. Conjuntos de referencia (refsets)
-- =============================================================================

-- Refset simple: presentaciones, fármacos, prácticas, ENO, odontología, etc.
DROP TABLE IF EXISTS `sct2_refset_simple`;
CREATE TABLE `sct2_refset_simple` (
  `id`                    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `effectiveTime`         DATE            NOT NULL,
  `active`                TINYINT UNSIGNED NOT NULL,
  `moduleId`              BIGINT UNSIGNED NOT NULL,
  `refsetId`              BIGINT UNSIGNED NOT NULL,
  `referencedComponentId` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Idioma y aceptabilidad. refsetId 450828004 = español de América Latina,
-- 900000000000509007 = en-US, 900000000000508004 = en-GB.
DROP TABLE IF EXISTS `sct2_refset_language`;
CREATE TABLE `sct2_refset_language` (
  `id`                    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `effectiveTime`         DATE            NOT NULL,
  `active`                TINYINT UNSIGNED NOT NULL,
  `moduleId`              BIGINT UNSIGNED NOT NULL,
  `refsetId`              BIGINT UNSIGNED NOT NULL,
  `referencedComponentId` BIGINT UNSIGNED NOT NULL COMMENT 'descriptionId',
  `acceptabilityId`       BIGINT UNSIGNED NOT NULL COMMENT 'preferido / aceptable',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

DROP TABLE IF EXISTS `sct2_refset_attributevalue`;
CREATE TABLE `sct2_refset_attributevalue` (
  `id`                    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `effectiveTime`         DATE            NOT NULL,
  `active`                TINYINT UNSIGNED NOT NULL,
  `moduleId`              BIGINT UNSIGNED NOT NULL,
  `refsetId`              BIGINT UNSIGNED NOT NULL,
  `referencedComponentId` BIGINT UNSIGNED NOT NULL,
  `valueId`               BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- OJO: en el archivo la última columna se llama targetComponentId.
DROP TABLE IF EXISTS `sct2_refset_association`;
CREATE TABLE `sct2_refset_association` (
  `id`                    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `effectiveTime`         DATE            NOT NULL,
  `active`                TINYINT UNSIGNED NOT NULL,
  `moduleId`              BIGINT UNSIGNED NOT NULL,
  `refsetId`              BIGINT UNSIGNED NOT NULL,
  `referencedComponentId` BIGINT UNSIGNED NOT NULL,
  `targetComponentId`     BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

DROP TABLE IF EXISTS `sct2_refset_simplemap`;
CREATE TABLE `sct2_refset_simplemap` (
  `id`                    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `effectiveTime`         DATE            NOT NULL,
  `active`                TINYINT UNSIGNED NOT NULL,
  `moduleId`              BIGINT UNSIGNED NOT NULL,
  `refsetId`              BIGINT UNSIGNED NOT NULL,
  `referencedComponentId` BIGINT UNSIGNED NOT NULL,
  `mapTarget`             VARCHAR(64)     NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Mapa complejo SNOMED CT -> CIE-10 (refset 447562003, 217.373 filas).
DROP TABLE IF EXISTS `sct2_refset_extendedmap`;
CREATE TABLE `sct2_refset_extendedmap` (
  `id`                    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `effectiveTime`         DATE            NOT NULL,
  `active`                TINYINT UNSIGNED NOT NULL,
  `moduleId`              BIGINT UNSIGNED NOT NULL,
  `refsetId`              BIGINT UNSIGNED NOT NULL,
  `referencedComponentId` BIGINT UNSIGNED NOT NULL,
  `mapGroup`              SMALLINT UNSIGNED NOT NULL,
  `mapPriority`           SMALLINT UNSIGNED NOT NULL,
  `mapRule`               VARCHAR(512)    NOT NULL,
  `mapAdvice`             VARCHAR(512)    NOT NULL,
  `mapTarget`             VARCHAR(64)     NULL COMMENT 'NULL = el concepto no tiene mapeo a CIE-10',
  `correlationId`         BIGINT UNSIGNED NOT NULL,
  `mapCategoryId`         BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Refset de productos medicinales del DNM (552511000221107). Se deja la tabla
-- porque está en el paquete, pero NO se usa en ninguna vista: en la edición
-- 2026-08-20 sus 19.068 filas están TODAS inactivas (active = 0).
-- Las columnas de referencia pueden venir vacías -> NULL.
DROP TABLE IF EXISTS `sct2_refset_medicinalproducts`;
CREATE TABLE `sct2_refset_medicinalproducts` (
  `id`                              CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `effectiveTime`                   DATE            NOT NULL,
  `active`                          TINYINT UNSIGNED NOT NULL,
  `moduleId`                        BIGINT UNSIGNED NOT NULL,
  `refsetId`                        BIGINT UNSIGNED NOT NULL,
  `referencedComponentId`           BIGINT UNSIGNED NOT NULL,
  `referencedComponentIdRCD`        BIGINT UNSIGNED NULL,
  `referencedComponentIdCD_UP`      BIGINT UNSIGNED NULL,
  `referencedComponentIdCD`         BIGINT UNSIGNED NULL,
  `referencedComponentIdMPFonlyId`  BIGINT UNSIGNED NULL,
  `referencedComponentIdMPonlyId`   BIGINT UNSIGNED NULL,
  `referenceComponentIdMP`          BIGINT UNSIGNED NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Expresiones OWL (520.295 filas). No se usan para el uso clínico normal.
DROP TABLE IF EXISTS `sct2_refset_owl`;
CREATE TABLE `sct2_refset_owl` (
  `id`                    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `effectiveTime`         DATE            NOT NULL,
  `active`                TINYINT UNSIGNED NOT NULL,
  `moduleId`              BIGINT UNSIGNED NOT NULL,
  `refsetId`              BIGINT UNSIGNED NOT NULL,
  `referencedComponentId` BIGINT UNSIGNED NOT NULL,
  `owlExpression`         TEXT            NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- =============================================================================
-- 3. Catálogo de refsets (sobrevive a las recargas)
-- =============================================================================

CREATE TABLE IF NOT EXISTS `sct2_refset_catalogo` (
  `refsetId`     BIGINT UNSIGNED NOT NULL,
  `nombre`       VARCHAR(255)    NOT NULL,
  `categoria`    VARCHAR(32)     NOT NULL DEFAULT 'otros',
  `descripcion`  VARCHAR(512)    NOT NULL DEFAULT '',
  PRIMARY KEY (`refsetId`),
  KEY `idx_cat` (`categoria`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- =============================================================================
-- 4. Tablas derivadas (se reconstruyen en 03_postcarga.sql)
-- =============================================================================

-- Un solo registro de idioma efectivo por descripción, aplicando la regla
-- argentina: si hay registro del módulo 11000221109 prevalece sobre el del
-- módulo internacional en español 450829007.
DROP TABLE IF EXISTS `sct2_language_efectivo`;
CREATE TABLE `sct2_language_efectivo` (
  `referencedComponentId` BIGINT UNSIGNED NOT NULL COMMENT 'descriptionId',
  `acceptabilityId`       BIGINT UNSIGNED NOT NULL,
  `moduleId`              BIGINT UNSIGNED NOT NULL,
  `effectiveTime`         DATE            NOT NULL,
  PRIMARY KEY (`referencedComponentId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Un término preferido por concepto (español primero, inglés como respaldo).
DROP TABLE IF EXISTS `sct2_termino_preferido`;
CREATE TABLE `sct2_termino_preferido` (
  `conceptId`     BIGINT UNSIGNED NOT NULL,
  `descriptionId` BIGINT UNSIGNED NOT NULL,
  `term`          VARCHAR(1024)   NOT NULL,
  `languageCode`  VARCHAR(8)      NOT NULL,
  PRIMARY KEY (`conceptId`),
  KEY `idx_tp_desc` (`descriptionId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Tabla del autocompletado: todas las descripciones activas en español (más
-- las inglesas de conceptos sin español) con el término preferido al lado.
DROP TABLE IF EXISTS `sct2_termino_busqueda`;
CREATE TABLE `sct2_termino_busqueda` (
  `descriptionId`    BIGINT UNSIGNED NOT NULL,
  `conceptId`        BIGINT UNSIGNED NOT NULL,
  `term`             VARCHAR(1024)   NOT NULL,
  `terminoPreferido` VARCHAR(1024)   NOT NULL,
  `languageCode`     VARCHAR(8)      NOT NULL,
  PRIMARY KEY (`descriptionId`),
  KEY `idx_tb_concept` (`conceptId`),
  FULLTEXT KEY `ft_tb_term` (`term`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Catálogo de fármacos genéricos prescribibles (refsets 574471000221107 y
-- 574481000221105 = 5.607 conceptos activos).
DROP TABLE IF EXISTS `sct2_generico`;
CREATE TABLE `sct2_generico` (
  `conceptId`             BIGINT UNSIGNED NOT NULL,
  `conUnidad`             TINYINT UNSIGNED NOT NULL COMMENT '1 = unidad de presentación definida',
  `formaFarmaceuticaId`   BIGINT UNSIGNED NULL,
  PRIMARY KEY (`conceptId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Vínculo marca -> genérico ("es un"), laboratorio, condición de expendio y
-- categoría de expendio controlado.
DROP TABLE IF EXISTS `sct2_marca_generico`;
CREATE TABLE `sct2_marca_generico` (
  `marcaId`              BIGINT UNSIGNED NOT NULL,
  `genericoId`           BIGINT UNSIGNED NULL COMMENT 'solo si hay exactamente una relación "es un"',
  `relaciones`           SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `comercializada`       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `laboratorioId`        BIGINT UNSIGNED NULL,
  `condicionExpendioId`  BIGINT UNSIGNED NULL,
  `categoriaControlId`   BIGINT UNSIGNED NULL COMMENT 'estupefaciente/psicotrópico (nuevo 2026-08)',
  PRIMARY KEY (`marcaId`),
  KEY `idx_mg_generico` (`genericoId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

SELECT 'Esquema SNOMED Argentina creado. Siguiente paso: 02_carga.sql.' AS resultado;
