-- =============================================================================
-- 00_respaldo.sql  ::  respaldo de la tabla del nomenclador
-- =============================================================================
-- Ejecutar ANTES de 10_estructura.sql y de 20_correcciones.sql.
-- Crea una copia de `odontologico` con la fecha y la hora en el nombre
-- (odontologico_bak_AAAAMMDD_HHMMSS). Se puede ejecutar todas las veces que
-- haga falta: cada vez crea una copia nueva.
--
-- Esto respalda SÓLO la tabla de origen. Para respaldar también las tablas de
-- mapeo y de capítulos, usar mysqldump (ver README.md).
-- Las copias son descartables: borrarlas cuando ya no hagan falta.
-- =============================================================================

SET @t := CONCAT('odontologico_bak_', DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s'));
SET @q := CONCAT('CREATE TABLE `', @t, '` AS SELECT * FROM `odontologico`');
PREPARE st FROM @q;
EXECUTE st;
DEALLOCATE PREPARE st;

SELECT @t AS `respaldo_creado`, (SELECT COUNT(*) FROM `odontologico`) AS `filas`;
