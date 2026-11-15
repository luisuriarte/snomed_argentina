-- =============================================================================
-- SNOMED CT Edición Argentina - OpenEMR
-- 06_odontologia.sql  ::  vistas de odontología (diagnósticos, CIE-10, prácticas)
-- =============================================================================
--
-- Cuándo se ejecuta: DESPUÉS de 03_postcarga.sql (necesita sus tablas derivadas
-- y las vistas v_sct_odonto_dx, v_sct_odonto_pr y v_sct_cie10). Es opcional:
-- ningún otro script depende de éste.
--
-- Es idempotente (CREATE OR REPLACE VIEW) y NO modifica ninguna tabla: sólo
-- crea vistas. No contiene datos propios ni correcciones manuales. Todo lo que
-- sale de acá se deriva de la release cargada, así que se regenera solo con
-- cada edición nueva.
--
-- Qué crea:
--   1. v_sct_odonto_dx_cie10_detalle  una fila por diagnóstico y código CIE-10
--   2. v_sct_odonto_dx_cie10          una fila por diagnóstico, con todos sus
--                                     códigos CIE-10 y un ámbito por CIE-10
--   3. v_sct_odonto_dx_busqueda       para el autocompletado de diagnósticos
--   4. v_sct_odonto_pr_categoria      prácticas con su categoría SNOMED CT
--   5. v_sct_odonto_pr_busqueda       para buscar prácticas por sinónimos
--
-- REQUISITOS: MySQL 8.0.14+ o MariaDB 10.4+ (igual que el resto del proyecto).
--
-- IMPORTANTE (cada release): 01_esquema.sql borra las tablas sct2_* pero no
-- conoce estas vistas, que quedarían apuntando a tablas recreadas. Como este
-- script las reemplaza, alcanza con volver a ejecutarlo después de 03. Para que
-- 01 las borre también, agregar al bloque de DROP VIEW de 01_esquema.sql:
--     DROP VIEW IF EXISTS v_sct_odonto_pr_busqueda;
--     DROP VIEW IF EXISTS v_sct_odonto_pr_categoria;
--     DROP VIEW IF EXISTS v_sct_odonto_dx_busqueda;
--     DROP VIEW IF EXISTS v_sct_odonto_dx_cie10;
--     DROP VIEW IF EXISTS v_sct_odonto_dx_cie10_detalle;
--
-- QUÉ NO HACE (a propósito):
--   * No incluye el nomenclador de prestaciones odontológicas ni su mapeo a
--     SNOMED CT: son datos curados a mano, con otro origen y otro ritmo de
--     cambio que la terminología. Viven en el repositorio del módulo de
--     odontología y leen estas vistas.
--   * No corrige a mano ningún ámbito. Ver la advertencia de la sección 2.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- 1) Diagnósticos de odontología: un registro por diagnóstico y código CIE-10
-- -----------------------------------------------------------------------------
-- Fuente: refset 398711000221107 (diagnósticos de odontología de Argentina,
-- 344 conceptos en la edición 2026-08-20) y el mapa extendido de SNOMED CT a
-- CIE-10 (refset 447562003).
--
-- Se usa el mapa extendido directo y no v_sct_cie10 porque esa vista no expone
-- mapAdvice, que trae avisos útiles para el profesional, por ejemplo "posible
-- requisito de un código de causa externa".
--
-- Cómo leer el mapa extendido:
--   * grupo      : cada grupo es un código que se necesita para describir el
--                  concepto. Un diagnóstico con dos grupos se codifica con dos
--                  códigos CIE-10 a la vez.
--   * prioridad  : dentro de un grupo, orden en que se evalúan las reglas; se
--                  toma la primera que se cumple.
--   * regla      : 'TRUE' = el código se aplica siempre. Cualquier otra cosa
--                  (por ejemplo una condición de sexo o edad) significa que el
--                  código depende del contexto del paciente.
--   * consejo    : texto para el profesional (mapAdvice).
--
-- El ORDEN de los grupos NO es un orden clínico. Por ejemplo "gingivitis
-- inducida por placa dental" tiene el grupo 1 = K03.6 (depósitos en los dientes)
-- y el grupo 2 = K05.1 (gingivitis), y "enfermedad gingival causada por el
-- embarazo" tiene el grupo 1 = O26.8 (obstétrico). No usar el grupo 1 como
-- "diagnóstico principal": que el profesional elija cuál es el principal.
--
-- Un concepto sin equivalencia en CIE-10 (mapTarget NULL) no aparece acá.
CREATE OR REPLACE VIEW `v_sct_odonto_dx_cie10_detalle` AS
SELECT d.`conceptoId`,
       d.`termino`,
       em.`mapTarget`     AS `cie10`,
       em.`mapGroup`      AS `grupo`,
       em.`mapPriority`   AS `prioridad`,
       em.`mapRule`       AS `regla`,
       em.`mapAdvice`     AS `consejo`,
       em.`correlationId` AS `correlacion`
  FROM `v_sct_odonto_dx` d
  JOIN `sct2_refset_extendedmap` em
    ON em.`referencedComponentId` = d.`conceptoId`
 WHERE em.`active` = 1
   AND em.`refsetId` = 447562003
   AND em.`mapTarget` IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 2) Diagnósticos de odontología: un registro por diagnóstico
-- -----------------------------------------------------------------------------
-- cie10_codigos   Códigos CIE-10 separados por coma, uno por grupo, en el orden
--                 del mapa (ver la advertencia de la sección 1). Sólo se toma
--                 la prioridad 1 de cada grupo: si todas las reglas son 'TRUE'
--                 (el caso de esta edición) es el código que corresponde.
-- cantidad_cie10  Cuántos códigos trae (cuántos grupos).
-- requiere_contexto
--                 1 si algún registro del mapa tiene una regla distinta de
--                 'TRUE' o una prioridad mayor que 1: en ese caso el código
--                 depende del paciente y hay que revisarlo a mano. En la
--                 edición 2026-08-20 vale 0 para los 344 diagnósticos.
-- ambito_por_cie10
--                 Clasificación gruesa para filtrar el catálogo en pantalla:
--                   diente    algún código K00-K08 (dientes y estructuras de soporte)
--                   glandulas algún código K11 (glándulas salivales)
--                   mucosa    algún código K09, K12, K13 o K14 (quistes, mucosa,
--                             labios, lengua)
--                   otro      el resto
--                 El orden de los WHEN importa: un diagnóstico con K02.9 y K11.9
--                 ("caries por disfunción salival") queda como 'diente'.
--
-- ADVERTENCIA: el ámbito sale SÓLO de los códigos CIE-10, así que es una
-- aproximación. En la edición 2026-08-20 deja en 'otro' cuatro diagnósticos,
-- de los cuales tres son claramente dentales o glandulares por su significado
-- ("lesión dental" y "traumatismo oclusal primario", cuyo único código es
-- S09.9, y el síndrome de hipoacusia e insensibilidad de glándulas salivales a
-- la aldosterona, con E34.8). Esas correcciones son criterio clínico, no
-- terminológico: no se hacen acá sino en el módulo que usa la vista.
-- Los diagnósticos con K10 (enfermedades de los maxilares) no figuran como
-- código principal en este refset; si una edición futura los incorporara,
-- caerían en 'otro'.
--
-- Límite: GROUP_CONCAT corta en group_concat_max_len (1024 por defecto); con a lo
-- sumo unos pocos códigos por diagnóstico no se alcanza.
CREATE OR REPLACE VIEW `v_sct_odonto_dx_cie10` AS
SELECT b.`conceptoId`,
       b.`termino`,
       b.`cie10_codigos`,
       b.`cantidad_cie10`,
       b.`requiere_contexto`,
       CASE WHEN b.`cie10_codigos` REGEXP '(^|,)K0[0-8]'      THEN 'diente'
            WHEN b.`cie10_codigos` REGEXP '(^|,)K11'          THEN 'glandulas'
            WHEN b.`cie10_codigos` REGEXP '(^|,)K(09|1[234])' THEN 'mucosa'
            ELSE 'otro'
       END AS `ambito_por_cie10`
  FROM (
        SELECT d.`conceptoId`,
               d.`termino`,
               GROUP_CONCAT(CASE WHEN em.`mapPriority` = 1 THEN em.`mapTarget` END
                            ORDER BY em.`mapGroup`, em.`mapPriority`
                            SEPARATOR ',')                              AS `cie10_codigos`,
               COUNT(DISTINCT CASE WHEN em.`mapPriority` = 1
                                   THEN em.`mapGroup` END)             AS `cantidad_cie10`,
               CAST(COALESCE(MAX(em.`mapRule` <> 'TRUE' OR em.`mapPriority` > 1), 0)
                    AS UNSIGNED)                                        AS `requiere_contexto`
          FROM `v_sct_odonto_dx` d
          LEFT JOIN `sct2_refset_extendedmap` em
            ON em.`referencedComponentId` = d.`conceptoId`
           AND em.`active` = 1
           AND em.`refsetId` = 447562003
           AND em.`mapTarget` IS NOT NULL
         GROUP BY d.`conceptoId`, d.`termino`
       ) b;

-- -----------------------------------------------------------------------------
-- 3) Búsqueda de diagnósticos (autocompletado)
-- -----------------------------------------------------------------------------
-- Una fila por cada descripción activa de cada diagnóstico (preferida y
-- aceptable), con el término preferido al lado. Permite que el profesional
-- escriba un sinónimo y vea el nombre preferido. Usa sct2_termino_busqueda,
-- que tiene índice FULLTEXT y por concepto (los crea 03_postcarga.sql).
--
-- Ejemplo:
--   SELECT DISTINCT conceptoId, termino, cie10_codigos
--     FROM v_sct_odonto_dx_busqueda
--    WHERE ambito_por_cie10 = 'diente' AND sinonimo LIKE '%gingiv%'
--    ORDER BY termino LIMIT 30;
-- El DISTINCT es necesario: un concepto puede coincidir por más de un sinónimo.
CREATE OR REPLACE VIEW `v_sct_odonto_dx_busqueda` AS
SELECT x.`conceptoId`,
       x.`termino`,
       x.`cie10_codigos`,
       x.`ambito_por_cie10`,
       tb.`term`         AS `sinonimo`,
       tb.`languageCode` AS `idioma`
  FROM `v_sct_odonto_dx_cie10` x
  JOIN `sct2_termino_busqueda` tb
    ON tb.`conceptId` = x.`conceptoId`;

-- -----------------------------------------------------------------------------
-- 4) Prácticas de odontología con su categoría SNOMED CT
-- -----------------------------------------------------------------------------
-- Fuente: refset 399211000221109 (procedimientos de odontología de Argentina,
-- 118 conceptos en la edición 2026-08-20) y la relación inferida "es un"
-- (116680003) hacia sus conceptos padre.
--
-- Sirve para recorrer la lista agrupada por tipo de práctica (por ejemplo, al
-- mapear un nomenclador de prestaciones). Un concepto puede tener más de un
-- padre: se concatenan separados por " | ".
CREATE OR REPLACE VIEW `v_sct_odonto_pr_categoria` AS
SELECT p.`conceptoId`,
       p.`termino`,
       GROUP_CONCAT(DISTINCT tp.`term` ORDER BY tp.`term` SEPARATOR ' | ') AS `categoria`,
       COUNT(DISTINCT rel.`destinationId`)                                 AS `cantidad_padres`
  FROM `v_sct_odonto_pr` p
  LEFT JOIN `sct2_relationship` rel
    ON rel.`sourceId` = p.`conceptoId`
   AND rel.`active` = 1
   AND rel.`typeId` = 116680003
  LEFT JOIN `sct2_termino_preferido` tp
    ON tp.`conceptId` = rel.`destinationId`
 GROUP BY p.`conceptoId`, p.`termino`;

-- -----------------------------------------------------------------------------
-- 5) Búsqueda de prácticas de odontología por sinónimos
-- -----------------------------------------------------------------------------
-- Igual que la sección 3 pero para las prácticas: busca en todas las
-- descripciones y devuelve el término preferido.
--
-- Ejemplo:
--   SELECT DISTINCT conceptoId, termino, categoria
--     FROM v_sct_odonto_pr_busqueda
--    WHERE sinonimo LIKE '%amalgama%'
--    ORDER BY termino;
CREATE OR REPLACE VIEW `v_sct_odonto_pr_busqueda` AS
SELECT c.`conceptoId`,
       c.`termino`,
       c.`categoria`,
       tb.`term`         AS `sinonimo`,
       tb.`languageCode` AS `idioma`
  FROM `v_sct_odonto_pr_categoria` c
  JOIN `sct2_termino_busqueda` tb
    ON tb.`conceptId` = c.`conceptoId`;


-- =============================================================================
-- VERIFICACIÓN (sólo SELECT; se puede copiar a 99_verificacion.sql)
-- =============================================================================
-- Los valores esperados corresponden a la edición Argentina 2026-08-20.
-- Con una edición nueva, actualizarlos (igual que los de 99_verificacion.sql):
-- que cambien no es un error, pero hay que mirar por qué.
-- Todo tiene que decir OK.

SELECT 'v_sct_odonto_dx' AS `control`, 344 AS `esperado`, COUNT(*) AS `obtenido`,
       IF(COUNT(*) = 344, 'OK', 'REVISAR') AS `estado`
  FROM `v_sct_odonto_dx`
UNION ALL
SELECT 'v_sct_odonto_pr', 118, COUNT(*),
       IF(COUNT(*) = 118, 'OK', 'REVISAR')
  FROM `v_sct_odonto_pr`
UNION ALL
SELECT 'v_sct_odonto_dx_cie10 (una fila por diagnóstico)', 344, COUNT(*),
       IF(COUNT(*) = 344, 'OK', 'REVISAR')
  FROM `v_sct_odonto_dx_cie10`
UNION ALL
SELECT 'diagnósticos con al menos un código CIE-10', 344, COUNT(*),
       IF(COUNT(*) = 344, 'OK', 'REVISAR')
  FROM `v_sct_odonto_dx_cie10` WHERE `cie10_codigos` IS NOT NULL
UNION ALL
SELECT 'v_sct_odonto_dx_cie10_detalle (filas)', 383, COUNT(*),
       IF(COUNT(*) = 383, 'OK', 'REVISAR')
  FROM `v_sct_odonto_dx_cie10_detalle`
UNION ALL
SELECT 'diagnósticos con más de un código CIE-10', 37, COUNT(*),
       IF(COUNT(*) = 37, 'OK', 'REVISAR')
  FROM `v_sct_odonto_dx_cie10` WHERE `cantidad_cie10` > 1
UNION ALL
SELECT 'diagnósticos que requieren contexto (regla o prioridad)', 0, COUNT(*),
       IF(COUNT(*) = 0, 'OK', 'REVISAR')
  FROM `v_sct_odonto_dx_cie10` WHERE `requiere_contexto` = 1
UNION ALL
SELECT 'ámbito diente', 190, COUNT(*),
       IF(COUNT(*) = 190, 'OK', 'REVISAR')
  FROM `v_sct_odonto_dx_cie10` WHERE `ambito_por_cie10` = 'diente'
UNION ALL
SELECT 'ámbito glandulas', 81, COUNT(*),
       IF(COUNT(*) = 81, 'OK', 'REVISAR')
  FROM `v_sct_odonto_dx_cie10` WHERE `ambito_por_cie10` = 'glandulas'
UNION ALL
SELECT 'ámbito mucosa', 69, COUNT(*),
       IF(COUNT(*) = 69, 'OK', 'REVISAR')
  FROM `v_sct_odonto_dx_cie10` WHERE `ambito_por_cie10` = 'mucosa'
UNION ALL
SELECT 'ámbito otro', 4, COUNT(*),
       IF(COUNT(*) = 4, 'OK', 'REVISAR')
  FROM `v_sct_odonto_dx_cie10` WHERE `ambito_por_cie10` = 'otro'
UNION ALL
SELECT 'v_sct_odonto_pr_categoria (una fila por práctica)', 118, COUNT(*),
       IF(COUNT(*) = 118, 'OK', 'REVISAR')
  FROM `v_sct_odonto_pr_categoria`;

-- Los dos controles siguientes no tienen valor fijo: si devuelven filas,
-- mirarlas.
--   a) Prácticas sin ningún padre (no deberían existir):
--      SELECT `conceptoId`, `termino` FROM `v_sct_odonto_pr_categoria`
--       WHERE `cantidad_padres` = 0;
--   b) Diagnósticos sin término preferido (termino NULL):
--      SELECT `conceptoId` FROM `v_sct_odonto_dx_cie10` WHERE `termino` IS NULL;