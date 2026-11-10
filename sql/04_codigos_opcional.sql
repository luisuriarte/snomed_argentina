-- =============================================================================
-- SNOMED CT Edición Argentina - OpenEMR
-- 04_codigos_opcional.sql  ::  publica la terminología en la tabla `codes`
-- =============================================================================
--
-- OPCIONAL. Sólo hace falta si se quiere que los conceptos de SNOMED CT
-- aparezcan en los listados de OpenEMR (diagnósticos, procedimientos,
-- medicamentos, problemas de la ficha, autocompletado de la emisión, etc.).
--
-- QUÉ HACE Y QUÉ NO HACE
--   * Crea 6 tipos de código PROPIOS (201 a 206). No toca los tipos que ya
--     existen: 100 (CVX), 103 (SNOMED), 107 (SNOMED-CT), 108 (SNOMED-PR),
--     109 (medicamentos RXCUI).
--   * NO borra filas de `codes`. El proyecto anterior hacía
--     "DELETE FROM codes WHERE code_type = '100' / '109'"; eso destruía
--     datos de otroslistados y queda deliberadamente fuera de este script.
--   * `codes.code` se completa con el ID de concepto de SNOMED CT (no con un
--     ROW_NUMBER()), para que el código sea el identificador real y se pueda
--     cruzar con la terminología y con las vistas v_sct_*.
--   * Es idempotente: se puede volver a ejecutar, no duplica nada.
--
-- REQUISITOS: haber ejecutado 03_postcarga.sql (las vistas de abajo leen de
-- las tablas derivadas).
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- 0) Verificación previa: ¿están libres los tipos de código 201 a 206?
--    Si alguno ya existe con otro nombre, el INSERT IGNORE lo va a saltear y
--    los códigos van a quedar colgados de un tipo de código ajeno.
-- -----------------------------------------------------------------------------
SELECT `ct_key`, `ct_id`, `ct_label` FROM `code_types`
 WHERE `ct_id` BETWEEN 200 AND 210;

-- -----------------------------------------------------------------------------
-- 1) Tipos de código
--    ct_key <= 15 caracteres, ct_label <= 31 caracteres.
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO `code_types`
  (`ct_key`, `ct_id`, `ct_seq`, `ct_mod`, `ct_just`, `ct_mask`, `ct_fee`, `ct_rel`,
   `ct_nofs`, `ct_diag`, `ct_active`, `ct_label`, `ct_external`, `ct_claim`,
   `ct_proc`, `ct_term`, `ct_problem`, `ct_drug`)
VALUES
  ('SNOMEDAR',    201, 201, 0, '', '', 0, 0, 1, 0, 1, 'SNOMED AR - Genéricos',    0, 0, 0, 1, 0, 1),
  ('SNOMEDARVAC', 202, 202, 0, '', '', 0, 0, 1, 0, 1, 'SNOMED AR - Vacunas',      0, 0, 0, 1, 0, 1),
  ('SNOMEDARLAB', 203, 203, 0, '', '', 0, 0, 1, 0, 1, 'SNOMED AR - Laboratorio',   0, 0, 0, 1, 0, 0),
  ('SNOMEDARIMG', 204, 204, 0, '', '', 0, 0, 1, 0, 1, 'SNOMED AR - Imágenes',     0, 0, 1, 1, 0, 0),
  ('SNOMEDARODO', 205, 205, 0, '', '', 0, 0, 1, 1, 1, 'SNOMED AR - Odontología',  0, 0, 1, 1, 1, 0),
  ('SNOMEDARPR',  206, 206, 0, '', '', 0, 0, 1, 0, 1, 'SNOMED AR - Prácticas',    0, 0, 1, 1, 0, 0);

-- -----------------------------------------------------------------------------
-- 2) Genéricos prescribibles (5.607 en la edición 2026-08-20)
-- -----------------------------------------------------------------------------
INSERT INTO `codes`
  (`code_text`, `code_text_short`, `code`, `code_type`, `modifier`, `units`, `fee`,
   `superbill`, `related_code`, `taxrates`, `cyp_factor`, `active`, `reportable`,
   `financial_reporting`, `revenue_code`)
SELECT v.`termino`,
       v.`termino`,
       CAST(v.`conceptoId` AS CHAR),
       201,
       '', 0, NULL, '', '', '', 0, 1, 0, 0, ''
  FROM `v_sct_generico` v
 WHERE NOT EXISTS (
       SELECT 1 FROM `codes` c
        WHERE c.`code_type` = 201
          AND c.`code` = CAST(v.`conceptoId` AS CHAR));

-- -----------------------------------------------------------------------------
-- 3) Inmunizaciones de Argentina (407)
-- -----------------------------------------------------------------------------
INSERT INTO `codes`
  (`code_text`, `code_text_short`, `code`, `code_type`, `modifier`, `units`, `fee`,
   `superbill`, `related_code`, `taxrates`, `cyp_factor`, `active`, `reportable`,
   `financial_reporting`, `revenue_code`)
SELECT v.`termino`,
       v.`termino`,
       CAST(v.`conceptoId` AS CHAR),
       202,
       '', 0, NULL, '', '', '', 0, 1, 0, 0, ''
  FROM `v_sct_vacuna` v
 WHERE NOT EXISTS (
       SELECT 1 FROM `codes` c
        WHERE c.`code_type` = 202
          AND c.`code` = CAST(v.`conceptoId` AS CHAR));

-- -----------------------------------------------------------------------------
-- 4) Prácticas de laboratorio de Argentina (1.007)
-- -----------------------------------------------------------------------------
INSERT INTO `codes`
  (`code_text`, `code_text_short`, `code`, `code_type`, `modifier`, `units`, `fee`,
   `superbill`, `related_code`, `taxrates`, `cyp_factor`, `active`, `reportable`,
   `financial_reporting`, `revenue_code`)
SELECT v.`termino`,
       v.`termino`,
       CAST(v.`conceptoId` AS CHAR),
       203,
       '', 0, NULL, '', '', '', 0, 1, 0, 0, ''
  FROM `v_sct_practica_lab` v
 WHERE NOT EXISTS (
       SELECT 1 FROM `codes` c
        WHERE c.`code_type` = 203
          AND c.`code` = CAST(v.`conceptoId` AS CHAR));

-- -----------------------------------------------------------------------------
-- 5) Prácticas de diagnóstico por imágenes (579)
-- -----------------------------------------------------------------------------
INSERT INTO `codes`
  (`code_text`, `code_text_short`, `code`, `code_type`, `modifier`, `units`, `fee`,
   `superbill`, `related_code`, `taxrates`, `cyp_factor`, `active`, `reportable`,
   `financial_reporting`, `revenue_code`)
SELECT v.`termino`,
       v.`termino`,
       CAST(v.`conceptoId` AS CHAR),
       204,
       '', 0, NULL, '', '', '', 0, 1, 0, 0, ''
  FROM `v_sct_practica_imagen` v
 WHERE NOT EXISTS (
       SELECT 1 FROM `codes` c
        WHERE c.`code_type` = 204
          AND c.`code` = CAST(v.`conceptoId` AS CHAR));

-- -----------------------------------------------------------------------------
-- 6) Odontología: diagnósticos (344) y procedimientos (118)
-- -----------------------------------------------------------------------------
INSERT INTO `codes`
  (`code_text`, `code_text_short`, `code`, `code_type`, `modifier`, `units`, `fee`,
   `superbill`, `related_code`, `taxrates`, `cyp_factor`, `active`, `reportable`,
   `financial_reporting`, `revenue_code`)
SELECT v.`termino`,
       v.`termino`,
       CAST(v.`conceptoId` AS CHAR),
       205,
       '', 0, NULL, '', '', '', 0, 1, 0, 0, ''
  FROM `v_sct_odonto_dx` v
 WHERE NOT EXISTS (
       SELECT 1 FROM `codes` c
        WHERE c.`code_type` = 205
          AND c.`code` = CAST(v.`conceptoId` AS CHAR));

INSERT INTO `codes`
  (`code_text`, `code_text_short`, `code`, `code_type`, `modifier`, `units`, `fee`,
   `superbill`, `related_code`, `taxrates`, `cyp_factor`, `active`, `reportable`,
   `financial_reporting`, `revenue_code`)
SELECT v.`termino`,
       v.`termino`,
       CAST(v.`conceptoId` AS CHAR),
       205,
       '', 0, NULL, '', '', '', 0, 1, 0, 0, ''
  FROM `v_sct_odonto_pr` v
 WHERE NOT EXISTS (
       SELECT 1 FROM `codes` c
        WHERE c.`code_type` = 205
          AND c.`code` = CAST(v.`conceptoId` AS CHAR));

-- -----------------------------------------------------------------------------
-- 7) Prácticas y procedimientos de la Edición Argentina (2.143)
-- -----------------------------------------------------------------------------
INSERT INTO `codes`
  (`code_text`, `code_text_short`, `code`, `code_type`, `modifier`, `units`, `fee`,
   `superbill`, `related_code`, `taxrates`, `cyp_factor`, `active`, `reportable`,
   `financial_reporting`, `revenue_code`)
SELECT v.`termino`,
       v.`termino`,
       CAST(v.`conceptoId` AS CHAR),
       206,
       '', 0, NULL, '', '', '', 0, 1, 0, 0, ''
  FROM `v_sct_prestacion` v
 WHERE NOT EXISTS (
       SELECT 1 FROM `codes` c
        WHERE c.`code_type` = 206
          AND c.`code` = CAST(v.`conceptoId` AS CHAR));

-- -----------------------------------------------------------------------------
-- 8) Comprobación
-- -----------------------------------------------------------------------------
SELECT `ct_id`, `ct_key`, `ct_label`, `ct_diag`, `ct_proc`, `ct_term`, `ct_drug`
  FROM `code_types`
 WHERE `ct_id` BETWEEN 201 AND 206
 ORDER BY `ct_id`;

SELECT `code_type`, COUNT(*) AS `codigos`
  FROM `codes`
 WHERE `code_type` BETWEEN 201 AND 206
 GROUP BY `code_type`
 ORDER BY `code_type`;

SELECT 'Códigos SNOMED CT publicados. Se pueden revisar en Administración -> Codificación.' AS resultado;
