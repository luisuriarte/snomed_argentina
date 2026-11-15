-- =============================================================================
-- 30_vistas.sql  ::  vistas del nomenclador (no dependen de las tablas SNOMED)
-- =============================================================================
-- Ejecutar DESPUÉS de 10_estructura.sql. Idempotente (CREATE OR REPLACE VIEW).
-- El módulo de odontología debe leer estas vistas y no la tabla de origen:
-- así los vacíos y los '1' de texto quedan normalizados en un solo lugar.
--
-- Qué crea:
--   1. v_odontologico_reglas          qué hay que pedir al registrar cada código
--   2. v_odontologico_mapeo           estado del mapeo de cada código a SNOMED CT
--   3. v_odontologico_mapeo_avance    avance del mapeo por capítulo
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- 1) Reglas de carga de cada código
-- -----------------------------------------------------------------------------
-- Las columnas de origen guardan '1' o vacío como texto. Acá pasan a 1 / 0.
--
-- Hay dos grupos de columnas, y la diferencia importa:
--   CONFIRMADAS  requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post
--                Se pueden respaldar con el documento de referencia o por criterio
--                clínico (docs/diccionario_columnas.md).
--   SIN CONFIRMAR  marca_*  Vienen de otra hoja que no se conserva y su
--                significado exacto se desconoce. Se exponen con un nombre
--                neutro ("marca_") para que ninguna pantalla prometa algo que
--                nadie sabe si es cierto. No construir validaciones sobre ellas
--                hasta confirmar qué significan.
--
-- unidad_efectiva  sobre qué se registra: la unidad cargada en `unidad`, o 'pieza'
--                  si no hay unidad y pieza = 1, o NULL si no se registra sobre
--                  nada en particular.
-- capitulo         prefijo del código (los dos primeros caracteres).
CREATE OR REPLACE VIEW `v_odontologico_reglas` AS
SELECT o.`codigo`,
       o.`descripcion`,
       o.`agrupamiento`,
       LEFT(o.`codigo`, 2)                                         AS `capitulo`,
       c.`nombre`                                                  AS `capitulo_nombre`,
       -- confirmadas
       COALESCE(TRIM(o.`pieza`)   = '1', 0)                        AS `requiere_pieza`,
       COALESCE(TRIM(o.`caras`)   = '1', 0)                        AS `requiere_caras`,
       COALESCE(TRIM(o.`rx_pre`)  = '1', 0)                        AS `requiere_rx_pre`,
       COALESCE(TRIM(o.`rx_post`) = '1', 0)                        AS `requiere_rx_post`,
       COALESCE(NULLIF(TRIM(o.`unidad`), ''),
                CASE WHEN TRIM(o.`pieza`) = '1' THEN 'pieza' END)  AS `unidad_efectiva`,
       o.`cantidad_max`,
       -- sin confirmar
       COALESCE(TRIM(o.`factura`)           = '1', 0)              AS `marca_factura`,
       COALESCE(TRIM(o.`ficha_odontolog`)   = '1', 0)              AS `marca_ficha_odontolog`,
       COALESCE(TRIM(o.`ficha_periodontal`) = '1', 0)              AS `marca_ficha_periodontal`,
       COALESCE(TRIM(o.`material`)          = '1', 0)              AS `marca_material`,
       COALESCE(TRIM(o.`maxilar`)           = '1', 0)              AS `marca_maxilar`,
       o.`norma_particular`
  FROM `odontologico` o
  LEFT JOIN `odontologico_capitulo` c
    ON c.`capitulo` = LEFT(o.`codigo`, 2);

-- -----------------------------------------------------------------------------
-- 2) Estado del mapeo de cada código a SNOMED CT
-- -----------------------------------------------------------------------------
-- situacion:
--   mapeado          tiene al menos una fila en odontologico_sct
--   sin_equivalente  se decidió no mapearlo (odontologico_sct_estado)
--   revisar          se marcó para revisar (odontologico_sct_estado)
--   pendiente        todavía no se hizo nada
-- Si un código tiene mapeo y además una fila de estado, manda el mapeo.
CREATE OR REPLACE VIEW `v_odontologico_mapeo` AS
SELECT o.`codigo`,
       o.`descripcion`,
       o.`agrupamiento`,
       (SELECT GROUP_CONCAT(s.`conceptId` ORDER BY s.`conceptId`)
          FROM `odontologico_sct` s
         WHERE s.`codigo` = o.`codigo`)                            AS `snomed`,
       e.`estado`                                                  AS `estado_mapeo`,
       e.`nota`                                                    AS `nota_estado`,
       CASE WHEN EXISTS (SELECT 1 FROM `odontologico_sct` s2 WHERE s2.`codigo` = o.`codigo`)
                 THEN 'mapeado'
            WHEN e.`estado` IS NOT NULL THEN e.`estado`
            ELSE 'pendiente' END                                   AS `situacion`,
       (SELECT GROUP_CONCAT(CONCAT(x.`sistema`, ':', x.`codigo_dx`)
                            ORDER BY x.`sistema`, x.`codigo_dx` SEPARATOR ',')
          FROM `odontologico_dx` x
         WHERE x.`codigo` = o.`codigo`)                            AS `dx_habituales`
  FROM `odontologico` o
  LEFT JOIN `odontologico_sct_estado` e ON e.`codigo` = o.`codigo`;

-- -----------------------------------------------------------------------------
-- 3) Avance del mapeo por capítulo
-- -----------------------------------------------------------------------------
-- Un capítulo con nombre vacío es un prefijo que falta en odontologico_capitulo.
CREATE OR REPLACE VIEW `v_odontologico_mapeo_avance` AS
SELECT t.`capitulo`,
       c.`nombre` AS `capitulo_nombre`,
       t.`prestaciones`,
       t.`mapeadas`,
       t.`sin_equivalente`,
       t.`a_revisar`,
       t.`pendientes`
  FROM (
        SELECT LEFT(m.`codigo`, 2)                         AS `capitulo`,
               COUNT(*)                                    AS `prestaciones`,
               SUM(m.`situacion` = 'mapeado')              AS `mapeadas`,
               SUM(m.`situacion` = 'sin_equivalente')      AS `sin_equivalente`,
               SUM(m.`situacion` = 'revisar')              AS `a_revisar`,
               SUM(m.`situacion` = 'pendiente')            AS `pendientes`
          FROM `v_odontologico_mapeo` m
         GROUP BY LEFT(m.`codigo`, 2)
       ) t
  LEFT JOIN `odontologico_capitulo` c ON c.`capitulo` = t.`capitulo`;
