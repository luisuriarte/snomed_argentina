-- =============================================================================
-- 35_vistas_snomed.sql  ::  vistas que cruzan el nomenclador con SNOMED CT
-- =============================================================================
-- DEPENDE del repositorio snomed_argentina:
--   * sus tablas sct2_* (cargadas con 02_carga.sql y 03_postcarga.sql)
--   * sql/06_odontologia.sql (vistas v_sct_odonto_dx_cie10 y
--     v_sct_odonto_pr_categoria)
-- Ejecutar DESPUÉS de 10_estructura.sql y 30_vistas.sql, y volver a ejecutarlo
-- cada vez que se cargue una edición nueva de SNOMED (el repositorio de SNOMED
-- recrea sus tablas y las vistas de este archivo quedarían apuntando a tablas
-- que ya no existen).
--
-- Los datos curados a mano (mapeo, estados, ámbitos) NO se tocan acá: viven en
-- tablas propias de este módulo y sobreviven a las recargas de SNOMED.
--
-- Qué crea:
--   1. Carga de las correcciones de ámbito de diagnósticos
--   2. v_odo_diagnosticos              catálogo de diagnósticos para el odontograma
--   3. v_odontologico_sct_control      mapeos que apuntan a conceptos inexistentes
--                                      o dados de baja
--   4. v_odo_practicas_snomed_libres   prácticas SNOMED todavía no usadas en el mapeo
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- 1) Correcciones manuales de ámbito
-- -----------------------------------------------------------------------------
-- El ámbito por defecto sale sólo del código CIE-10 (v_sct_odonto_dx_cie10).
-- Estas tres correcciones son CRITERIO MÍO, NO CLÍNICO: están pendientes de
-- revisión por un odontólogo (docs/pendientes.md). Si la fila ya existe, este
-- INSERT no la modifica: se pueden corregir a mano en la tabla sin que el
-- script las revierta. Para quitar una corrección hay que borrar la fila (y
-- sacarla de este archivo, o volvería a crearse).
INSERT INTO `odo_dx_ambito_manual` (`conceptId`, `ambito`, `nota`) VALUES
  (21763005,  'diente',    'CIE-10 solo S09.9; clínicamente dental. Pendiente de revisión clínica'),
  (109648006, 'diente',    'CIE-10 solo S09.9; clínicamente dental. Pendiente de revisión clínica'),
  (716239006, 'glandulas', 'CIE-10 solo E34.8; compromete glándulas salivales. Pendiente de revisión clínica')
ON DUPLICATE KEY UPDATE `nota` = `nota`;

-- -----------------------------------------------------------------------------
-- 2) Catálogo de diagnósticos para el odontograma
-- -----------------------------------------------------------------------------
-- Toma v_sct_odonto_dx_cie10 (344 diagnósticos en la edición 2026-08-20) y le
-- aplica las correcciones manuales de ámbito.
--   ambito          diente | glandulas | mucosa | otro  (con correcciones)
--   ambito_por_cie10 el que salía sólo del CIE-10, por si hace falta compararlo
--   cie10_codigos   TODOS los códigos separados por coma. El orden NO es clínico:
--                   no tomar el primero como "diagnóstico principal"; que lo
--                   elija el profesional.
--   requiere_contexto  1 si algún código depende de una regla (revisar a mano)
CREATE OR REPLACE VIEW `v_odo_diagnosticos` AS
SELECT v.`conceptoId`,
       v.`termino`,
       v.`cie10_codigos`,
       v.`cantidad_cie10`,
       v.`requiere_contexto`,
       v.`ambito_por_cie10`,
       COALESCE(a.`ambito`, v.`ambito_por_cie10`) AS `ambito`
  FROM `v_sct_odonto_dx_cie10` v
  LEFT JOIN `odo_dx_ambito_manual` a ON a.`conceptId` = v.`conceptoId`;

-- -----------------------------------------------------------------------------
-- 3) Control: mapeos que apuntan a conceptos que no existen o están de baja
-- -----------------------------------------------------------------------------
-- Tiene que devolver CERO filas. Suele pasar por un error de tipeo o porque la
-- edición nueva dio de baja el concepto. En ese caso mirar el refset de
-- asociaciones históricas (REEMPLAZADO POR) del repositorio de SNOMED.
CREATE OR REPLACE VIEW `v_odontologico_sct_control` AS
SELECT s.`codigo`,
       s.`conceptId`,
       s.`relacion`,
       CASE WHEN c.`id` IS NULL THEN 'el concepto no existe'
            ELSE 'el concepto está dado de baja' END AS `problema`
  FROM `odontologico_sct` s
  LEFT JOIN `sct2_concept` c ON c.`id` = s.`conceptId`
 WHERE c.`id` IS NULL OR c.`active` = 0;

-- -----------------------------------------------------------------------------
-- 4) Prácticas SNOMED del refset de odontología que ningún código usa todavía
-- -----------------------------------------------------------------------------
-- Ayuda a mapear: lo que queda acá es lo que falta cubrir (o lo que ningún
-- código del nomenclador representa). La categoría agrupa por tipo de práctica.
CREATE OR REPLACE VIEW `v_odo_practicas_snomed_libres` AS
SELECT p.`conceptoId`,
       p.`termino`,
       p.`categoria`
  FROM `v_sct_odonto_pr_categoria` p
 WHERE NOT EXISTS (SELECT 1 FROM `odontologico_sct` s WHERE s.`conceptId` = p.`conceptoId`);
