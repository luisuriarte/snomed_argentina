-- =============================================================================
-- 99_verificaciones.sql  ::  controles de integridad (sólo SELECT)
-- =============================================================================
-- No modifica nada. Ejecutar después de 10, 20 y 30, y cada vez que se edite la
-- tabla a mano. Los controles de la sección 1 tienen que decir OK.
-- (Los controles que usan tablas de SNOMED están al final de 35_vistas_snomed.sql
-- vía v_odontologico_sct_control, que tiene que devolver cero filas.)
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- 1) Integridad. Todo tiene que decir OK.
-- -----------------------------------------------------------------------------
SELECT 'odontologico.codigo es clave primaria' AS `control`,
       (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'odontologico'
           AND CONSTRAINT_TYPE = 'PRIMARY KEY')                                  AS `obtenido`,
       1 AS `esperado`,
       IF((SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'odontologico'
              AND CONSTRAINT_TYPE = 'PRIMARY KEY') = 1, 'OK', 'REVISAR')         AS `estado`
UNION ALL
SELECT 'códigos vacíos', COUNT(*), 0, IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM `odontologico` WHERE TRIM(`codigo`) = ''
UNION ALL
-- Las marcas sólo pueden valer vacío o '1'. Cualquier otra cosa es un error de tipeo
-- o un valor nuevo que las vistas no entienden.
SELECT 'marcas con valores distintos de vacío o 1', COUNT(*), 0, IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM `odontologico`
 WHERE COALESCE(TRIM(`factura`), '')           NOT IN ('', '1')
    OR COALESCE(TRIM(`ficha_odontolog`), '')   NOT IN ('', '1')
    OR COALESCE(TRIM(`ficha_periodontal`), '') NOT IN ('', '1')
    OR COALESCE(TRIM(`pieza`), '')             NOT IN ('', '1')
    OR COALESCE(TRIM(`caras`), '')             NOT IN ('', '1')
    OR COALESCE(TRIM(`rx_pre`), '')            NOT IN ('', '1')
    OR COALESCE(TRIM(`rx_post`), '')           NOT IN ('', '1')
    OR COALESCE(TRIM(`material`), '')          NOT IN ('', '1')
    OR COALESCE(TRIM(`maxilar`), '')           NOT IN ('', '1')
UNION ALL
-- unidad: lista de valores conocidos (ampliar acá cuando se agreguen unidades nuevas)
SELECT 'unidades fuera de la lista conocida', COUNT(*), 0, IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM `odontologico`
 WHERE `unidad` IS NOT NULL
   AND `unidad` NOT IN ('pieza','piezas','arcada','sector','zona','glandula','lado','elemento','protesis','estudio','exposicion')
UNION ALL
-- cantidad_max sin unidad no tiene sentido
SELECT 'cantidad_max sin unidad', COUNT(*), 0, IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM `odontologico` WHERE `cantidad_max` IS NOT NULL AND `unidad` IS NULL
UNION ALL
-- capítulos presentes en la tabla pero ausentes en odontologico_capitulo
SELECT 'capítulos sin cargar en odontologico_capitulo', COUNT(*), 0, IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM (SELECT DISTINCT LEFT(`codigo`, 2) AS `cap` FROM `odontologico`) x
 WHERE x.`cap` NOT IN (SELECT `capitulo` FROM `odontologico_capitulo`)
UNION ALL
-- nombres distintos para un mismo capítulo en `agrupamiento` (errores de tipeo)
SELECT 'capítulos con más de un nombre en agrupamiento', COUNT(*), 0, IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM (SELECT LEFT(`codigo`, 2) AS `cap`
          FROM `odontologico` WHERE `agrupamiento` IS NOT NULL
         GROUP BY LEFT(`codigo`, 2) HAVING COUNT(DISTINCT `agrupamiento`) > 1) y;

-- Detalle de los controles de capítulos, para saber cuáles son:
--   SELECT DISTINCT LEFT(codigo, 2) AS capitulo FROM odontologico
--    WHERE LEFT(codigo, 2) NOT IN (SELECT capitulo FROM odontologico_capitulo);
--   SELECT LEFT(codigo, 2) AS capitulo, agrupamiento, COUNT(*) AS codigos
--     FROM odontologico GROUP BY capitulo, agrupamiento ORDER BY capitulo;

-- -----------------------------------------------------------------------------
-- 2) Marcas de radiografía contra el documento de referencia (informativo)
-- -----------------------------------------------------------------------------
-- Compara lo que exige el documento (docs/fuentes.md) con las marcas de la
-- tabla, y muestra SÓLO las diferencias y los códigos que faltan en la tabla.
-- Con el estado actual del proyecto se espera ver 08.03 y 08.04 hasta que se
-- resuelva la decisión C.1 de 20_correcciones.sql (el documento pide radiografía
-- preoperatoria y la tabla tiene también la postoperatoria).
-- Los códigos 03.03 y 03.04 no están en el documento; se incluyen porque el
-- capítulo de endodoncia entero exige las radiografías pre y post.
SELECT e.`codigo`, o.`descripcion`,
       e.`pre`  AS `rx_pre_documento`,  COALESCE(TRIM(o.`rx_pre`)  = '1', 0) AS `rx_pre_tabla`,
       e.`post` AS `rx_post_documento`, COALESCE(TRIM(o.`rx_post`) = '1', 0) AS `rx_post_tabla`,
       IF(o.`codigo` IS NULL, 'NO ESTÁ EN LA TABLA', '')                      AS `nota`
  FROM (
        SELECT '02.04' AS `codigo`, 0 AS `pre`, 1 AS `post`
        UNION ALL SELECT '03.01', 1, 1 UNION ALL SELECT '03.02', 1, 1 UNION ALL SELECT '03.03', 1, 1
        UNION ALL SELECT '03.04', 1, 1 UNION ALL SELECT '03.05', 1, 1 UNION ALL SELECT '03.06', 1, 1
        UNION ALL SELECT '07.02', 0, 1 UNION ALL SELECT '07.04', 0, 1 UNION ALL SELECT '07.05', 0, 1
        UNION ALL SELECT '07.06.04', 1, 1 UNION ALL SELECT '07.07', 0, 1
        UNION ALL SELECT '08.03', 1, 0 UNION ALL SELECT '08.04', 1, 0
        UNION ALL SELECT '10.02', 1, 0 UNION ALL SELECT '10.05', 0, 1
        UNION ALL SELECT '10.09', 1, 1 UNION ALL SELECT '10.10', 1, 1 UNION ALL SELECT '10.11', 1, 1
        UNION ALL SELECT '10.12', 1, 1 UNION ALL SELECT '10.14', 1, 1 UNION ALL SELECT '10.15', 1, 1
       ) e
  LEFT JOIN `odontologico` o ON o.`codigo` = e.`codigo`
 WHERE o.`codigo` IS NULL
    OR e.`pre`  <> COALESCE(TRIM(o.`rx_pre`)  = '1', 0)
    OR e.`post` <> COALESCE(TRIM(o.`rx_post`) = '1', 0)
 ORDER BY e.`codigo`;
