-- =============================================================================
-- SNOMED CT Edición Argentina - OpenEMR
-- 05_map_excel.sql  ::  carga de los mapeos NBU y GTIN
-- =============================================================================
--
-- Cuándo se ejecuta: DESPUÉS de 03_postcarga.sql (las tablas deben existir y
-- los CSV deben estar generados con scripts/convertir_excel_maps.py).
-- Es idempotente: hace TRUNCATE + LOAD en cada ejecución.
--
-- Fuentes (carpeta Resources/ dentro del ZIP del release):
--   NBU  → Mapeo_NBU_SCT_Agosto26.xlsx          (425 filas)
--   GTIN → MAP_GTIN_a_RPCD_comercializadas_20260820.xlsx (15.500 filas)
--
-- Pasos previos:
--   1. Ejecutar scripts/convertir_excel_maps.py para generar los CSV.
--   2. Comprobar que MySQL tiene permiso FILE y que secure_file_priv
--      incluye la carpeta de los CSV (o está vacío).
--
-- Verificar permiso:  SHOW VARIABLES LIKE 'secure_file_priv';
-- =============================================================================

SET NAMES utf8mb4;

-- =============================================================================
-- A) Mapeo SNOMED CT → Nomenclador Bioquímico Único (NBU)
-- =============================================================================

TRUNCATE TABLE `sct2_map_nbu`;

LOAD DATA LOCAL INFILE
  'd:/docs/luis/Documentos/sitios/openemr/codigos/SNOMED/sct_carga_20260820/Resources/Mapeo_NBU_SCT_Agosto26.csv'
INTO TABLE `sct2_map_nbu`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY '\t'
         ENCLOSED BY '"'
         ESCAPED BY '\\'
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (@sctid, @codigoNBU, @determinacion)
SET
  `sctid`         = CAST(@sctid AS UNSIGNED),
  `codigoNBU`     = CAST(@codigoNBU AS UNSIGNED),
  `determinacion` = TRIM(@determinacion);

SELECT CONCAT('sct2_map_nbu cargada: ', COUNT(*), ' filas.') AS resultado
  FROM `sct2_map_nbu`;

-- =============================================================================
-- B) Mapeo GTIN → Presentación farmacéutica comercial (RPCD)
-- =============================================================================
--
-- El campo `gtin` se almacena en formato canónico GS1 (GTIN-14, 14 dígitos
-- con ceros a la izquierda). El tipo de código de barras real del envase:
--
--   Ceros inic.  Dígitos sig.  Tipo GS1              Cantidad en este mapeo
--   -----------  ------------  --------------------  -----------------------
--   1            13            EAN-13  ← dominante   15.430  (99,5 %)
--   2            12            UPC-A                     42  ( 0,3 %)
--   0            14            GTIN-14 nativo (ITF-14)   10  (<0,1 %)
--   3            11            Indeterminado             15  (<0,1 %)
--   6             8            EAN-8                      3  (<0,1 %)
--
-- Para buscar desde un lector de código de barras (devuelve EAN-13, 13 dígitos):
--   WHERE gtin = LPAD('7790001234567', 14, '0')
-- =============================================================================

TRUNCATE TABLE `sct2_map_gtin`;

LOAD DATA LOCAL INFILE
  'd:/docs/luis/Documentos/sitios/openemr/codigos/SNOMED/sct_carga_20260820/Resources/MAP_GTIN_a_RPCD_comercializadas_20260820.csv'
INTO TABLE `sct2_map_gtin`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY '\t'
         ENCLOSED BY '"'
         ESCAPED BY '\\'
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`gtin`, `condicion`, `rpcd_id`, `rpcd_fsn`);

SELECT CONCAT('sct2_map_gtin cargada: ', COUNT(*), ' filas.') AS resultado
  FROM `sct2_map_gtin`;

-- =============================================================================
-- C) Índice adicional (si no existe)
-- =============================================================================

-- El IDX en rpcd_id ya se crea en 01_esquema.sql (KEY `idx_gtin_rpcd`).
-- Aquí agregamos uno en codigoNBU para búsquedas por código:
DROP PROCEDURE IF EXISTS `sct_idx_tmp`;
DELIMITER $$
CREATE PROCEDURE `sct_idx_tmp`()
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.statistics
     WHERE table_schema = DATABASE()
       AND table_name   = 'sct2_map_nbu'
       AND index_name   = 'idx_nbu_codigo'
  ) THEN
    ALTER TABLE `sct2_map_nbu` ADD INDEX `idx_nbu_codigo` (`codigoNBU`);
  END IF;
END$$
DELIMITER ;
CALL `sct_idx_tmp`();
DROP PROCEDURE IF EXISTS `sct_idx_tmp`;

ANALYZE TABLE `sct2_map_nbu`, `sct2_map_gtin`;

SELECT '05_map_excel.sql terminado. Verificar con 99_verificacion.sql.' AS resultado;

