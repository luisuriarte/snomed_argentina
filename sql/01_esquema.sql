-- =============================================================================
-- SNOMED CT Edición Argentina - OpenEMR
-- 01_esquema.sql  ::  crea las tablas de trabajo y las tablas auxiliares
-- =============================================================================
--
-- Edición de referencia: Argentina 2026-08-20 (Release Note 20260820).
--
-- DEFINICIONES DE LOS CAMPOS
--   Los COMMENT de las tablas de terminología están tomados de la
--   especificación oficial de SNOMED CT en Release Format 2 (RF2) de SNOMED
--   International:
--     https://docs.snomed.org/snomed-ct-specifications/snomed-ct-release-file-specification
--   (Apéndice B "Specification Reference Information", capítulo 4 "File Format
--   Specifications" y capítulo 5 "Reference Set Release File Specification").
--   Los campos propios de la Extensión Argentina (refset de productos
--   medicinales del DNM) siguen el modelo de datos del Centro Nacional de
--   Terminología en Salud y se indican como tales.
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

-- Archivo RF2: Snapshot/Terminology/sct2_Concept_Snapshot_<release>.txt
DROP TABLE IF EXISTS `sct2_concept`;
CREATE TABLE `sct2_concept` (
  `id`                 BIGINT UNSIGNED NOT NULL COMMENT 'SCTID. Identificador único del concepto. Nunca se reutiliza, ni siquiera para el concepto inactivo.',
  `effectiveTime`      DATE            NOT NULL COMMENT 'Fecha (YYYYMMDD) en la que esta versión del concepto pasó a ser el estado vigente del componente.',
  `active`             TINYINT UNSIGNED NOT NULL COMMENT '1 = activo, 0 = inactivo. Un concepto inactivo sigue siendo válido: es el principio de permanencia de conceptos.',
  `moduleId`           BIGINT UNSIGNED NOT NULL COMMENT 'Módulo de desarrollo en el que se creó y se mantiene el concepto. 11000221109 = Extensión Argentina; 900000000000207008 = núcleo de SNOMED CT (core); 450829007 = módulo de la edición española.',
  `definitionStatusId` BIGINT UNSIGNED NOT NULL COMMENT 'Estado de definición del concepto. 900000000000073002 = definido por condiciones necesarias suficientes (fully defined); 900000000000074008 = no definido por condiciones necesarias suficientes (primitive).',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Conceptos de SNOMED CT (archivo sct2_Concept). Un concepto toma su significado de su nombre completamente especificado (FSN).';

-- Archivo RF2: Snapshot/Terminology/sct2_Description_Snapshot_<release>.txt
-- OJO: el término puede superar los 255 caracteres: en esta edición hay 212
-- descripciones de hasta 482 bytes. Por eso VARCHAR(1024) y no VARCHAR(255).
DROP TABLE IF EXISTS `sct2_description`;
CREATE TABLE `sct2_description` (
  `id`                  BIGINT UNSIGNED NOT NULL COMMENT 'SCTID. Identificador único de la descripción (el texto) asociada a un concepto.',
  `effectiveTime`       DATE            NOT NULL COMMENT 'Fecha (YYYYMMDD) en la que esta versión de la descripción pasó a ser el estado vigente.',
  `active`              TINYINT UNSIGNED NOT NULL COMMENT '1 = activa, 0 = inactiva. Las descripciones de un concepto inactivo pueden seguir activas.',
  `moduleId`            BIGINT UNSIGNED NOT NULL COMMENT 'Módulo de desarrollo en el que se creó y se mantiene la descripción.',
  `conceptId`           BIGINT UNSIGNED NOT NULL COMMENT 'Concepto al que se aplica esta descripción. Referencia conceptual a sct2_concept.id.',
  `languageCode`        VARCHAR(8)      NOT NULL COMMENT 'Idioma del texto, con el código ISO-639-1 de dos letras (es = español, en = inglés). Indica sólo el idioma, no el dialecto ni el país.',
  `typeId`              BIGINT UNSIGNED NOT NULL COMMENT 'Tipo de la descripción (hijo de 900000000000446008). 900000000000003001 = nombre completamente especificado (FSN); 900000000000013009 = sinónimo. El término preferido es un sinónimo marcado como tal en el refset de idioma.',
  `term`                VARCHAR(1024)   NOT NULL COMMENT 'Texto de la descripción en UTF-8. En esta edición hay 212 textos de más de 255 caracteres (el más largo, 482 bytes).',
  `caseSignificanceId`  BIGINT UNSIGNED NOT NULL COMMENT 'Sensibilidad a mayúsculas y minúsculas del texto (hijo de 900000000000447004). 900000000000448009 = todo el término insensible a mayúsculas; 900000000000017005 = todo el término sensible a mayúsculas; 900000000000020002 = sólo el primer carácter insensible.',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Descripciones (textos) de los conceptos. El término preferido de cada concepto sale de combinar esta tabla con el refset de idioma.';

-- Archivo RF2: Snapshot/Terminology/sct2_Relationship_Snapshot_<release>.txt
-- RF2 tiene 10 columnas. La tabla de OpenEMR tiene 9 (omite relationshipGroup)
-- y eso corre las columnas: relationshipGroup termina guardado en typeId.
-- Acá se usa el layout real del RF2.
DROP TABLE IF EXISTS `sct2_relationship`;
CREATE TABLE `sct2_relationship` (
  `id`                   BIGINT UNSIGNED NOT NULL COMMENT 'SCTID. Identificador único de la relación.',
  `effectiveTime`        DATE            NOT NULL COMMENT 'Fecha (YYYYMMDD) en la que esta versión de la relación pasó a ser el estado vigente.',
  `active`               TINYINT UNSIGNED NOT NULL COMMENT '1 = activa, 0 = inactiva. Sólo las activas se usan para el significado clínico.',
  `moduleId`             BIGINT UNSIGNED NOT NULL COMMENT 'Módulo de desarrollo en el que se creó y se mantiene la relación.',
  `sourceId`             BIGINT UNSIGNED NOT NULL COMMENT 'Concepto origen: el que queda definido o refinado por la relación.',
  `destinationId`        BIGINT UNSIGNED NOT NULL COMMENT 'Concepto destino de la relación. Si el valor es concreto (dosis, cantidad), la fila está en sct2_rel_concrete.',
  `relationshipGroup`    SMALLINT UNSIGNED NOT NULL COMMENT 'Agrupa las relaciones que describen una misma característica (rol). 0 = sin agrupar.',
  `typeId`               BIGINT UNSIGNED NOT NULL COMMENT 'Tipo de la relación. 116680003 = es un; 762949000 = ingrediente activo preciso; 411116001 = forma farmacéutica; 774159003 = proveedor o laboratorio; 574941000221106 = condición de expendio; 579631000221106 = tiene categoría de expendio controlado.',
  `characteristicTypeId` BIGINT UNSIGNED NOT NULL COMMENT 'Naturaleza de la relación. 900000000000011006 = relación inferida (valor de todas las relaciones liberadas desde 2018); 900000000000227009 = relación adicional (no se usa desde 2012).',
  `modifierId`           BIGINT UNSIGNED NOT NULL COMMENT 'Modificador de lógica de descripción. 900000000000451002 = restricción existencial (algunos); 900000000000452009 = restricción universal (todos). En esta edición las 4.087.686 relaciones usan 900000000000451002.',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Relaciones inferidas entre conceptos. Es la base del vínculo marca -> genérico (116680003 es un) y de los atributos del DNM.';

-- Archivo RF2: Snapshot/Terminology/sct2_StatedRelationship_Snapshot_<release>.txt
-- En esta edición las 1.172.419 relaciones declaradas están TODAS inactivas
-- (active = 0), igual que en la edición internacional. Se cargan solo si se
-- pide explícitamente con --con-stated en el generador.
DROP TABLE IF EXISTS `sct2_statedrelationship`;
CREATE TABLE `sct2_statedrelationship` (
  `id`                   BIGINT UNSIGNED NOT NULL COMMENT 'SCTID. Identificador único de la relación declarada.',
  `effectiveTime`        DATE            NOT NULL COMMENT 'Fecha (YYYYMMDD) en la que esta versión de la relación pasó a ser el estado vigente.',
  `active`               TINYINT UNSIGNED NOT NULL COMMENT '1 = activa, 0 = inactiva.',
  `moduleId`             BIGINT UNSIGNED NOT NULL COMMENT 'Módulo de desarrollo en el que se creó y se mantiene la relación.',
  `sourceId`             BIGINT UNSIGNED NOT NULL COMMENT 'Concepto origen de la relación.',
  `destinationId`        BIGINT UNSIGNED NOT NULL COMMENT 'Concepto destino de la relación.',
  `relationshipGroup`    SMALLINT UNSIGNED NOT NULL COMMENT 'Agrupa las relaciones que describen una misma característica (rol). 0 = sin agrupar.',
  `typeId`               BIGINT UNSIGNED NOT NULL COMMENT 'Tipo de la relación declarada.',
  `characteristicTypeId` BIGINT UNSIGNED NOT NULL COMMENT 'Naturaleza de la relación. En las relaciones declaradas: 900000000000010007 = relación declarada (stated); 900000000000227009 = relación adicional.',
  `modifierId`           BIGINT UNSIGNED NOT NULL COMMENT 'Modificador de lógica de descripción. 900000000000451002 = restricción existencial (algunos); 900000000000452009 = restricción universal (todos).',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Relaciones declaradas (stated) del autor. Mismo layout que sct2_relationship.';

-- Archivo RF2: Snapshot/Terminology/sct2_Identifier_Snapshot_<release>.txt
-- En esta edición el archivo viene vacío (0 filas) y con las columnas en otro
-- orden que la tabla de OpenEMR. La tabla se crea con el orden real del RF2.
DROP TABLE IF EXISTS `sct2_identifier`;
CREATE TABLE `sct2_identifier` (
  `alternateIdentifier`   VARCHAR(255)    NOT NULL COMMENT 'Representación textual del identificador alterno en su esquema de origen.',
  `effectiveTime`         DATE            NOT NULL COMMENT 'Fecha (YYYYMMDD) en la que esta versión del identificador alterno pasó a ser el estado vigente.',
  `active`                TINYINT UNSIGNED NOT NULL COMMENT '1 = activo, 0 = inactivo.',
  `moduleId`              BIGINT UNSIGNED NOT NULL COMMENT 'Módulo de desarrollo en el que se creó y se mantiene el identificador alterno.',
  `identifierSchemeId`    BIGINT UNSIGNED NOT NULL COMMENT 'Concepto SNOMED CT que identifica el esquema de códigos alterno.',
  `referencedComponentId` BIGINT UNSIGNED NOT NULL COMMENT 'Componente SNOMED CT al que se vincula el identificador alterno.',
  PRIMARY KEY (`identifierSchemeId`, `alternateIdentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Identificadores alternos (por ejemplo un código de otro sistema) vinculados a un componente SNOMED CT.';

-- Archivo RF2: Snapshot/Terminology/sct2_TextDefinition_Snapshot_<release>.txt
DROP TABLE IF EXISTS `sct2_textdefinition`;
CREATE TABLE `sct2_textdefinition` (
  `id`                  BIGINT UNSIGNED NOT NULL COMMENT 'SCTID. Identificador único de la definición de texto.',
  `effectiveTime`       DATE            NOT NULL COMMENT 'Fecha (YYYYMMDD) en la que esta versión pasó a ser el estado vigente.',
  `active`              TINYINT UNSIGNED NOT NULL COMMENT '1 = activa, 0 = inactiva.',
  `moduleId`            BIGINT UNSIGNED NOT NULL COMMENT 'Módulo de desarrollo en el que se creó y se mantiene la definición.',
  `conceptId`           BIGINT UNSIGNED NOT NULL COMMENT 'Concepto al que se aplica la definición de texto.',
  `languageCode`        VARCHAR(8)      NOT NULL COMMENT 'Idioma del texto (ISO-639-1 de dos letras).',
  `typeId`              BIGINT UNSIGNED NOT NULL COMMENT 'Tipo de la definición (hijo de 900000000000446008). 900000000000550004 = definición textual del concepto.',
  `term`                TEXT            NOT NULL COMMENT 'Texto de la definición en UTF-8. En esta edición llega a 1.922 bytes, por eso es TEXT y no VARCHAR.',
  `caseSignificanceId`  BIGINT UNSIGNED NOT NULL COMMENT 'Sensibilidad a mayúsculas y minúsculas del texto (hijo de 900000000000447004).',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Definiciones de texto de los conceptos. Mismo layout que sct2_description pero con textos largos.';

-- Archivo RF2: Snapshot/Terminology/sct2_RelationshipConcreteValues_Snapshot_<release>.txt
-- Sin esta tabla quedan relaciones con destinationId = 0 que no se pueden
-- interpretar: aquí están las dosis y las cantidades.
DROP TABLE IF EXISTS `sct2_rel_concrete`;
CREATE TABLE `sct2_rel_concrete` (
  `id`                   BIGINT UNSIGNED NOT NULL COMMENT 'SCTID. Identificador único de la relación con valor concreto.',
  `effectiveTime`        DATE            NOT NULL COMMENT 'Fecha (YYYYMMDD) en la que esta versión pasó a ser el estado vigente.',
  `active`               TINYINT UNSIGNED NOT NULL COMMENT '1 = activa, 0 = inactiva.',
  `moduleId`             BIGINT UNSIGNED NOT NULL COMMENT 'Módulo de desarrollo en el que se creó y se mantiene la relación.',
  `sourceId`             BIGINT UNSIGNED NOT NULL COMMENT 'Concepto origen de la relación.',
  `value`                VARCHAR(255)    NOT NULL COMMENT 'Valor concreto como texto: entero o decimal con prefijo # (por ejemplo #500); texto entre comillas dobles con las comillas internas escapadas.',
  `relationshipGroup`    SMALLINT UNSIGNED NOT NULL COMMENT 'Agrupa las relaciones que describen una misma característica (rol). 0 = sin agrupar.',
  `typeId`               BIGINT UNSIGNED NOT NULL COMMENT 'Tipo de la relación a la que corresponde el valor (por ejemplo 763032000, unidad de presentación).',
  `characteristicTypeId` BIGINT UNSIGNED NOT NULL COMMENT 'Naturaleza de la relación. 900000000000011006 = relación inferida; 900000000000227009 = relación adicional.',
  `modifierId`           BIGINT UNSIGNED NOT NULL COMMENT 'Modificador de lógica de descripción. 900000000000451002 = restricción existencial (algunos); 900000000000452009 = restricción universal (todos).',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Relaciones cuyo destino es un valor concreto (dosis, cantidad, unidad) en lugar de un concepto.';

-- =============================================================================
-- 2. Conjuntos de referencias (refsets)
-- =============================================================================
-- Todos los refsets comparten la estructura básica de miembro de refset:
--   id (UUID) - effectiveTime - active - moduleId - refsetId - referencedComponentId
-- y agregan columnas según el tipo de refset.

-- Archivo RF2: Snapshot/Refset/Content/der2_Refset_SimpleSnapshot_<release>.txt
DROP TABLE IF EXISTS `sct2_refset_simple`;
CREATE TABLE `sct2_refset_simple` (
  `id`                    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT 'UUID. Identificador único del miembro del refset. No identifica ni el refset ni el componente: sirve para versionar la fila.',
  `effectiveTime`         DATE            NOT NULL COMMENT 'Fecha (YYYYMMDD) en la que esta versión del miembro pasó a ser la versión vigente del mismo.',
  `active`                TINYINT UNSIGNED NOT NULL COMMENT '1 = miembro activo del conjunto, 0 = miembro dado de baja.',
  `moduleId`              BIGINT UNSIGNED NOT NULL COMMENT 'Módulo de desarrollo en el que se creó y se mantiene la pertenencia.',
  `refsetId`              BIGINT UNSIGNED NOT NULL COMMENT 'Concepto SNOMED CT que nombra el conjunto de referencias y agrupa a todos sus miembros. Por ejemplo 537301000221103 = prácticas de laboratorio de Argentina.',
  `referencedComponentId` BIGINT UNSIGNED NOT NULL COMMENT 'Componente al que se aplica la pertenencia al conjunto. En los refsets de contenido es casi siempre un conceptId.',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Refsets simples: enumeran un subconjunto de conceptos (presentaciones, fármacos, prácticas, ENO, odontología,etc.).';

-- Archivo RF2: Snapshot/Refset/Language/der2_cRefset_LanguageSnapshot_<release>.txt
-- 450828004 = español de América Latina; 900000000000509007 = en-US;
-- 900000000000508004 = en-GB.
DROP TABLE IF EXISTS `sct2_refset_language`;
CREATE TABLE `sct2_refset_language` (
  `id`                    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT 'UUID. Identificador único del miembro del refset.',
  `effectiveTime`         DATE            NOT NULL COMMENT 'Fecha (YYYYMMDD) en la que esta versión del miembro pasó a ser la versión vigente.',
  `active`                TINYINT UNSIGNED NOT NULL COMMENT '1 = la aceptación del término está vigente, 0 = fue dada de baja.',
  `moduleId`              BIGINT UNSIGNED NOT NULL COMMENT 'Módulo que define la aceptación. 11000221109 = Argentina; 450829007 = español internacional (cede ante el argentino).',
  `refsetId`              BIGINT UNSIGNED NOT NULL COMMENT 'Refset de idioma: 450828004 = español de América Latina; 900000000000509007 = en-US; 900000000000508004 = en-GB.',
  `referencedComponentId` BIGINT UNSIGNED NOT NULL COMMENT 'descriptionId (NO es un conceptId): la descripción cuya aceptabilidad se define.',
  `acceptabilityId`       BIGINT UNSIGNED NOT NULL COMMENT 'Aceptabilidad del término. 900000000000548007 = preferido; 900000000000549004 = aceptable.',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Refsets de idioma: indica qué descripciones son el término preferido y cuáles son aceptables en cada idioma o dialecto.';

-- Archivo RF2: Snapshot/Refset/Content/der2_cRefset_AttributeValueSnapshot_<release>.txt
DROP TABLE IF EXISTS `sct2_refset_attributevalue`;
CREATE TABLE `sct2_refset_attributevalue` (
  `id`                    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT 'UUID. Identificador único del miembro del refset.',
  `effectiveTime`         DATE            NOT NULL COMMENT 'Fecha (YYYYMMDD) en la que esta versión del miembro pasó a ser la versión vigente.',
  `active`                TINYINT UNSIGNED NOT NULL COMMENT '1 = activo, 0 = inactivo.',
  `moduleId`              BIGINT UNSIGNED NOT NULL COMMENT 'Módulo de desarrollo en el que se creó y se mantiene la pertenencia.',
  `refsetId`              BIGINT UNSIGNED NOT NULL COMMENT 'Concepto SNOMED CT que nombra el conjunto de referencias.',
  `referencedComponentId` BIGINT UNSIGNED NOT NULL COMMENT 'Componente al que se aplica el valor etiquetado (por ejemplo el motivo de inactivación de un concepto).',
  `valueId`               BIGINT UNSIGNED NOT NULL COMMENT 'Concepto que actúa como valor de la etiqueta asociada al componente referenciado.',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Refsets de valor de atributo: etiquetan un componente con un valor de la jerarquía de metadatos.';

-- Archivo RF2: Snapshot/Refset/Content/der2_cRefset_AssociationSnapshot_<release>.txt
-- OJO: en el archivo la última columna se llama targetComponentId.
DROP TABLE IF EXISTS `sct2_refset_association`;
CREATE TABLE `sct2_refset_association` (
  `id`                    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT 'UUID. Identificador único del miembro del refset.',
  `effectiveTime`         DATE            NOT NULL COMMENT 'Fecha (YYYYMMDD) en la que esta versión del miembro pasó a ser la versión vigente.',
  `active`                TINYINT UNSIGNED NOT NULL COMMENT '1 = activo, 0 = inactivo.',
  `moduleId`              BIGINT UNSIGNED NOT NULL COMMENT 'Módulo de desarrollo en el que se creó y se mantiene la asociación.',
  `refsetId`              BIGINT UNSIGNED NOT NULL COMMENT 'Concepto SNOMED CT que nombra el conjunto de referencias de asociación.',
  `referencedComponentId` BIGINT UNSIGNED NOT NULL COMMENT 'Componente origen de la asociación.',
  `targetComponentId`     BIGINT UNSIGNED NOT NULL COMMENT 'Componente destino de la asociación: por ejemplo el concepto que reemplaza a otro.',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Refsets de asociación: vinculan componentes entre sí (por ejemplo reemplazo de un concepto por otro).';

-- Archivo RF2: Snapshot/Refset/Map/der2_sRefset_SimpleMapSnapshot_<release>.txt
DROP TABLE IF EXISTS `sct2_refset_simplemap`;
CREATE TABLE `sct2_refset_simplemap` (
  `id`                    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT 'UUID. Identificador único del miembro del refset.',
  `effectiveTime`         DATE            NOT NULL COMMENT 'Fecha (YYYYMMDD) en la que esta versión del miembro pasó a ser la versión vigente.',
  `active`                TINYINT UNSIGNED NOT NULL COMMENT '1 = mapeo activo, 0 = inactivo.',
  `moduleId`              BIGINT UNSIGNED NOT NULL COMMENT 'Módulo de desarrollo en el que se creó y se mantiene el mapeo.',
  `refsetId`              BIGINT UNSIGNED NOT NULL COMMENT 'Concepto SNOMED CT que nombra el conjunto. 900000000000497000 = mapa simple a CIE-10.',
  `referencedComponentId` BIGINT UNSIGNED NOT NULL COMMENT 'Concepto SNOMED CT de origen del mapeo.',
  `mapTarget`             VARCHAR(64)     NOT NULL COMMENT 'Código en el esquema de destino al que se mapea el concepto (por ejemplo C50 en CIE-10).',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Mapas simples desde SNOMED CT hacia otro sistema de códigos (uno a uno).';

-- Archivo RF2: Snapshot/Refset/Map/der2_iisssccRefset_ExtendedMapSnapshot_<release>.txt
-- Mapa extendido a CIE-10 (refset 447562003). Aquí está el mapeo
-- SNOMED CT -> CIE-10 que sirve, por ejemplo, para el SNVS.
DROP TABLE IF EXISTS `sct2_refset_extendedmap`;
CREATE TABLE `sct2_refset_extendedmap` (
  `id`                    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT 'UUID. Identificador único del miembro del refset.',
  `effectiveTime`         DATE            NOT NULL COMMENT 'Fecha (YYYYMMDD) en la que esta versión del miembro pasó a ser la versión vigente.',
  `active`                TINYINT UNSIGNED NOT NULL COMMENT '1 = mapeo activo, 0 = inactivo.',
  `moduleId`              BIGINT UNSIGNED NOT NULL COMMENT 'Módulo de desarrollo en el que se creó y se mantiene el mapeo.',
  `refsetId`              BIGINT UNSIGNED NOT NULL COMMENT 'Concepto SNOMED CT que nombra el conjunto. 447562003 = mapa extendido a CIE-10.',
  `referencedComponentId` BIGINT UNSIGNED NOT NULL COMMENT 'Concepto SNOMED CT de origen del mapeo.',
  `mapGroup`              SMALLINT UNSIGNED NOT NULL COMMENT 'Agrupa los registros de mapa complejo entre los cuales se puede elegir un código destino. Un concepto que mapea a n códigos tiene n grupos.',
  `mapPriority`           SMALLINT UNSIGNED NOT NULL COMMENT 'Orden en que se revisan los registros del grupo: se toma el primero que cumpla el criterio de selección.',
  `mapRule`               VARCHAR(512)    NOT NULL COMMENT 'Regla legible por máquina (se evalúa a true o false en tiempo de ejecución) que indica si el registro debe seleccionarse dentro de su grupo.',
  `mapAdvice`             VARCHAR(512)    NOT NULL COMMENT 'Consejo legible por humanos para elegir el código destino correcto entre las alternativas del grupo.',
  `mapTarget`             VARCHAR(64)     NULL COMMENT 'Código en el esquema de destino. NULL = el concepto no tiene equivalencia en ese esquema (34.409 filas de esta edición).',
  `correlationId`         BIGINT UNSIGNED NOT NULL COMMENT 'Concepto SNOMED CT que representa la correlación entre el concepto SNOMED CT y el código destino.',
  `mapCategoryId`         BIGINT UNSIGNED NOT NULL COMMENT 'Concepto de la jerarquía de metadatos que representa la categoría del mapa (hijo de 609331003, valor de categoría de mapa).',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Mapas extendidos (complejos) desde SNOMED CT hacia CIE-10, con reglas de selección en tiempo de ejecución.';

-- Archivo RF2: Snapshot/Refset/Content/der2_ccccccRefset_MedicinalProductsSnapshot_<release>.txt
-- Refset de productos medicinales del DNM (552511000221107). Se deja disponible
-- pero NO se usa en las vistas: en la edición 2026-08-20 sus 19.068 filas están
-- TODAS inactivas (active = 0). Las columnas de referencia pueden venir vacías
-- -> NULL. Estas columnas no están en la especificación RF2 internacional: son
-- del modelo de datos del DNM del Centro Nacional de Terminología en Salud
-- (MP = producto medicinal, MPF = forma de presentación, CD = medicamento
-- genérico, CD_UP = genérico con unidad de presentación definida,
-- RCD = genérico de referencia).
DROP TABLE IF EXISTS `sct2_refset_medicinalproducts`;
CREATE TABLE `sct2_refset_medicinalproducts` (
  `id`                              CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT 'UUID. Identificador único del miembro del refset.',
  `effectiveTime`                   DATE            NOT NULL COMMENT 'Fecha (YYYYMMDD) en la que esta versión del miembro pasó a ser la versión vigente.',
  `active`                          TINYINT UNSIGNED NOT NULL COMMENT '1 = activo, 0 = inactivo. En esta edición las 19.068 filas están inactivas.',
  `moduleId`                        BIGINT UNSIGNED NOT NULL COMMENT 'Módulo de desarrollo en el que se creó y se mantiene la pertenencia. 11000221109 = DNM Argentina.',
  `refsetId`                        BIGINT UNSIGNED NOT NULL COMMENT 'Concepto SNOMED CT que nombra el conjunto. 552511000221107 = productos medicinales del DNM.',
  `referencedComponentId`           BIGINT UNSIGNED NOT NULL COMMENT 'Concepto del producto medicinal (MP) o de su forma de presentación (MPF).',
  `referencedComponentIdRCD`        BIGINT UNSIGNED NULL COMMENT 'Concepto del medicamento genérico de referencia (RCD) vinculado al producto.',
  `referencedComponentIdCD_UP`      BIGINT UNSIGNED NULL COMMENT 'Concepto del medicamento genérico con unidad de presentación definida (CD_UP).',
  `referencedComponentIdCD`         BIGINT UNSIGNED NULL COMMENT 'Concepto del medicamento genérico (CD) vinculado al producto.',
  `referencedComponentIdMPFonlyId`  BIGINT UNSIGNED NULL COMMENT 'Forma de presentación (MPF) que no tiene concepto genérico asociado.',
  `referencedComponentIdMPonlyId`   BIGINT UNSIGNED NULL COMMENT 'Producto medicinal (MP) que no tiene concepto genérico asociado.',
  `referenceComponentIdMP`          BIGINT UNSIGNED NULL COMMENT 'Producto medicinal (MP) de referencia del grupo.',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Refset de productos medicinales del DNM (modelo CNTS). En esta edición está íntegramente inactivo: no se usa en ninguna vista.';

-- Archivo RF2: Snapshot/Terminology/sct2_sRefset_OWLExpressionSnapshot_<release>.txt
-- Expresiones OWL (520.295 filas). No se usan para el uso clínico normal.
DROP TABLE IF EXISTS `sct2_refset_owl`;
CREATE TABLE `sct2_refset_owl` (
  `id`                    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT 'UUID. Identificador único del miembro del refset.',
  `effectiveTime`         DATE            NOT NULL COMMENT 'Fecha (YYYYMMDD) en la que esta versión del miembro pasó a ser la versión vigente.',
  `active`                TINYINT UNSIGNED NOT NULL COMMENT '1 = activo, 0 = inactivo.',
  `moduleId`              BIGINT UNSIGNED NOT NULL COMMENT 'Módulo de desarrollo en el que se creó y se mantiene la expresión.',
  `refsetId`              BIGINT UNSIGNED NOT NULL COMMENT 'Concepto SNOMED CT que nombra el conjunto. 733073007 = axiomas OWL; 762103008 = ontología OWL.',
  `referencedComponentId` BIGINT UNSIGNED NOT NULL COMMENT 'Concepto al que se aplica la expresión OWL.',
  `owlExpression`         TEXT            NOT NULL COMMENT 'Expresión OWL en sintaxis funcional que define lógicamente el concepto (hasta 2.547 bytes en esta edición).',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Refsets de expresión OWL: definición lógica de los conceptos en la sintaxis funcional de OWL.';

-- =============================================================================
-- 3. Catálogo de refsets (sobrevive a las recargas)
-- =============================================================================

CREATE TABLE IF NOT EXISTS `sct2_refset_catalogo` (
  `refsetId`     BIGINT UNSIGNED NOT NULL COMMENT 'Concepto SNOMED CT que nombra el conjunto de referencias.',
  `nombre`       VARCHAR(255)    NOT NULL COMMENT 'Nombre del conjunto según las Notas de la Edición Argentina. Si el conjunto no está nominado, se muestra "Refset <id>".',
  `categoria`    VARCHAR(32)     NOT NULL DEFAULT 'otros' COMMENT 'Agrupación para el listado: medicamentos, practicas, odontologia, vacunas, eno, dispositivos, poblaciones u otros.',
  `descripcion`  VARCHAR(512)    NOT NULL DEFAULT '' COMMENT 'Detalle del alcance del conjunto.',
  PRIMARY KEY (`refsetId`),
  KEY `idx_cat` (`categoria`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Catálogo de los conjuntos de referencias con su nombre y categoría (lo mantiene el proyecto, no viene en el ZIP).';

-- =============================================================================
-- 4. Tablas derivadas (se reconstruyen en 03_postcarga.sql)
-- =============================================================================

-- Un solo registro de idioma efectivo por descripción, aplicando la regla
-- "si existe registro del módulo argentino, prevalece sobre el internacional".
DROP TABLE IF EXISTS `sct2_language_efectivo`;
CREATE TABLE `sct2_language_efectivo` (
  `referencedComponentId` BIGINT UNSIGNED NOT NULL COMMENT 'descriptionId (NO es un conceptId): la descripción de la que se resuelve el idioma efectivo.',
  `acceptabilityId`       BIGINT UNSIGNED NOT NULL COMMENT 'Aceptabilidad que quedó vigente. 900000000000548007 = preferido; 900000000000549004 = aceptable.',
  `moduleId`              BIGINT UNSIGNED NOT NULL COMMENT 'Módulo del registro que quedó vigente. 11000221109 = Argentina; 450829007 = español internacional.',
  `effectiveTime`         DATE            NOT NULL COMMENT 'Fecha del registro de idioma que quedó vigente.',
  PRIMARY KEY (`referencedComponentId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Idioma y aceptabilidad efectiva de cada descripción (una fila por descripción).';

-- Un término preferido por concepto.
DROP TABLE IF EXISTS `sct2_termino_preferido`;
CREATE TABLE `sct2_termino_preferido` (
  `conceptId`     BIGINT UNSIGNED NOT NULL COMMENT 'Concepto al que pertenece el término.',
  `descriptionId` BIGINT UNSIGNED NOT NULL COMMENT 'Descripción elegida como término preferido.',
  `term`          VARCHAR(1024)   NOT NULL COMMENT 'Texto del término preferido.',
  `languageCode`  VARCHAR(8)      NOT NULL COMMENT 'Idioma del término elegido. En el 93 % de los casos es es; si el concepto no tiene término en español se recurre al inglés.',
  PRIMARY KEY (`conceptId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Un término preferido por concepto (español primero, inglés como respaldo).';

-- Todas las descripciones activas en español (preferidas y aceptables),
-- con el término preferido al lado. Es la tabla del autocompletado:
-- permite buscar "clonazepam 0,5" y devolver "clonazepam 500 mcg ...".
-- El índice FULLTEXT y el índice por concepto se agregan en 03_postcarga.sql.
DROP TABLE IF EXISTS `sct2_termino_busqueda`;
CREATE TABLE `sct2_termino_busqueda` (
  `descriptionId`    BIGINT UNSIGNED NOT NULL COMMENT 'Descripción a la que pertenece la fila.',
  `conceptId`        BIGINT UNSIGNED NOT NULL COMMENT 'Concepto al que pertenece la descripción.',
  `term`             VARCHAR(1024)   NOT NULL COMMENT 'Texto de la descripción (el texto por el que se busca).',
  `terminoPreferido` VARCHAR(1024)   NOT NULL COMMENT 'Término preferido del concepto, para mostrarlo junto al resultado.',
  `languageCode`     VARCHAR(8)      NOT NULL COMMENT 'Idioma de la descripción buscada.',
  PRIMARY KEY (`descriptionId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Índice de búsqueda: descripciones activas en español (y en inglés para los conceptos que no tienen español).';

-- Catálogo de fármacos genéricos prescribibles (refsets 574471000221107 y
-- 574481000221105 = 5.607 conceptos activos).
DROP TABLE IF EXISTS `sct2_generico`;
CREATE TABLE `sct2_generico` (
  `conceptId`             BIGINT UNSIGNED NOT NULL COMMENT 'Concepto del medicamento genérico prescribible.',
  `conUnidad`             TINYINT UNSIGNED NOT NULL COMMENT '1 = el genérico tiene unidad de presentación definida (refset 574471000221107); 0 = no la tiene (refset 574481000221105).',
  `formaFarmaceuticaId`   BIGINT UNSIGNED NULL COMMENT 'Concepto de la forma farmacéutica del genérico (relación 411116001), si la tiene.',
  PRIMARY KEY (`conceptId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Fármacos genéricos prescribibles del DNM con estado de comercialización vigente.';

-- Vínculo marca -> genérico ("es un"), laboratorio, condición de expendio y
-- categoría de expendio controlado.
DROP TABLE IF EXISTS `sct2_marca_generico`;
CREATE TABLE `sct2_marca_generico` (
  `marcaId`              BIGINT UNSIGNED NOT NULL COMMENT 'Concepto de la marca comercial (refset 425071000221108).',
  `genericoId`           BIGINT UNSIGNED NULL COMMENT 'Concepto del genérico al que apunta la relación 116680003 (es un). NULL si la marca tiene más de un destino y el vínculo es ambiguo.',
  `relaciones`           SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Cantidad de relaciones "es un" de la marca. 164 marcas de esta edición tienen más de una.',
  `comercializada`       TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 = la marca tiene al menos una presentación en estado comercializado (refset 574461000221103).',
  `laboratorioId`        BIGINT UNSIGNED NULL COMMENT 'Concepto del laboratorio o proveedor de la marca (relación 774159003).',
  `condicionExpendioId`  BIGINT UNSIGNED NULL COMMENT 'Concepto de la condición de expendio de la marca (relación 574941000221106).',
  `categoriaControlId`   BIGINT UNSIGNED NULL COMMENT 'Concepto de la categoría de expendio controlado (relación 579631000221106, nueva en la edición 2026-08): estupefaciente o psicotrópico de lista I a IV.',
  PRIMARY KEY (`marcaId`),
  KEY `idx_mg_generico` (`genericoId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Vínculo entre marcas comerciales y genéricos, con los atributos del DNM asociados.';

-- Mapeo SNOMED CT → Nomenclador Bioquímico Único (NBU) 2012/2026.
-- Fuente: Mapeo_NBU_SCT_Agosto26.xlsx distribuido en la carpeta Resources/
-- del paquete SNOMED CT Argentina 2026-08-20. 425 pares SCT→NBU.
DROP TABLE IF EXISTS `sct2_map_nbu`;
CREATE TABLE `sct2_map_nbu` (
  `sctid`         BIGINT UNSIGNED NOT NULL  COMMENT 'Concepto SNOMED CT de la práctica de laboratorio.',
  `codigoNBU`     INT UNSIGNED    NOT NULL  COMMENT 'Código numérico del Nomenclador Bioquímico Único (NBU PMO, versión 2016).',
  `determinacion` VARCHAR(512)    NOT NULL  COMMENT 'Nombre de la determinación según el NBU.',
  PRIMARY KEY (`sctid`, `codigoNBU`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Mapeo SNOMED CT → Nomenclador Bioquímico Único 2012/2026 (NRC Argentina, agosto 2026).';

-- Mapeo GTIN (código de barras EAN-13) → Presentación comercial SNOMED CT.
-- Fuente: MAP_GTIN_a_RPCD_comercializadas_20260820.xlsx en Resources/.
-- 15.500 GTINs en estado COMERCIALIZADO al 7-jul-2026.
DROP TABLE IF EXISTS `sct2_map_gtin`;
CREATE TABLE `sct2_map_gtin` (
  `gtin`                   VARCHAR(20)     NOT NULL  COMMENT 'Global Trade Item Number (EAN-13/GTIN-14) del producto comercial.',
  `condicion`              VARCHAR(30)     NOT NULL  COMMENT 'Estado de comercialización: COMERCIALIZADO u otro.',
  `rpcd_id`                BIGINT UNSIGNED NOT NULL  COMMENT 'Concepto SNOMED CT de la presentación farmacéutica comercial (RPCD).',
  `rpcd_fsn`               VARCHAR(1024)   NOT NULL  COMMENT 'Fully Specified Name de la presentación comercial en SNOMED CT.',
  PRIMARY KEY (`gtin`),
  KEY `idx_gtin_rpcd`      (`rpcd_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  COMMENT='Mapeo GTIN (código de barras) → Presentación farmacéutica comercial SNOMED CT (NRC Argentina, agosto 2026).';

SELECT 'Esquema SNOMED Argentina creado. Siguiente paso: 02_carga.sql.' AS resultado;
