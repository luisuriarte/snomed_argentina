-- =============================================================================
-- SNOMED CT Edición Argentina - OpenEMR
-- 99_verificacion.sql  ::  controles de la carga
-- =============================================================================
--
-- Se ejecuta al final, después de 03_postcarga.sql (y 04 si se hizo).
-- No modifica nada: sólo SELECT.
--
-- Los valores esperados corresponden a la edición Argentina 2026-08-20
-- (dependencia: edición internacional de julio de 2026).
-- Si se cargó con --sin-ingles, la tabla sct2_description tiene 1.617.125
-- filas en vez de 3.337.073 (los 1.719.948 borrados son los de inglés).
--
-- Para consultar el resultado en DBeaver: ejecutar el script y mirar la
-- columna "estado". Todo tiene que decir OK.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- 1) Conteos de las tablas cargadas
-- -----------------------------------------------------------------------------
SELECT 'sct2_concept' AS `tabla`, 600374 AS `esperado`, COUNT(*) AS `obtenido`,
       IF(COUNT(*) = 600374, 'OK', 'REVISAR') AS `estado`
  FROM `sct2_concept`
UNION ALL
SELECT 'sct2_description', 3337073, COUNT(*),
       IF(COUNT(*) = 3337073, 'OK', 'REVISAR') FROM `sct2_description`
UNION ALL
SELECT 'sct2_description (es)', 1617125, COUNT(*),
       IF(COUNT(*) = 1617125, 'OK', 'REVISAR')
  FROM `sct2_description` WHERE `languageCode` = 'es'
UNION ALL
SELECT 'sct2_description (en)', 1719948, COUNT(*),
       IF(COUNT(*) = 1719948, 'OK', 'REVISAR')
  FROM `sct2_description` WHERE `languageCode` = 'en'
UNION ALL
SELECT 'sct2_description activas', 2733899, COUNT(*),
       IF(COUNT(*) = 2733899, 'OK', 'REVISAR')
  FROM `sct2_description` WHERE `active` = 1
UNION ALL
SELECT 'sct2_relationship', 4087686, COUNT(*),
       IF(COUNT(*) = 4087686, 'OK', 'REVISAR') FROM `sct2_relationship`
UNION ALL
SELECT 'sct2_relationship activas', 1751826, COUNT(*),
       IF(COUNT(*) = 1751826, 'OK', 'REVISAR')
  FROM `sct2_relationship` WHERE `active` = 1
UNION ALL
SELECT 'sct2_textdefinition', 29051, COUNT(*),
       IF(COUNT(*) = 29051, 'OK', 'REVISAR') FROM `sct2_textdefinition`
UNION ALL
SELECT 'sct2_rel_concrete', 152675, COUNT(*),
       IF(COUNT(*) = 152675, 'OK', 'REVISAR') FROM `sct2_rel_concrete`
UNION ALL
SELECT 'sct2_refset_simple', 120740, COUNT(*),
       IF(COUNT(*) = 120740, 'OK', 'REVISAR') FROM `sct2_refset_simple`
UNION ALL
SELECT 'sct2_refset_simple activas', 105912, COUNT(*),
       IF(COUNT(*) = 105912, 'OK', 'REVISAR')
  FROM `sct2_refset_simple` WHERE `active` = 1
UNION ALL
SELECT 'sct2_refset_language', 6394288, COUNT(*),
       IF(COUNT(*) = 6394288, 'OK', 'REVISAR') FROM `sct2_refset_language`
UNION ALL
SELECT 'sct2_refset_attributevalue', 1045476, COUNT(*),
       IF(COUNT(*) = 1045476, 'OK', 'REVISAR') FROM `sct2_refset_attributevalue`
UNION ALL
SELECT 'sct2_refset_association', 227886, COUNT(*),
       IF(COUNT(*) = 227886, 'OK', 'REVISAR') FROM `sct2_refset_association`
UNION ALL
SELECT 'sct2_refset_simplemap', 562075, COUNT(*),
       IF(COUNT(*) = 562075, 'OK', 'REVISAR') FROM `sct2_refset_simplemap`
UNION ALL
SELECT 'sct2_refset_extendedmap', 217373, COUNT(*),
       IF(COUNT(*) = 217373, 'OK', 'REVISAR') FROM `sct2_refset_extendedmap`
UNION ALL
SELECT 'sct2_identifier', 0, COUNT(*),
       IF(COUNT(*) = 0, 'OK', 'REVISAR') FROM `sct2_identifier`;

-- Tablas opcionales: sólo se controlan si se cargaron.
SELECT 'sct2_statedrelationship (opcional)' AS `tabla`, 1172419 AS `esperado`,
       COUNT(*) AS `obtenido`,
       IF(COUNT(*) = 1172419, 'OK', 'REVISAR') AS `estado`
  FROM `sct2_statedrelationship`
UNION ALL
SELECT 'sct2_refset_owl (opcional)', 520295, COUNT(*),
       IF(COUNT(*) = 520295, 'OK', 'REVISAR') FROM `sct2_refset_owl`
UNION ALL
SELECT 'sct2_refset_medicinalproducts (opcional)', 19068, COUNT(*),
       IF(COUNT(*) = 19068, 'OK', 'REVISAR') FROM `sct2_refset_medicinalproducts`;

-- -----------------------------------------------------------------------------
-- 2) Tablas derivadas
-- -----------------------------------------------------------------------------
SELECT 'sct2_language_efectivo' AS `tabla`, 2755885 AS `esperado`, COUNT(*) AS `obtenido`,
       IF(COUNT(*) = 2755885, 'OK', 'REVISAR') AS `estado`
  FROM `sct2_language_efectivo`
UNION ALL
SELECT 'sct2_termino_preferido', 600374, COUNT(*),
       IF(COUNT(*) = 600374, 'OK', 'REVISAR') FROM `sct2_termino_preferido`
UNION ALL
SELECT 'sct2_termino_busqueda', 1433264, COUNT(*),
       IF(COUNT(*) = 1433264, 'OK', 'REVISAR') FROM `sct2_termino_busqueda`
UNION ALL
SELECT 'sct2_generico', 5607, COUNT(*),
       IF(COUNT(*) = 5607, 'OK', 'REVISAR') FROM `sct2_generico`
UNION ALL
SELECT 'sct2_marca_generico', 15139, COUNT(*),
       IF(COUNT(*) = 15139, 'OK', 'REVISAR') FROM `sct2_marca_generico`;

-- -----------------------------------------------------------------------------
-- 3) Integridad de los datos
-- -----------------------------------------------------------------------------
-- 3.1 Todo concepto activo debe tener un término preferido. Debe ser 0.
SELECT 'conceptos activos sin término preferido' AS `control`, 0 AS `esperado`,
       COUNT(*) AS `obtenido`,
       IF(COUNT(*) = 0, 'OK', 'REVISAR') AS `estado`
  FROM `sct2_concept` c
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = c.`id`
 WHERE c.`active` = 1 AND tp.`conceptId` IS NULL
UNION ALL
-- 3.2 Términos vacíos. Debe ser 0.
SELECT 'descripciones activas con término vacío', 0, COUNT(*),
       IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM `sct2_description` WHERE `active` = 1 AND TRIM(`term`) = ''
UNION ALL
-- 3.3 El término más largo de esta edición mide 482 bytes (212 descripciones
--     superan los 255 caracteres: por eso la columna es VARCHAR(1024)).
SELECT 'términos de más de 255 caracteres', 212, COUNT(*),
       IF(COUNT(*) = 212, 'OK', 'REVISAR')
  FROM `sct2_description` WHERE CHAR_LENGTH(`term`) > 255
UNION ALL
-- 3.4 Toda relación activa debe tener destino. Debe ser 0.
SELECT 'relaciones activas sin destino', 0, COUNT(*),
       IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM `sct2_relationship` WHERE `active` = 1 AND `destinationId` = 0;

-- -----------------------------------------------------------------------------
-- 4) Regla de idioma argentina
--    Para el español, el módulo argentino (11000221109) tiene que prevalecer
--    sobre el módulo internacional (450829007) cuando ambos definen la misma
--    descripción. Si el conteo es 0, la regla se está aplicando.
-- -----------------------------------------------------------------------------
SELECT 'descripciones es con módulo argentino e internacional' AS `control`,
       0 AS `esperado`, COUNT(*) AS `obtenido`,
       IF(COUNT(*) = 0, 'OK', 'REVISAR') AS `estado`
  FROM `sct2_language_efectivo`
 WHERE `moduleId` = 450829007;

-- -----------------------------------------------------------------------------
-- 5) Catálogos Clinicales
-- -----------------------------------------------------------------------------
SELECT 'genéricos comercializados' AS `control`, 5607 AS `esperado`,
       COUNT(*) AS `obtenido`,
       IF(COUNT(*) = 5607, 'OK', 'REVISAR') AS `estado`
  FROM `sct2_generico`
UNION ALL
SELECT 'marcas del catálogo', 15139, COUNT(*),
       IF(COUNT(*) = 15139, 'OK', 'REVISAR')
  FROM `sct2_marca_generico`
UNION ALL
SELECT 'marcas con un único genérico', 14975, COUNT(*),
       IF(COUNT(*) = 14975, 'OK', 'REVISAR')
  FROM `sct2_marca_generico` WHERE `relaciones` = 1
UNION ALL
SELECT 'marcas con vínculo ambiguo', 164, COUNT(*),
       IF(COUNT(*) = 164, 'OK', 'REVISAR')
  FROM `sct2_marca_generico` WHERE `relaciones` > 1
UNION ALL
SELECT 'marcas comercializadas', 11745, COUNT(*),
       IF(COUNT(*) = 11745, 'OK', 'REVISAR')
  FROM `sct2_marca_generico` WHERE `comercializada` = 1
UNION ALL
SELECT 'marcas con laboratorio', 15139, COUNT(*),
       IF(COUNT(*) = 15139, 'OK', 'REVISAR')
  FROM `sct2_marca_generico` WHERE `laboratorioId` IS NOT NULL
UNION ALL
SELECT 'marcas con categoría de expendio controlado', 151, COUNT(*),
       IF(COUNT(*) = 151, 'OK', 'REVISAR')
  FROM `sct2_marca_generico` WHERE `categoriaControlId` IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 6) Vistas
-- -----------------------------------------------------------------------------
SELECT 'v_sct_generico' AS `vista`, 5607 AS `esperado`, COUNT(*) AS `obtenido`,
       IF(COUNT(*) = 5607, 'OK', 'REVISAR') AS `estado` FROM `v_sct_generico`
UNION ALL
SELECT 'v_sct_marca', 15139, COUNT(*),
       IF(COUNT(*) = 15139, 'OK', 'REVISAR') FROM `v_sct_marca`
UNION ALL
SELECT 'v_sct_generico_marca', 5607, COUNT(*),
       IF(COUNT(*) = 5607, 'OK', 'REVISAR') FROM `v_sct_generico_marca`
UNION ALL
SELECT 'v_sct_vacuna', 407, COUNT(*),
       IF(COUNT(*) = 407, 'OK', 'REVISAR') FROM `v_sct_vacuna`
UNION ALL
SELECT 'v_sct_practica_lab', 1007, COUNT(*),
       IF(COUNT(*) = 1007, 'OK', 'REVISAR') FROM `v_sct_practica_lab`
UNION ALL
SELECT 'v_sct_practica_imagen', 579, COUNT(*),
       IF(COUNT(*) = 579, 'OK', 'REVISAR') FROM `v_sct_practica_imagen`
UNION ALL
SELECT 'v_sct_prestacion', 2143, COUNT(*),
       IF(COUNT(*) = 2143, 'OK', 'REVISAR') FROM `v_sct_prestacion`
UNION ALL
SELECT 'v_sct_odonto_dx', 344, COUNT(*),
       IF(COUNT(*) = 344, 'OK', 'REVISAR') FROM `v_sct_odonto_dx`
UNION ALL
SELECT 'v_sct_odonto_pr', 118, COUNT(*),
       IF(COUNT(*) = 118, 'OK', 'REVISAR') FROM `v_sct_odonto_pr`
UNION ALL
SELECT 'v_sct_eno', 195, COUNT(*),
       IF(COUNT(*) = 195, 'OK', 'REVISAR') FROM `v_sct_eno`
UNION ALL
SELECT 'v_sct_presentacion', 15941, COUNT(*),
       IF(COUNT(*) = 15941, 'OK', 'REVISAR') FROM `v_sct_presentacion`
UNION ALL
SELECT 'v_sct_dispositivo', 1088, COUNT(*),
       IF(COUNT(*) = 1088, 'OK', 'REVISAR') FROM `v_sct_dispositivo`;

-- -----------------------------------------------------------------------------
-- 7) Resumen de refsets (referencia rápida)
-- -----------------------------------------------------------------------------
SELECT * FROM `v_sct_refset_resumen` ORDER BY `activos` DESC;

-- -----------------------------------------------------------------------------
-- 8) Registro de la versión importada
-- -----------------------------------------------------------------------------
SELECT `imported_date`, `name`, `revision_version`, `revision_date`, `file_checksum`
  FROM `standardized_tables_track`
 WHERE `name` = 'SNOMED'
 ORDER BY `id` DESC
 LIMIT 5;

-- -----------------------------------------------------------------------------
-- 9) Códigos publicados (sólo si se ejecutó 04_codigos_opcional.sql)
-- -----------------------------------------------------------------------------
SELECT `code_type`, COUNT(*) AS `codigos`
  FROM `codes`
 WHERE `code_type` BETWEEN 201 AND 206
 GROUP BY `code_type`
 ORDER BY `code_type`;

-- -----------------------------------------------------------------------------
-- 10) Mapeos Excel NBU y GTIN (sólo si se ejecutó 05_map_excel.sql)
-- -----------------------------------------------------------------------------
SELECT 'sct2_map_nbu' AS `tabla`, 425 AS `esperado`, COUNT(*) AS `obtenido`,
       IF(COUNT(*) = 425, 'OK', 'REVISAR') AS `estado`
  FROM `sct2_map_nbu`
UNION ALL
SELECT 'sct2_map_gtin', 15500, COUNT(*),
       IF(COUNT(*) = 15500, 'OK', 'REVISAR')
  FROM `sct2_map_gtin`;

-- Vistas derivadas de los mapeos Excel
SELECT 'v_sct_map_nbu' AS `vista`, 425 AS `esperado`, COUNT(*) AS `obtenido`,
       IF(COUNT(*) = 425, 'OK', 'REVISAR') AS `estado`
  FROM `v_sct_map_nbu`
UNION ALL
SELECT 'v_sct_map_gtin', 15500, COUNT(*),
       IF(COUNT(*) = 15500, 'OK', 'REVISAR')
  FROM `v_sct_map_gtin`;

-- Integridad: todas las entradas NBU deben tener su sctid en sct2_concept.
SELECT 'NBU: sctids sin concepto SNOMED' AS `control`, 0 AS `esperado`,
       COUNT(*) AS `obtenido`,
       IF(COUNT(*) = 0, 'OK', 'REVISAR') AS `estado`
  FROM `sct2_map_nbu` n
  LEFT JOIN `sct2_concept` c ON c.`id` = n.`sctid`
 WHERE c.`id` IS NULL
UNION ALL
-- Integridad: todos los RPCD del GTIN deben existir en sct2_concept.
SELECT 'GTIN: rpcd_ids sin concepto SNOMED', 0, COUNT(*),
       IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM `sct2_map_gtin` g
  LEFT JOIN `sct2_concept` c ON c.`id` = g.`rpcd_id`
 WHERE c.`id` IS NULL;

SELECT 'Verificación terminada. Revisá que todas las filas digan OK.' AS resultado;
