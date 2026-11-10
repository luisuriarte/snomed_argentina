-- =============================================================================
-- SNOMED CT Edición Argentina - OpenEMR
-- 03_postcarga.sql  ::  índices, tablas derivadas y vistas
-- =============================================================================
--
-- Cuándo se ejecuta: DESPUÉS de 02_carga.sql y ANTES de 04_codigos_opcional.sql.
-- Es idempotente: se puede volver a ejecutar sin romper nada (los índices se
-- crean sólo si no existen y las tablas derivadas se recalculan desde cero).
--
-- Qué hace, en orden:
--   1. Crea los índices secundarios (que en 01 no se crean, para que la carga
--      de 02 sea rápida).
--   2. Reconstruye las tablas derivadas:
--        sct2_language_efectivo  -> idioma/aceptabilidad efectiva por descripción
--        sct2_termino_preferido  -> un término por concepto (español primero)
--        sct2_termino_busqueda   -> índice de búsqueda con sinónimos
--        sct2_generico           -> catálogo de fármacos genéricos
--        sct2_marca_generico     -> vínculo marca -> genérico / laboratorio
--   3. Carga el catálogo de refsets con sus nombres.
--   4. Crea las vistas de consulta.
--   5. ANALYZE TABLE.
--
-- REQUISITOS: MySQL 8.0.14+ o MariaDB 10.4+ (ROW_NUMBER).
-- Tiempo estimado con los datos reales: 10-25 minutos.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- 0) Procedimiento auxiliar: agregar un índice sólo si todavía no existe
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sct_agregar_indice`;
DELIMITER $$
CREATE PROCEDURE `sct_agregar_indice`(
  IN p_tabla  VARCHAR(64),
  IN p_indice VARCHAR(64),
  IN p_clausula VARCHAR(512)
)
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.statistics
     WHERE table_schema = DATABASE()
       AND table_name   = p_tabla
       AND index_name   = p_indice
  ) THEN
    SET @sct_ddl = CONCAT('ALTER TABLE `', p_tabla, '` ADD ', p_clausula);
    PREPARE sct_stmt FROM @sct_ddl;
    EXECUTE sct_stmt;
    DEALLOCATE PREPARE sct_stmt;
  END IF;
END$$
DELIMITER ;

-- -----------------------------------------------------------------------------
-- 1) Índices secundarios
-- -----------------------------------------------------------------------------
CALL sct_agregar_indice('sct2_concept',                 'idx_concept_active',   'INDEX `idx_concept_active` (`active`)');
CALL sct_agregar_indice('sct2_description',             'idx_desc_concept',     'INDEX `idx_desc_concept` (`conceptId`)');
CALL sct_agregar_indice('sct2_description',             'idx_desc_lang',        'INDEX `idx_desc_lang` (`languageCode`, `active`)');
CALL sct_agregar_indice('sct2_relationship',            'idx_rel_source',       'INDEX `idx_rel_source` (`sourceId`, `active`, `typeId`)');
CALL sct_agregar_indice('sct2_relationship',            'idx_rel_dest',         'INDEX `idx_rel_dest` (`destinationId`)');
CALL sct_agregar_indice('sct2_relationship',            'idx_rel_type',         'INDEX `idx_rel_type` (`typeId`, `active`)');
CALL sct_agregar_indice('sct2_statedrelationship',      'idx_stated_source',    'INDEX `idx_stated_source` (`sourceId`)');
CALL sct_agregar_indice('sct2_rel_concrete',            'idx_concrete_source',  'INDEX `idx_concrete_source` (`sourceId`, `active`, `typeId`)');
CALL sct_agregar_indice('sct2_refset_simple',           'idx_simple_refset',    'INDEX `idx_simple_refset` (`refsetId`, `active`, `referencedComponentId`)');
CALL sct_agregar_indice('sct2_refset_simple',           'idx_simple_comp',      'INDEX `idx_simple_comp` (`referencedComponentId`)');
CALL sct_agregar_indice('sct2_refset_language',         'idx_lang_refset',      'INDEX `idx_lang_refset` (`refsetId`, `active`)');
CALL sct_agregar_indice('sct2_refset_language',         'idx_lang_comp',        'INDEX `idx_lang_comp` (`referencedComponentId`)');
CALL sct_agregar_indice('sct2_refset_attributevalue',   'idx_attr_refset',      'INDEX `idx_attr_refset` (`refsetId`, `referencedComponentId`)');
CALL sct_agregar_indice('sct2_refset_association',      'idx_assoc_refset',     'INDEX `idx_assoc_refset` (`refsetId`)');
CALL sct_agregar_indice('sct2_refset_simplemap',        'idx_smap_refset',      'INDEX `idx_smap_refset` (`refsetId`, `referencedComponentId`)');
CALL sct_agregar_indice('sct2_refset_extendedmap',      'idx_emap_refset',      'INDEX `idx_emap_refset` (`refsetId`, `active`, `referencedComponentId`)');
CALL sct_agregar_indice('sct2_refset_extendedmap',      'idx_emap_target',      'INDEX `idx_emap_target` (`mapTarget`)');
CALL sct_agregar_indice('sct2_refset_medicinalproducts','idx_mp_refset',        'INDEX `idx_mp_refset` (`refsetId`, `referencedComponentId`)');
CALL sct_agregar_indice('sct2_refset_owl',              'idx_owl_refset',       'INDEX `idx_owl_refset` (`refsetId`)');
CALL sct_agregar_indice('sct2_termino_preferido',       'idx_tp_desc',          'INDEX `idx_tp_desc` (`descriptionId`)');
CALL sct_agregar_indice('sct2_termino_preferido',       'idx_tp_lang',          'INDEX `idx_tp_lang` (`languageCode`)');
CALL sct_agregar_indice('sct2_termino_busqueda',        'idx_tb_concept',       'INDEX `idx_tb_concept` (`conceptId`)');

-- -----------------------------------------------------------------------------
-- 2) Tablas derivadas
-- -----------------------------------------------------------------------------

-- 2.1 Idioma y aceptabilidad efectiva de cada descripción.
--     Regla argentina: si la misma descripción tiene registro en el módulo
--     argentino (11000221109), ese prevalece sobre el del módulo internacional
--     de español (450829007). Dentro de cada módulo gana el término PREFERIDO
--     y, a igualdad de todo, el registro más reciente.
--     Se incluyen los tres refsets de idioma: es-419, en-US y en-GB.
TRUNCATE TABLE `sct2_language_efectivo`;
INSERT INTO `sct2_language_efectivo`
  (`referencedComponentId`, `acceptabilityId`, `moduleId`, `effectiveTime`)
SELECT `referencedComponentId`, `acceptabilityId`, `moduleId`, `effectiveTime`
FROM (
  SELECT l.`referencedComponentId`,
         l.`acceptabilityId`,
         l.`moduleId`,
         l.`effectiveTime`,
         ROW_NUMBER() OVER (
           PARTITION BY l.`referencedComponentId`
           ORDER BY (l.`acceptabilityId` = 900000000000548007) DESC,
                    (l.`moduleId` = 11000221109) DESC,
                    l.`effectiveTime` DESC,
                    l.`id` DESC
         ) AS rn
    FROM `sct2_refset_language` l
   WHERE l.`active` = 1
     AND l.`refsetId` IN (450828004, 900000000000509007, 900000000000508004)
) x
WHERE x.rn = 1;

-- 2.2 Un término por concepto.
--     Prioridad: español > inglés; dentro del idioma, PREFERIDO > ACEPTABLE;
--     a igualdad, el módulo argentino; después, el registro más reciente.
--     Así ningún concepto activo queda sin término (en esta edición los
--     600.374 conceptos tienen al menos una descripción activa).
TRUNCATE TABLE `sct2_termino_preferido`;
INSERT INTO `sct2_termino_preferido`
  (`conceptId`, `descriptionId`, `term`, `languageCode`)
SELECT `conceptId`, `descriptionId`, `term`, `languageCode`
FROM (
  SELECT d.`conceptId`,
         d.`id` AS `descriptionId`,
         d.`term`,
         d.`languageCode`,
         ROW_NUMBER() OVER (
           PARTITION BY d.`conceptId`
           ORDER BY CASE WHEN d.`languageCode` = 'es' THEN 0 ELSE 1 END,
                    CASE le.`acceptabilityId`
                         WHEN 900000000000548007 THEN 0
                         WHEN 900000000000549004 THEN 1
                         ELSE 2 END,
                    (le.`moduleId` = 11000221109) DESC,
                    d.`effectiveTime` DESC,
                    d.`id` DESC
         ) AS rn
    FROM `sct2_description` d
    LEFT JOIN `sct2_language_efectivo` le
           ON le.`referencedComponentId` = d.`id`
   WHERE d.`active` = 1
) x
WHERE x.rn = 1;

-- 2.3 Índice de búsqueda: todas las descripciones activas en español y, para
--     los conceptos que no tienen ninguna, las descripciones en inglés.
--     Se agrega el término preferido del concepto para mostrarlo al lado.
DROP TEMPORARY TABLE IF EXISTS `tmp_conceptos_es`;
CREATE TEMPORARY TABLE `tmp_conceptos_es` (
  `conceptId` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`conceptId`)
) ENGINE=InnoDB;
INSERT INTO `tmp_conceptos_es` (`conceptId`)
SELECT DISTINCT d.`conceptId`
  FROM `sct2_description` d
 WHERE d.`active` = 1
   AND d.`languageCode` = 'es';

TRUNCATE TABLE `sct2_termino_busqueda`;
INSERT INTO `sct2_termino_busqueda`
  (`descriptionId`, `conceptId`, `term`, `terminoPreferido`, `languageCode`)
SELECT d.`id`, d.`conceptId`, d.`term`, tp.`term`, d.`languageCode`
  FROM `sct2_description` d
  JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = d.`conceptId`
  LEFT JOIN `tmp_conceptos_es` e ON e.`conceptId` = d.`conceptId`
 WHERE d.`active` = 1
   AND (d.`languageCode` = 'es' OR e.`conceptId` IS NULL);
DROP TEMPORARY TABLE IF EXISTS `tmp_conceptos_es`;

-- El índice FULLTEXT se crea después de cargar: insertar 1,6 millones de filas
-- en una tabla con FULLTEXT es varias veces más lento.
CALL sct_agregar_indice('sct2_termino_busqueda', 'ft_tb_term', 'FULLTEXT KEY `ft_tb_term` (`term`)');

-- 2.4 Catálogo de fármacos genéricos prescribibles.
--     574471000221107 = con unidad de presentación definida, comercializados.
--     574481000221105 = sin unidad de presentación definida, comercializados.
TRUNCATE TABLE `sct2_generico`;
INSERT INTO `sct2_generico` (`conceptId`, `conUnidad`, `formaFarmaceuticaId`)
SELECT g.`conceptoId`,
       MAX(g.`conUnidad`),
       (SELECT MAX(r.`destinationId`)
          FROM `sct2_relationship` r
         WHERE r.`sourceId` = g.`conceptoId`
           AND r.`active` = 1
           AND r.`typeId` = 411116001)   -- 411116001 | forma farmacéutica |
  FROM (
    SELECT r.`referencedComponentId` AS `conceptoId`, 1 AS `conUnidad`
      FROM `sct2_refset_simple` r
     WHERE r.`refsetId` = 574471000221107 AND r.`active` = 1
    UNION
    SELECT r.`referencedComponentId`, 0
      FROM `sct2_refset_simple` r
     WHERE r.`refsetId` = 574481000221105 AND r.`active` = 1
  ) g
 GROUP BY g.`conceptoId`;

-- 2.5 Vínculo marca -> genérico.
--     El genérico de una marca se obtiene de la relación inferida
--     116680003 | es un |. Si una marca tiene más de un destino (109 de
--     11.745 en esta edición) queda con genericoId = NULL porque el vínculo
--     es ambiguo.
--     425071000221108 = fármacos de uso clínico comerciales (catálogo de marcas)
--     574461000221103 = los que están en estado comercializado
TRUNCATE TABLE `sct2_marca_generico`;
INSERT INTO `sct2_marca_generico`
  (`marcaId`, `genericoId`, `relaciones`, `comercializada`,
   `laboratorioId`, `condicionExpendioId`, `categoriaControlId`)
SELECT b.`marcaId`,
       CASE WHEN r.`n` = 1 THEN r.`d` ELSE NULL END,
       COALESCE(r.`n`, 0),
       CASE WHEN c.`marcaId` IS NULL THEN 0 ELSE 1 END,
       lab.`d`,
       exp.`d`,
       ctrl.`d`
  FROM (
    SELECT DISTINCT r.`referencedComponentId` AS `marcaId`
      FROM `sct2_refset_simple` r
     WHERE r.`refsetId` = 425071000221108 AND r.`active` = 1
  ) b
  LEFT JOIN (
    SELECT r.`sourceId`, COUNT(*) AS `n`, MIN(r.`destinationId`) AS `d`
      FROM `sct2_relationship` r
      JOIN (
        SELECT DISTINCT `referencedComponentId` FROM `sct2_refset_simple`
         WHERE `refsetId` = 425071000221108 AND `active` = 1
      ) bb ON bb.`referencedComponentId` = r.`sourceId`
     WHERE r.`active` = 1 AND r.`typeId` = 116680003
     GROUP BY r.`sourceId`
  ) r ON r.`sourceId` = b.`marcaId`
  LEFT JOIN (
    SELECT DISTINCT `referencedComponentId` AS `marcaId`
      FROM `sct2_refset_simple`
     WHERE `refsetId` = 574461000221103 AND `active` = 1
  ) c ON c.`marcaId` = b.`marcaId`
  LEFT JOIN (
    SELECT `sourceId`, MIN(`destinationId`) AS `d`
      FROM `sct2_relationship`
     WHERE `active` = 1 AND `typeId` = 774159003
     GROUP BY `sourceId`
  ) lab ON lab.`sourceId` = b.`marcaId`
  LEFT JOIN (
    SELECT `sourceId`, MIN(`destinationId`) AS `d`
      FROM `sct2_relationship`
     WHERE `active` = 1 AND `typeId` = 574941000221106
     GROUP BY `sourceId`
  ) exp ON exp.`sourceId` = b.`marcaId`
  LEFT JOIN (
    SELECT `sourceId`, MIN(`destinationId`) AS `d`
      FROM `sct2_relationship`
     WHERE `active` = 1 AND `typeId` = 579631000221106
     GROUP BY `sourceId`
  ) ctrl ON ctrl.`sourceId` = b.`marcaId`;

-- -----------------------------------------------------------------------------
-- 3) Catálogo de refsets (nombres publicados en las Notas de la Edición)
-- -----------------------------------------------------------------------------
INSERT INTO `sct2_refset_catalogo` (`refsetId`, `nombre`, `categoria`, `descripcion`) VALUES
 (723264001,        'Presentaciones farmacéuticas comerciales (VNM)',                 'medicamentos', ''),
 (574451000221100,  'Presentaciones farmacéuticas comerciales (DNM)',                 'medicamentos', 'Presentaciones y medicamentos autorizados por ANMAT desde 2019, estén o no comercializados'),
 (331101000221109,  'Presentaciones farmacéuticas comerciales comercializadas (DNM)', 'medicamentos', 'Presentaciones en estado de comercialización vigente según el Vademecum de ANMAT'),
 (425071000221108,  'Fármacos de uso clínico comerciales (DNM)',                      'medicamentos', 'Catálogo de marcas comerciales del DNM'),
 (574461000221103,  'Fármacos de uso clínico comerciales comercializados (DNM)',      'medicamentos', 'Marcas que tienen al menos una presentación comercializada'),
 (425081000221106,  'Fármacos de uso clínico con unidad de presentación (DNM)',        'medicamentos', ''),
 (574471000221107,  'Fármacos de uso clínico con unidad comercializados (DNM)',       'medicamentos', 'Genéricos prescribibles con unidad de presentación definida'),
 (425091000221109,  'Fármacos de uso clínico sin unidad de presentación (DNM)',       'medicamentos', ''),
 (574481000221105,  'Fármacos de uso clínico sin unidad comercializados (DNM)',       'medicamentos', 'Genéricos prescribibles sin unidad de presentación definida'),
 (577281000221100,  'Prácticas y procedimientos de la Edición Argentina',              'practicas',    'Incluye los conceptos usados en el mapeo a NBU'),
 (537301000221103,  'Prácticas de laboratorio de Argentina',                          'practicas',    'Ampliado con todos los conceptos del mapeo a NBU 2026'),
 (536561000221108,  'Prácticas prescribibles de diagnóstico por imágenes',           'practicas',    ''),
 (371201000221100,  'Prácticas y procedimientos SUMAR',                               'practicas',    ''),
 (398711000221107,  'Diagnósticos de odontología de Argentina',                      'odontologia',  ''),
 (399211000221109,  'Procedimientos de odontología de Argentina',                     'odontologia',  ''),
 (2281000221106,    'Inmunizaciones de Argentina',                                   'vacunas',      ''),
 (651000221107,     'Enfermedades de notificación obligatoria (ENO)',                'eno',          ''),
 (869651000221108,  'Productos sanitarios y dispositivos médicos',                   'dispositivos', ''),
 (93491000221103,   'Pueblos originarios',                                           'poblaciones',  '')
ON DUPLICATE KEY UPDATE
  `nombre`      = VALUES(`nombre`),
  `categoria`   = VALUES(`categoria`),
  `descripcion` = VALUES(`descripcion`);

-- -----------------------------------------------------------------------------
-- 4) Vistas
-- -----------------------------------------------------------------------------

-- 4.1 Resumen de todos los refsets con su cantidad de miembros.
CREATE OR REPLACE VIEW `v_sct_refset_resumen` AS
SELECT r.`refsetId`,
       COALESCE(c.`nombre`, CONCAT('Refset ', r.`refsetId`)) AS `nombre`,
       COALESCE(c.`categoria`, 'otros')                         AS `categoria`,
       COUNT(*)                                                AS `miembros`,
       CAST(SUM(r.`active` = 1) AS UNSIGNED)                   AS `activos`,
       COUNT(DISTINCT r.`referencedComponentId`)               AS `conceptosDistintos`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_refset_catalogo` c ON c.`refsetId` = r.`refsetId`
 GROUP BY r.`refsetId`, c.`nombre`, c.`categoria`;

-- 4.2 Miembros de un refset con su término.
CREATE OR REPLACE VIEW `v_sct_refset_miembro` AS
SELECT r.`refsetId`,
       COALESCE(c.`nombre`, CONCAT('Refset ', r.`refsetId`)) AS `refset`,
       r.`referencedComponentId`                             AS `conceptoId`,
       tp.`term`                                             AS `termino`,
       r.`active`                                            AS `activo`,
       r.`effectiveTime`                                     AS `vigenteDesde`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_refset_catalogo` c ON c.`refsetId` = r.`refsetId`
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`;

-- 4.3 Término preferido de cada concepto.
CREATE OR REPLACE VIEW `v_sct_termino` AS
SELECT `conceptId` AS `conceptoId`, `term` AS `termino`, `languageCode` AS `idioma`
  FROM `sct2_termino_preferido`;

-- 4.4 Genéricos prescribibles.
CREATE OR REPLACE VIEW `v_sct_generico` AS
SELECT g.`conceptId`                AS `conceptoId`,
       tp.`term`                    AS `termino`,
       g.`conUnidad`                AS `conUnidad`,
       g.`formaFarmaceuticaId`      AS `formaFarmaceuticaId`,
       ff.`term`                    AS `formaFarmaceutica`
  FROM `sct2_generico` g
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = g.`conceptId`
  LEFT JOIN `sct2_termino_preferido` ff ON ff.`conceptId` = g.`formaFarmaceuticaId`;

-- 4.5 Marcas comerciales: genérico, laboratorio y condición de expendio.
CREATE OR REPLACE VIEW `v_sct_marca` AS
SELECT m.`marcaId`              AS `marcaId`,
       tp.`term`                AS `marca`,
       m.`comercializada`       AS `comercializada`,
       m.`genericoId`           AS `genericoId`,
       gp.`term`                AS `generico`,
       m.`laboratorioId`        AS `laboratorioId`,
       lp.`term`                AS `laboratorio`,
       m.`condicionExpendioId`  AS `condicionExpendioId`,
       ep.`term`                AS `condicionExpendio`,
       m.`categoriaControlId`   AS `categoriaControlId`,
       cp.`term`                AS `categoriaControl`
  FROM `sct2_marca_generico` m
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = m.`marcaId`
  LEFT JOIN `sct2_termino_preferido` gp ON gp.`conceptId` = m.`genericoId`
  LEFT JOIN `sct2_termino_preferido` lp ON lp.`conceptId` = m.`laboratorioId`
  LEFT JOIN `sct2_termino_preferido` ep ON ep.`conceptId` = m.`condicionExpendioId`
  LEFT JOIN `sct2_termino_preferido` cp ON cp.`conceptId` = m.`categoriaControlId`;

-- 4.6 Genéricos y cuántas marcas tienen.
CREATE OR REPLACE VIEW `v_sct_generico_marca` AS
SELECT g.`conceptId`              AS `genericoId`,
       tp.`term`                  AS `generico`,
       COUNT(m.`marcaId`)          AS `marcas`,
       CAST(COALESCE(SUM(m.`comercializada`), 0) AS UNSIGNED) AS `marcasComercializadas`
  FROM `sct2_generico` g
  JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = g.`conceptId`
  LEFT JOIN `sct2_marca_generico` m ON m.`genericoId` = g.`conceptId`
 GROUP BY g.`conceptId`, tp.`term`;

-- 4.7 Mapeo SNOMED CT -> CIE-10 (refset complejo 447562003).
CREATE OR REPLACE VIEW `v_sct_cie10` AS
SELECT em.`referencedComponentId` AS `conceptoId`,
       tp.`term`                   AS `termino`,
       em.`mapTarget`              AS `cie10`,
       em.`mapGroup`               AS `grupo`,
       em.`mapPriority`            AS `prioridad`,
       em.`mapRule`                AS `regla`,
       em.`correlationId`          AS `correlacion`
  FROM `sct2_refset_extendedmap` em
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = em.`referencedComponentId`
 WHERE em.`active` = 1
   AND em.`refsetId` = 447562003
   AND em.`mapTarget` IS NOT NULL;

-- 4.8 Conjuntos con nombre propio.
CREATE OR REPLACE VIEW `v_sct_eno` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 651000221107 AND r.`active` = 1;

CREATE OR REPLACE VIEW `v_sct_vacuna` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 2281000221106 AND r.`active` = 1;

CREATE OR REPLACE VIEW `v_sct_practica_lab` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 537301000221103 AND r.`active` = 1;

CREATE OR REPLACE VIEW `v_sct_practica_imagen` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 536561000221108 AND r.`active` = 1;

CREATE OR REPLACE VIEW `v_sct_prestacion` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 577281000221100 AND r.`active` = 1;

CREATE OR REPLACE VIEW `v_sct_odonto_dx` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 398711000221107 AND r.`active` = 1;

CREATE OR REPLACE VIEW `v_sct_odonto_pr` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 399211000221109 AND r.`active` = 1;

CREATE OR REPLACE VIEW `v_sct_presentacion` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 331101000221109 AND r.`active` = 1;

CREATE OR REPLACE VIEW `v_sct_dispositivo` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 869651000221108 AND r.`active` = 1;

-- 4.9  Especialidades reconocidas por el Ministerio de Salud de la Nación.
CREATE OR REPLACE VIEW `v_sct_especialidad` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 331151000221108 AND r.`active` = 1;

-- 4.10 Profesiones matriculadas vinculadas a la atención en salud.
CREATE OR REPLACE VIEW `v_sct_profesion` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 2271000221108 AND r.`active` = 1;

-- 4.11 Ocupaciones vinculadas a especialidades (Ministerio de Salud).
CREATE OR REPLACE VIEW `v_sct_ocupacion` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 331131000221104 AND r.`active` = 1;

-- 4.12 Fármacos del Programa Remediar / Medicamentos Esenciales del Ministerio.
CREATE OR REPLACE VIEW `v_sct_remediar` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 349091000221101 AND r.`active` = 1;

-- 4.13 Diagnósticos del Programa SUMAR (facturación).
CREATE OR REPLACE VIEW `v_sct_sumar_diag` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 371191000221103 AND r.`active` = 1;

-- 4.14 Procedimientos/prestaciones del Programa SUMAR (facturación).
CREATE OR REPLACE VIEW `v_sct_sumar_proced` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 371201000221100 AND r.`active` = 1;

-- 4.15 Ámbitos de atención del Programa SUMAR.
CREATE OR REPLACE VIEW `v_sct_sumar_ambito` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 371221000221107 AND r.`active` = 1;

-- 4.16 Profesionales de salud vinculados al Programa SUMAR.
CREATE OR REPLACE VIEW `v_sct_sumar_profesional` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 371211000221102 AND r.`active` = 1;

-- 4.17 Pueblos originarios argentinos reconocidos por el Ministerio de Salud.
CREATE OR REPLACE VIEW `v_sct_pueblo_originario` AS
SELECT r.`referencedComponentId` AS `conceptoId`, tp.`term` AS `termino`
  FROM `sct2_refset_simple` r
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = r.`referencedComponentId`
 WHERE r.`refsetId` = 93491000221103 AND r.`active` = 1;

-- 4.18 Mapeo SNOMED CT → NOMIVAC (vacunas). Refset de mapa simple.
--      Columna mapTarget contiene el código NOMIVAC.
CREATE OR REPLACE VIEW `v_sct_nomivac` AS
SELECT sm.`referencedComponentId` AS `conceptoId`,
       tp.`term`                  AS `termino`,
       sm.`mapTarget`             AS `codigoNOMIVAC`
  FROM `sct2_refset_simplemap` sm
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = sm.`referencedComponentId`
 WHERE sm.`refsetId` = 401211000221103 AND sm.`active` = 1;

-- 4.19 Mapeo SNOMED CT → Nomenclador Bioquímico Único (NBU).
--      Requiere haber ejecutado 05_map_excel.sql.
CREATE OR REPLACE VIEW `v_sct_map_nbu` AS
SELECT n.`sctid`,
       tp.`term`          AS `practica_sct`,
       n.`codigoNBU`,
       n.`determinacion`  AS `determinacion_nbu`
  FROM `sct2_map_nbu` n
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = n.`sctid`;

-- 4.20 Mapeo GTIN → Presentación farmacéutica comercial SNOMED CT.
--      Requiere haber ejecutado 05_map_excel.sql.
CREATE OR REPLACE VIEW `v_sct_map_gtin` AS
SELECT g.`gtin`,
       g.`condicion`,
       g.`rpcd_id`   AS `sctid`,
       tp.`term`     AS `termino_sct`,
       g.`rpcd_fsn`  AS `fsn`
  FROM `sct2_map_gtin` g
  LEFT JOIN `sct2_termino_preferido` tp ON tp.`conceptId` = g.`rpcd_id`;

-- -----------------------------------------------------------------------------
-- 5) Análisis de estadísticas
-- -----------------------------------------------------------------------------
-- Nota: sct2_map_nbu y sct2_map_gtin se analizan en 05_map_excel.sql.
ANALYZE TABLE `sct2_concept`, `sct2_description`, `sct2_relationship`,
               `sct2_refset_simple`, `sct2_refset_language`,
               `sct2_termino_preferido`, `sct2_termino_busqueda`,
               `sct2_generico`, `sct2_marca_generico`;

DROP PROCEDURE IF EXISTS `sct_agregar_indice`;

SELECT 'Postcarga terminada: índices, tablas derivadas y vistas listas.' AS resultado;
