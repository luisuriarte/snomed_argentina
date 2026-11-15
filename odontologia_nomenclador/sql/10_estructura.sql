-- =============================================================================
-- 10_estructura.sql  ::  clave, columnas nuevas y tablas auxiliares
-- =============================================================================
-- Idempotente: se puede ejecutar más de una vez. No borra ni reemplaza datos.
-- Requisito: existe la tabla `odontologico` (la tabla del nomenclador).
--
-- Qué hace:
--   1. Controla que `codigo` no tenga vacíos ni repetidos.
--   2. Le pone clave primaria a `odontologico.codigo` (si no la tiene).
--   3. Agrega las columnas `unidad` y `cantidad_max` (si no existen).
--   4. Crea las tablas auxiliares (capítulos, mapeo a SNOMED CT, estados,
--      diagnósticos habituales y ámbito manual).
--   5. Carga la lista de capítulos conocidos, sin pisar lo que ya esté cargado.
--
-- Todas las tablas auxiliares usan utf8mb4_general_ci para que coincida con
-- `odontologico` (con otro collation las claves foráneas fallan con el error 150).
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- 1) Controles previos. Los DOS primeros tienen que devolver cero filas.
--    Si devuelven filas, corregir los datos antes de seguir: el paso 2 fallaría.
-- -----------------------------------------------------------------------------
SELECT `codigo`, COUNT(*) AS `repeticiones`
  FROM `odontologico` GROUP BY `codigo` HAVING COUNT(*) > 1;

SELECT COUNT(*) AS `codigos_vacios`
  FROM `odontologico` WHERE `codigo` IS NULL OR TRIM(`codigo`) = '';

-- -----------------------------------------------------------------------------
-- 2) Clave primaria en odontologico.codigo (sólo si todavía no tiene)
-- -----------------------------------------------------------------------------
SET @tiene_pk := (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
                   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'odontologico'
                     AND CONSTRAINT_TYPE = 'PRIMARY KEY');
SET @q := IF(@tiene_pk = 0,
             'ALTER TABLE `odontologico` MODIFY `codigo` VARCHAR(50) NOT NULL, ADD PRIMARY KEY (`codigo`)',
             'DO 0');
PREPARE st FROM @q; EXECUTE st; DEALLOCATE PREPARE st;

-- -----------------------------------------------------------------------------
-- 3) Columnas nuevas (sólo si todavía no existen)
--    unidad        sobre qué se registra la prestación cuando NO es un diente:
--                  sector, zona, glandula, arcada, piezas, elemento, estudio...
--                  Vacía = no se especificó (la vista deduce 'pieza' si pieza = 1).
--    cantidad_max  cantidad máxima de esa unidad (por ejemplo 6 sectores o 6 zonas).
-- -----------------------------------------------------------------------------
SET @existe := (SELECT COUNT(*) FROM information_schema.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'odontologico'
                   AND COLUMN_NAME = 'unidad');
SET @q := IF(@existe = 0,
             'ALTER TABLE `odontologico` ADD COLUMN `unidad` VARCHAR(20) NULL AFTER `caras`',
             'DO 0');
PREPARE st FROM @q; EXECUTE st; DEALLOCATE PREPARE st;

SET @existe := (SELECT COUNT(*) FROM information_schema.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'odontologico'
                   AND COLUMN_NAME = 'cantidad_max');
SET @q := IF(@existe = 0,
             'ALTER TABLE `odontologico` ADD COLUMN `cantidad_max` SMALLINT NULL AFTER `unidad`',
             'DO 0');
PREPARE st FROM @q; EXECUTE st; DEALLOCATE PREPARE st;

-- -----------------------------------------------------------------------------
-- 4) Tablas auxiliares
-- -----------------------------------------------------------------------------

-- 4.1 Capítulos: nombre, norma general y de qué documento se tomó.
--     `capitulo` es el prefijo del código (los dos primeros caracteres).
--     El capítulo '00' guarda la norma general de todo el nomenclador.
CREATE TABLE IF NOT EXISTS `odontologico_capitulo` (
  `capitulo`      CHAR(2)      NOT NULL,
  `nombre`        VARCHAR(100) NOT NULL,
  `norma_general` TEXT         NULL,
  `fuente`        VARCHAR(255) NULL,
  PRIMARY KEY (`capitulo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 4.2 Mapeo de prestaciones del nomenclador a conceptos SNOMED CT (procedimientos).
--     Un código puede apuntar a varios conceptos y un concepto a varios códigos.
--     NO hay clave foránea hacia las tablas de SNOMED: se recargan en cada release
--     y los conceptId se controlan con v_odontologico_sct_control (35_...).
--       relacion: equivalente | mas_general | mas_especifico | parcial
--         mas_general    el concepto SNOMED es más amplio que el código
--         mas_especifico el concepto SNOMED es más estrecho que el código
--         parcial        se superponen sin que uno contenga al otro
CREATE TABLE IF NOT EXISTS `odontologico_sct` (
  `codigo`    VARCHAR(50) NOT NULL,
  `conceptId` BIGINT      NOT NULL,
  `relacion`  ENUM('equivalente','mas_general','mas_especifico','parcial') NOT NULL DEFAULT 'equivalente',
  `nota`      VARCHAR(255) NULL,
  PRIMARY KEY (`codigo`, `conceptId`),
  KEY `idx_concept` (`conceptId`),
  CONSTRAINT `fk_odo_sct` FOREIGN KEY (`codigo`) REFERENCES `odontologico` (`codigo`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 4.3 Prestaciones que se decidió NO mapear (o dejar para revisar), para que no
--     figuren como pendientes para siempre. Un código con filas en odontologico_sct
--     cuenta como mapeado y no necesita fila acá.
CREATE TABLE IF NOT EXISTS `odontologico_sct_estado` (
  `codigo` VARCHAR(50) NOT NULL,
  `estado` ENUM('sin_equivalente','revisar') NOT NULL,
  `nota`   VARCHAR(255) NULL,
  PRIMARY KEY (`codigo`),
  CONSTRAINT `fk_odo_est` FOREIGN KEY (`codigo`) REFERENCES `odontologico` (`codigo`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 4.4 Diagnósticos habituales para los que se indica una prestación (OPCIONAL).
--     Es una relación de INDICACIÓN, no de equivalencia: el CIE-10 clasifica
--     enfermedades, no procedimientos.
CREATE TABLE IF NOT EXISTS `odontologico_dx` (
  `codigo`    VARCHAR(50) NOT NULL,
  `sistema`   ENUM('CIE10','SNOMED') NOT NULL,
  `codigo_dx` VARCHAR(32) NOT NULL,
  `nota`      VARCHAR(255) NULL,
  PRIMARY KEY (`codigo`, `sistema`, `codigo_dx`),
  KEY `idx_dx` (`sistema`, `codigo_dx`),
  CONSTRAINT `fk_odo_dx` FOREIGN KEY (`codigo`) REFERENCES `odontologico` (`codigo`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 4.5 Correcciones manuales del ámbito de un diagnóstico SNOMED CT.
--     El ámbito por defecto sale del código CIE-10 (v_sct_odonto_dx_cie10, en el
--     repositorio snomed_argentina). Esto es criterio clínico, por eso vive acá y
--     no en la vista: así sobrevive a las recargas de SNOMED.
CREATE TABLE IF NOT EXISTS `odo_dx_ambito_manual` (
  `conceptId` BIGINT NOT NULL,
  `ambito`    ENUM('diente','glandulas','mucosa','otro') NOT NULL,
  `nota`      VARCHAR(255) NULL,
  PRIMARY KEY (`conceptId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- -----------------------------------------------------------------------------
-- 5) Capítulos conocidos. No pisa norma_general ni fuente si ya tienen valor,
--    pero el NOMBRE sí se restablece al de esta lista cada vez que se ejecuta.
--    Los capítulos 04 y 06 NO figuran en el documento de referencia: agregarlos
--    a mano con su fuente (ver docs/pendientes.md). 99_verificaciones.sql avisa
--    de los capítulos que aparezcan en `odontologico` y falten acá.
-- -----------------------------------------------------------------------------
INSERT INTO `odontologico_capitulo` (`capitulo`, `nombre`, `fuente`) VALUES
  ('00', 'Norma general del nomenclador', 'NORMAS-trabajoVIGENTES.pdf (circulo.com.org.ar; subido 2022-09 según la URL)'),
  ('01', 'Consultas',              'NORMAS-trabajoVIGENTES.pdf'),
  ('02', 'Operatoria Dental',      'NORMAS-trabajoVIGENTES.pdf'),
  ('03', 'Endodoncia',             'NORMAS-trabajoVIGENTES.pdf'),
  ('05', 'Odontología Preventiva', 'NORMAS-trabajoVIGENTES.pdf'),
  ('07', 'Odontopediatría',        'NORMAS-trabajoVIGENTES.pdf'),
  ('08', 'Periodoncia',            'NORMAS-trabajoVIGENTES.pdf'),
  ('09', 'Radiología',             'NORMAS-trabajoVIGENTES.pdf'),
  ('10', 'Cirugía',                'NORMAS-trabajoVIGENTES.pdf')
ON DUPLICATE KEY UPDATE
  `nombre` = VALUES(`nombre`),
  `fuente` = COALESCE(`fuente`, VALUES(`fuente`));
