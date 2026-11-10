-- =============================================================================
-- 02_carga.sql  ::  LOAD DATA de la Edición Argentina de SNOMED CT
-- =============================================================================
-- GENERADO AUTOMÁTICAMENTE por scripts/generar_carga.php. No editar a mano:
-- si cambia la release, vuelva a generarlo.
--
-- Release           : 2026-08-20
-- Generado          : 2026-11-10 18:25:26
-- Carpeta de archivos: D:\docs\luis\Documentos\sitios\openemr\codigos\SNOMED\sct_carga_20260820
-- Ruta en los LOAD   : D:\docs\luis\Documentos\sitios\openemr\codigos\SNOMED\sct_carga_20260820
-- Bloques incluidos : 11
-- Inglés            : se conserva
--
-- ANTES DE EJECUTAR
--   1) En el servidor MySQL: SET GLOBAL local_infile = 1;
--   2) En la conexión de DBeaver: AllowLoadLocalInfile = true
--      (Propiedades del driver -> allowLoadLocalInfile).
--   3) Las rutas de abajo son del equipo desde donde se EJECUTA el SQL:
--      - con mysql < 02_carga.sql en el servidor, la ruta debe ser del
--        servidor;
--      - ejecutado desde DBeaver-CE, la ruta debe ser de la PC donde está
--        DBeaver (los archivos se leen del cliente y viajan por el túnel).
--   4) Ejecute 01_esquema.sql antes de este archivo.
--
-- Duración estimada: 20-60 minutos según el equipo.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- [1/11] sct2_concept
-- 600.374 conceptos
-- Archivo: Snapshot/Terminology/sct2_Concept_Snapshot_ArgentinaEdition_20260820.txt
-- -----------------------------------------------------------------------------
TRUNCATE TABLE `sct2_concept`;
LOAD DATA LOCAL INFILE 'D:/docs/luis/Documentos/sitios/openemr/codigos/SNOMED/sct_carga_20260820/Snapshot/Terminology/sct2_Concept_Snapshot_ArgentinaEdition_20260820.txt'
  INTO TABLE `sct2_concept`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY '\t' ESCAPED BY ''
  LINES TERMINATED BY '\r\n'
  IGNORE 1 LINES
  (`id`, `effectiveTime`, `active`, `moduleId`, `definitionStatusId`)
;

-- -----------------------------------------------------------------------------
-- [2/11] sct2_description
-- 3.337.073 descripciones (1.719.948 en inglés, 1.617.125 en español)
-- Archivo: Snapshot/Terminology/sct2_Description_Snapshot_ArgentinaEdition_20260820.txt
-- -----------------------------------------------------------------------------
TRUNCATE TABLE `sct2_description`;
LOAD DATA LOCAL INFILE 'D:/docs/luis/Documentos/sitios/openemr/codigos/SNOMED/sct_carga_20260820/Snapshot/Terminology/sct2_Description_Snapshot_ArgentinaEdition_20260820.txt'
  INTO TABLE `sct2_description`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY '\t' ESCAPED BY ''
  LINES TERMINATED BY '\r\n'
  IGNORE 1 LINES
  (`id`, `effectiveTime`, `active`, `moduleId`, `conceptId`, `languageCode`, `typeId`, `term`, `caseSignificanceId`)
;

-- -----------------------------------------------------------------------------
-- [3/11] sct2_relationship
-- 4.087.686 relaciones (1.751.826 activas)
-- Archivo: Snapshot/Terminology/sct2_Relationship_Snapshot_ArgentinaEdition_20260820.txt
-- -----------------------------------------------------------------------------
TRUNCATE TABLE `sct2_relationship`;
LOAD DATA LOCAL INFILE 'D:/docs/luis/Documentos/sitios/openemr/codigos/SNOMED/sct_carga_20260820/Snapshot/Terminology/sct2_Relationship_Snapshot_ArgentinaEdition_20260820.txt'
  INTO TABLE `sct2_relationship`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY '\t' ESCAPED BY ''
  LINES TERMINATED BY '\r\n'
  IGNORE 1 LINES
  (`id`, `effectiveTime`, `active`, `moduleId`, `sourceId`, `destinationId`, `relationshipGroup`, `typeId`, `characteristicTypeId`, `modifierId`)
;

-- -----------------------------------------------------------------------------
-- [4/11] sct2_textdefinition
-- 29.051 definiciones de texto
-- Archivo: Snapshot/Terminology/sct2_TextDefinition_Snapshot_ArgentinaEdition_20260820.txt
-- -----------------------------------------------------------------------------
TRUNCATE TABLE `sct2_textdefinition`;
LOAD DATA LOCAL INFILE 'D:/docs/luis/Documentos/sitios/openemr/codigos/SNOMED/sct_carga_20260820/Snapshot/Terminology/sct2_TextDefinition_Snapshot_ArgentinaEdition_20260820.txt'
  INTO TABLE `sct2_textdefinition`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY '\t' ESCAPED BY ''
  LINES TERMINATED BY '\r\n'
  IGNORE 1 LINES
  (`id`, `effectiveTime`, `active`, `moduleId`, `conceptId`, `languageCode`, `typeId`, `term`, `caseSignificanceId`)
;

-- -----------------------------------------------------------------------------
-- [5/11] sct2_rel_concrete
-- 152.675 valores concretos (dosis, valores numéricos)
-- Archivo: Snapshot/Terminology/sct2_RelationshipConcreteValues_Snapshot_ArgentinaEdition_20260820.txt
-- -----------------------------------------------------------------------------
TRUNCATE TABLE `sct2_rel_concrete`;
LOAD DATA LOCAL INFILE 'D:/docs/luis/Documentos/sitios/openemr/codigos/SNOMED/sct_carga_20260820/Snapshot/Terminology/sct2_RelationshipConcreteValues_Snapshot_ArgentinaEdition_20260820.txt'
  INTO TABLE `sct2_rel_concrete`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY '\t' ESCAPED BY ''
  LINES TERMINATED BY '\r\n'
  IGNORE 1 LINES
  (`id`, `effectiveTime`, `active`, `moduleId`, `sourceId`, `value`, `relationshipGroup`, `typeId`, `characteristicTypeId`, `modifierId`)
;

-- -----------------------------------------------------------------------------
-- [6/11] sct2_refset_simple
-- 120.740 filas (105.912 activas) en 28 conjuntos
-- Archivo: Snapshot/Refset/Content/der2_Refset_SimpleSnapshot_ArgentinaEdition_20260820.txt
-- -----------------------------------------------------------------------------
TRUNCATE TABLE `sct2_refset_simple`;
LOAD DATA LOCAL INFILE 'D:/docs/luis/Documentos/sitios/openemr/codigos/SNOMED/sct_carga_20260820/Snapshot/Refset/Content/der2_Refset_SimpleSnapshot_ArgentinaEdition_20260820.txt'
  INTO TABLE `sct2_refset_simple`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY '\t' ESCAPED BY ''
  LINES TERMINATED BY '\r\n'
  IGNORE 1 LINES
  (`id`, `effectiveTime`, `active`, `moduleId`, `refsetId`, `referencedComponentId`)
;

-- -----------------------------------------------------------------------------
-- [7/11] sct2_refset_language
-- 6.394.288 filas (es-419, en-US, en-GB)
-- Archivo: Snapshot/Refset/Language/der2_cRefset_LanguageSnapshot_ArgentinaEdition_20260820.txt
-- -----------------------------------------------------------------------------
TRUNCATE TABLE `sct2_refset_language`;
LOAD DATA LOCAL INFILE 'D:/docs/luis/Documentos/sitios/openemr/codigos/SNOMED/sct_carga_20260820/Snapshot/Refset/Language/der2_cRefset_LanguageSnapshot_ArgentinaEdition_20260820.txt'
  INTO TABLE `sct2_refset_language`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY '\t' ESCAPED BY ''
  LINES TERMINATED BY '\r\n'
  IGNORE 1 LINES
  (`id`, `effectiveTime`, `active`, `moduleId`, `refsetId`, `referencedComponentId`, `acceptabilityId`)
;

-- -----------------------------------------------------------------------------
-- [8/11] sct2_refset_attributevalue
-- 1.045.476 filas
-- Archivo: Snapshot/Refset/Content/der2_cRefset_AttributeValueSnapshot_ArgentinaEdition_20260820.txt
-- -----------------------------------------------------------------------------
TRUNCATE TABLE `sct2_refset_attributevalue`;
LOAD DATA LOCAL INFILE 'D:/docs/luis/Documentos/sitios/openemr/codigos/SNOMED/sct_carga_20260820/Snapshot/Refset/Content/der2_cRefset_AttributeValueSnapshot_ArgentinaEdition_20260820.txt'
  INTO TABLE `sct2_refset_attributevalue`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY '\t' ESCAPED BY ''
  LINES TERMINATED BY '\r\n'
  IGNORE 1 LINES
  (`id`, `effectiveTime`, `active`, `moduleId`, `refsetId`, `referencedComponentId`, `valueId`)
;

-- -----------------------------------------------------------------------------
-- [9/11] sct2_refset_association
-- 227.886 filas (histórico de reemplazos)
-- Archivo: Snapshot/Refset/Content/der2_cRefset_AssociationSnapshot_ArgentinaEdition_20260820.txt
-- -----------------------------------------------------------------------------
TRUNCATE TABLE `sct2_refset_association`;
LOAD DATA LOCAL INFILE 'D:/docs/luis/Documentos/sitios/openemr/codigos/SNOMED/sct_carga_20260820/Snapshot/Refset/Content/der2_cRefset_AssociationSnapshot_ArgentinaEdition_20260820.txt'
  INTO TABLE `sct2_refset_association`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY '\t' ESCAPED BY ''
  LINES TERMINATED BY '\r\n'
  IGNORE 1 LINES
  (`id`, `effectiveTime`, `active`, `moduleId`, `refsetId`, `referencedComponentId`, `targetComponentId`)
;

-- -----------------------------------------------------------------------------
-- [10/11] sct2_refset_simplemap
-- 562.075 filas (mapa simple, incluye CIE-10)
-- Archivo: Snapshot/Refset/Map/der2_sRefset_SimpleMapSnapshot_ArgentinaEdition_20260820.txt
-- -----------------------------------------------------------------------------
TRUNCATE TABLE `sct2_refset_simplemap`;
LOAD DATA LOCAL INFILE 'D:/docs/luis/Documentos/sitios/openemr/codigos/SNOMED/sct_carga_20260820/Snapshot/Refset/Map/der2_sRefset_SimpleMapSnapshot_ArgentinaEdition_20260820.txt'
  INTO TABLE `sct2_refset_simplemap`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY '\t' ESCAPED BY ''
  LINES TERMINATED BY '\r\n'
  IGNORE 1 LINES
  (`id`, `effectiveTime`, `active`, `moduleId`, `refsetId`, `referencedComponentId`, `mapTarget`)
;

-- -----------------------------------------------------------------------------
-- [11/11] sct2_refset_extendedmap
-- 217.373 filas: mapa complejo SNOMED CT -> CIE-10
-- Archivo: Snapshot/Refset/Map/der2_iisssccRefset_ExtendedMapSnapshot_ArgentinaEdition_20260820.txt
-- -----------------------------------------------------------------------------
TRUNCATE TABLE `sct2_refset_extendedmap`;
LOAD DATA LOCAL INFILE 'D:/docs/luis/Documentos/sitios/openemr/codigos/SNOMED/sct_carga_20260820/Snapshot/Refset/Map/der2_iisssccRefset_ExtendedMapSnapshot_ArgentinaEdition_20260820.txt'
  INTO TABLE `sct2_refset_extendedmap`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY '\t' ESCAPED BY ''
  LINES TERMINATED BY '\r\n'
  IGNORE 1 LINES
  (`id`, `effectiveTime`, `active`, `moduleId`, `refsetId`, `referencedComponentId`, `mapGroup`, `mapPriority`, `mapRule`, `mapAdvice`, @mapTarget, `correlationId`, `mapCategoryId`)
  SET `mapTarget` = NULLIF(@mapTarget, '')
;

-- -----------------------------------------------------------------------------
-- Registro de la versión importada (lo lee OpenEMR en la pantalla de
-- Administración -> Codificación -> Tablas estandarizadas).
-- -----------------------------------------------------------------------------
INSERT INTO `standardized_tables_track`
  (`imported_date`, `name`, `revision_version`, `revision_date`, `file_checksum`)
VALUES (NOW(), 'SNOMED', 'Argentina 2026-08-20', '2026-08-20', '');

SELECT 'Carga terminada. Continúe con 03_postcarga.sql.' AS resultado;
