-- =============================================================================
-- 20_correcciones.sql  ::  correcciones puntuales a la tabla `odontologico`
-- =============================================================================
-- Ejecutar DESPUÉS de 00_respaldo.sql y 10_estructura.sql.
-- Idempotente: cada UPDATE deja el mismo valor final aunque se repita.
--
-- Por qué hacen falta: la tabla se armó a mano copiando de varios listados, y
-- la numeración y los textos cambian de un listado a otro (por ejemplo el
-- código 08.06 es "ferulización" en el documento de referencia y "placas
-- oclusales" en la tabla). Cada corrección dice en qué se apoya:
--   [PDF]      respaldada por el documento de referencia (docs/fuentes.md)
--   [CRITERIO] criterio clínico o de coherencia, sin documento que lo diga;
--              confirmar con un odontólogo
--
-- ATENCIÓN: este archivo contiene textos de normas copiados de documentos de
-- terceros. Mantener el repositorio PRIVADO (ver README.md).
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- A) Correcciones respaldadas por el documento de referencia
-- -----------------------------------------------------------------------------

-- A.1 [PDF] Normas cruzadas entre 02.03 y 02.04.
--     "Se reconocerá en piezas posteriores y con Rx post-operatoria que se
--     incluye" es la norma de 02.04 (reconstrucción con tornillo en conducto),
--     no de 02.03. En el documento 02.02 es "cavidad compuesta y compleja", así
--     que 02.03 (compleja) toma la norma de 02.02. La toma de 02.02 es una
--     suposición: confirmar con el listado donde 02.02 y 02.03 van separados.
UPDATE `odontologico` a
  JOIN `odontologico` b ON b.`codigo` = '02.02'
   SET a.`norma_particular` = b.`norma_particular`
 WHERE a.`codigo` = '02.03';

UPDATE `odontologico`
   SET `norma_particular` = 'Se reconocerá en piezas posteriores y con Rx post-operatoria que se incluye.'
 WHERE `codigo` = '02.04';

-- A.2 [PDF] Título de 02.06: el documento dice "cavidad compuesta o compleja"
--     (la tabla repetía "Compuesta o Compuesta").
UPDATE `odontologico`
   SET `descripcion` = 'Obturación Estética- Cavidad compuesta o compleja'
 WHERE `codigo` = '02.06';

-- A.3 [PDF] Marcas de radiografía que el documento exige y la tabla no tenía.
--     07.06.04: "Rx pre y post operatoria".  10.02: radiografía preoperatoria.
--     10.15: radiografía pre y post-operatoria.
UPDATE `odontologico` SET `rx_pre` = '1'                       WHERE `codigo` = '07.06.04';
UPDATE `odontologico` SET `rx_pre` = '1'                       WHERE `codigo` = '10.02';
UPDATE `odontologico` SET `rx_pre` = '1', `rx_post` = '1'      WHERE `codigo` = '10.15';

-- A.4 [PDF] Unidad de registro (columnas creadas en 10_estructura.sql).
--     08.03 y 08.04: por sector, 6 sectores.   10.04 y 10.15: por zona, 6 zonas.
--     09.02.06 (sialografía): por glándula y por lado.
UPDATE `odontologico` SET `unidad` = 'sector',   `cantidad_max` = 6 WHERE `codigo` IN ('08.03', '08.04');
UPDATE `odontologico` SET `unidad` = 'zona',     `cantidad_max` = 6 WHERE `codigo` IN ('10.04', '10.15');
UPDATE `odontologico` SET `unidad` = 'glandula'                     WHERE `codigo` = '09.02.06';

-- -----------------------------------------------------------------------------
-- B) Correcciones por criterio (confirmar con un odontólogo)
-- -----------------------------------------------------------------------------

-- B.1 [CRITERIO] 02.10 es una obturación y no tenía pieza ni caras
--     (02.08, la equivalente anterior y posterior, sí las tiene).
UPDATE `odontologico` SET `pieza` = '1', `caras` = '1' WHERE `codigo` = '02.10';

-- B.2 [CRITERIO] Unificar el nombre de los capítulos en `agrupamiento`:
--     "Cápitulo" -> "Capítulo" y el guion largo "–" -> "-". Con las dos
--     variantes, un mismo capítulo aparecía como dos grupos distintos.
UPDATE `odontologico`
   SET `agrupamiento` = REPLACE(REPLACE(`agrupamiento`, 'Cápitulo', 'Capítulo'), '–', '-')
 WHERE `agrupamiento` LIKE '%Cápitulo%' OR `agrupamiento` LIKE '%–%';

-- -----------------------------------------------------------------------------
-- C) DECISIONES PENDIENTES (comentadas: descomentar sólo cuando estén resueltas)
-- -----------------------------------------------------------------------------

-- C.1 08.03 y 08.04: el documento exige radiografía PREoperatoria y no
--     menciona la postoperatoria, pero la tabla tiene rx_post = 1. Si la otra
--     hoja de origen no lo justifica, alinear con el documento:
-- UPDATE `odontologico` SET `rx_post` = NULL WHERE `codigo` IN ('08.03', '08.04');

-- C.2 08.06: en la tabla es "Placas oclusales", pero su norma (autorización
--     previa, factores traumatizantes, cobertura mínima de tres años) es la de
--     "Ferulización dentaria en sector anterior" del documento. El documento no
--     tiene ninguna norma para placas oclusales. En este orden:
--       paso 1 (opcional, sólo si 02.15 F es la misma ferulización del documento):
--              pasarle a 02.15 F la norma que hoy está en 08.06
-- UPDATE `odontologico` a JOIN `odontologico` b ON b.`codigo` = '08.06'
--    SET a.`norma_particular` = b.`norma_particular` WHERE a.`codigo` = '02.15 F';
--       paso 2: quitar la norma de 08.06 (placas oclusales)
-- UPDATE `odontologico` SET `norma_particular` = NULL WHERE `codigo` = '08.06';

-- C.3 Unidades que el documento NO cubre (prótesis y reparaciones). Propuesta:
-- UPDATE `odontologico` SET `unidad` = 'piezas'   WHERE `codigo` IN ('04.02.01','04.02.02','04.02.03','04.02.04');
-- UPDATE `odontologico` SET `unidad` = 'arcada'   WHERE `codigo` IN ('04.03.01','04.03.02','04.03.03');
-- UPDATE `odontologico` SET `unidad` = 'elemento' WHERE `codigo` IN ('04.04.05','04.04.06');
-- UPDATE `odontologico` SET `unidad` = 'protesis' WHERE `codigo` = '04.04.10';
-- UPDATE `odontologico` SET `unidad` = 'estudio'  WHERE `codigo` = '09.02.03';
