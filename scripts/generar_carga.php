<?php
/**
 * =============================================================================
 *  generar_carga.php  ::  SNOMED CT Edición Argentina -> OpenEMR
 * =============================================================================
 *
 * Genera el archivo sql/02_carga.sql con los LOAD DATA LOCAL INFILE listos para
 * ejecutar en DBeaver-CE. No se conecta a la base: solo escribe el SQL.
 *
 * Uso:
 *   php scripts/generar_carga.php <ruta-zip | ruta-carpeta> [opciones]
 *
 * Ejemplos:
 *   php scripts/generar_carga.php "D:\...\SnomedCT_Argentina-EditionRelease_PRODUCTION_20260820T120000Z.zip"
 *   php scripts/generar_carga.php "D:\snomed\extraido" --sin-ingles
 *   php scripts/generar_carga.php "D:\...\20260820.zip" --todo --salida=sql/02_carga_completa.sql
 *
 * Opciones:
 *   --salida=RUTA     Archivo SQL de salida (por defecto: sql/02_carga.sql)
 *   --destino=RUTA    Carpeta donde extraer el ZIP (por defecto:
 *                     <carpeta del zip>/sct_carga_AAAAMMDD)
 *   --ruta=RUTA       Ruta base que se escribe en los LOAD DATA (por defecto:
 *                     la carpeta donde quedaron los archivos). Sirve para
 *                     generar el SQL con las rutas del servidor o con las de
 *                     la PC, según desde dónde se vaya a ejecutar.
 *   --sin-ingles      Agrega DELETE de descripciones en inglés después de cargar
 *                     OJO: 41.129 conceptos no tienen descripción en español;
 *                     si borra el inglés esos conceptos quedan sin término.
 *   --con-stated      Carga sct2_statedrelationship (1.172.419 filas, todas
 *                     inactivas en esta edición; no se usa en las vistas)
 *   --con-owl         Carga sct2_refset_owl (520.295 expresiones, no se usan)
 *   --con-mp          Carga sct2_refset_medicinalproducts (19.068 filas, todas
 *                     inactivas; no se usa en las vistas)
 *   --con-identifier  Carga sct2_identifier (0 filas en esta edición)
 *   --todo            Equivale a --con-stated --con-owl --con-mp --con-identifier
 *   --sin-track       No agrega el INSERT en standardized_tables_track
 *   --sin-extraer     Falla si hay que extraer el ZIP (solo acepta carpetas)
 *   --stdout          Escribe el SQL por pantalla en vez de en un archivo
 *
 * DÓNDE SE EJECUTA EL SQL
 *   En el servidor (más rápido, los archivos se leen del disco del servidor):
 *     php scripts/generar_carga.php /opt/sct/20260820 --ruta=/opt/sct/20260820
 *     mysql -u USUARIO -p BASE < sql/02_carga.sql
 *   Desde DBeaver-CE en la PC (los archivos viajan por el túnel):
 *     php scripts/generar_carga.php "D:\sct\20260820" --ruta="D:\sct\20260820"
 *     y en DBeaver: abrir sql/02_carga.sql y ejecutarlo.
 * =============================================================================
 */

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    fwrite(STDERR, "Este script se ejecuta por línea de comandos.\n");
    exit(1);
}

// -----------------------------------------------------------------------------
// Definición de archivos -> tabla. El orden importa: las tablas maestras van
// primero. `columnas` es la lista explícita que se pasa a LOAD DATA: no se
// confía en el orden del archivo ni en el orden de la tabla.
// -----------------------------------------------------------------------------
$DEFINICIONES = [
    [
        'tabla'     => 'sct2_concept',
        'prefijo'   => 'sct2_Concept_Snapshot',
        'columnas'  => ['id', 'effectiveTime', 'active', 'moduleId', 'definitionStatusId'],
        'obligatorio' => true,
        'nota'      => '600.374 conceptos',
    ],
    [
        'tabla'     => 'sct2_description',
        'prefijo'   => 'sct2_Description_Snapshot',
        'columnas'  => ['id', 'effectiveTime', 'active', 'moduleId', 'conceptId',
                        'languageCode', 'typeId', 'term', 'caseSignificanceId'],
        'obligatorio' => true,
        'nota'      => '3.337.073 descripciones (1.719.948 en inglés, 1.617.125 en español)',
    ],
    [
        'tabla'     => 'sct2_relationship',
        'prefijo'   => 'sct2_Relationship_Snapshot',
        'columnas'  => ['id', 'effectiveTime', 'active', 'moduleId', 'sourceId',
                        'destinationId', 'relationshipGroup', 'typeId',
                        'characteristicTypeId', 'modifierId'],
        'obligatorio' => true,
        'nota'      => '4.087.686 relaciones (1.751.826 activas)',
    ],
    [
        'tabla'     => 'sct2_statedrelationship',
        'prefijo'   => 'sct2_StatedRelationship_Snapshot',
        'columnas'  => ['id', 'effectiveTime', 'active', 'moduleId', 'sourceId',
                        'destinationId', 'relationshipGroup', 'typeId',
                        'characteristicTypeId', 'modifierId'],
        'obligatorio' => false,
        'opcion'    => 'stated',
        'nota'      => '1.172.419 relaciones declaradas, TODAS inactivas',
    ],
    [
        'tabla'     => 'sct2_identifier',
        'prefijo'   => 'sct2_Identifier_Snapshot',
        'columnas'  => ['alternateIdentifier', 'effectiveTime', 'active', 'moduleId',
                        'identifierSchemeId', 'referencedComponentId'],
        'obligatorio' => false,
        'opcion'    => 'identifier',
        'nota'      => 'archivo vacío en esta edición (solo encabezado)',
    ],
    [
        'tabla'     => 'sct2_textdefinition',
        'prefijo'   => 'sct2_TextDefinition_Snapshot',
        'columnas'  => ['id', 'effectiveTime', 'active', 'moduleId', 'conceptId',
                        'languageCode', 'typeId', 'term', 'caseSignificanceId'],
        'obligatorio' => true,
        'nota'      => '29.051 definiciones de texto',
    ],
    [
        'tabla'     => 'sct2_rel_concrete',
        'prefijo'   => 'sct2_RelationshipConcreteValues_Snapshot',
        'columnas'  => ['id', 'effectiveTime', 'active', 'moduleId', 'sourceId',
                        'value', 'relationshipGroup', 'typeId',
                        'characteristicTypeId', 'modifierId'],
        'obligatorio' => true,
        'nota'      => '152.675 valores concretos (dosis, valores numéricos)',
    ],
    [
        'tabla'     => 'sct2_refset_simple',
        'prefijo'   => 'der2_Refset_SimpleSnapshot',
        'columnas'  => ['id', 'effectiveTime', 'active', 'moduleId', 'refsetId',
                        'referencedComponentId'],
        'obligatorio' => true,
        'nota'      => '120.740 filas (105.912 activas) en 28 conjuntos',
    ],
    [
        'tabla'     => 'sct2_refset_language',
        'prefijo'   => 'der2_cRefset_LanguageSnapshot',
        'columnas'  => ['id', 'effectiveTime', 'active', 'moduleId', 'refsetId',
                        'referencedComponentId', 'acceptabilityId'],
        'obligatorio' => true,
        'nota'      => '6.394.288 filas (es-419, en-US, en-GB)',
    ],
    [
        'tabla'     => 'sct2_refset_attributevalue',
        'prefijo'   => 'der2_cRefset_AttributeValueSnapshot',
        'columnas'  => ['id', 'effectiveTime', 'active', 'moduleId', 'refsetId',
                        'referencedComponentId', 'valueId'],
        'obligatorio' => true,
        'nota'      => '1.045.476 filas',
    ],
    [
        'tabla'     => 'sct2_refset_association',
        'prefijo'   => 'der2_cRefset_AssociationSnapshot',
        'columnas'  => ['id', 'effectiveTime', 'active', 'moduleId', 'refsetId',
                        'referencedComponentId', 'targetComponentId'],
        'obligatorio' => true,
        'nota'      => '227.886 filas (histórico de reemplazos)',
    ],
    [
        'tabla'     => 'sct2_refset_medicinalproducts',
        'prefijo'   => 'der2_ccccccRefset_MedicinalProductsSnapshot',
        'columnas'  => ['id', 'effectiveTime', 'active', 'moduleId', 'refsetId',
                        'referencedComponentId', 'referencedComponentIdRCD',
                        'referencedComponentIdCD_UP', 'referencedComponentIdCD',
                        'referencedComponentIdMPFonlyId', 'referencedComponentIdMPonlyId',
                        'referenceComponentIdMP'],
        'nulos'     => ['referencedComponentIdRCD'        => 'int',
                        'referencedComponentIdCD_UP'      => 'int',
                        'referencedComponentIdCD'         => 'int',
                        'referencedComponentIdMPFonlyId'  => 'int',
                        'referencedComponentIdMPonlyId'   => 'int',
                        'referenceComponentIdMP'          => 'int'],
        'obligatorio' => false,
        'opcion'    => 'mp',
        'nota'      => '19.068 filas, TODAS inactivas (no se usa en las vistas)',
    ],
    [
        'tabla'     => 'sct2_refset_simplemap',
        'prefijo'   => 'der2_sRefset_SimpleMapSnapshot',
        'columnas'  => ['id', 'effectiveTime', 'active', 'moduleId', 'refsetId',
                        'referencedComponentId', 'mapTarget'],
        'obligatorio' => true,
        'nota'      => '562.075 filas (mapa simple, incluye CIE-10)',
    ],
    [
        'tabla'     => 'sct2_refset_extendedmap',
        'prefijo'   => 'der2_iisssccRefset_ExtendedMapSnapshot',
        'columnas'  => ['id', 'effectiveTime', 'active', 'moduleId', 'refsetId',
                        'referencedComponentId', 'mapGroup', 'mapPriority', 'mapRule',
                        'mapAdvice', 'mapTarget', 'correlationId', 'mapCategoryId'],
        'nulos'     => ['mapTarget' => 'str'],
        'obligatorio' => true,
        'nota'      => '217.373 filas: mapa complejo SNOMED CT -> CIE-10',
    ],
    [
        'tabla'     => 'sct2_refset_owl',
        'prefijo'   => 'sct2_sRefset_OWLExpressionSnapshot',
        'columnas'  => ['id', 'effectiveTime', 'active', 'moduleId', 'refsetId',
                        'referencedComponentId', 'owlExpression'],
        'obligatorio' => false,
        'opcion'    => 'owl',
        'nota'      => '520.295 expresiones OWL (no se usan en las vistas)',
    ],
];

// -----------------------------------------------------------------------------
// Argumentos
// -----------------------------------------------------------------------------
$opciones = [
    'sin-ingles'     => false,
    'stated'         => false,
    'owl'            => false,
    'mp'             => false,
    'identifier'     => false,
    'sin-track'      => false,
    'sin-extraer'    => false,
    'stdout'         => false,
    'salida'         => dirname(__DIR__) . '/sql/02_carga.sql',
    'destino'        => null,
    'ruta'           => null,
];
$fuente = null;

foreach (array_slice($argv, 1) as $arg) {
    if (str_starts_with($arg, '--')) {
        $partes = explode('=', substr($arg, 2), 2);
        $clave  = $partes[0];
        $valor  = $partes[1] ?? null;

        if (in_array($clave, ['salida', 'destino', 'ruta'], true)) {
            if ($valor === null || $valor === '') {
                fwrite(STDERR, "Falta el valor de --$clave\n");
                exit(1);
            }
            $opciones[$clave] = $valor;
            continue;
        }
        if ($clave === 'todo') {
            $opciones['stated'] = $opciones['owl'] = $opciones['mp'] = $opciones['identifier'] = true;
            continue;
        }
        if (!array_key_exists($clave, $opciones)) {
            fwrite(STDERR, "Opción desconocida: --$clave\n");
            exit(1);
        }
        $opciones[$clave] = true;
        continue;
    }
    if ($fuente !== null) {
        fwrite(STDERR, "Indicó más de una ruta de origen.\n");
        exit(1);
    }
    $fuente = $arg;
}

if ($fuente === null) {
    fwrite(STDERR, <<<TXT
Uso: php scripts/generar_carga.php <ruta-zip | ruta-carpeta> [opciones]

  --salida=RUTA     archivo SQL de salida (por defecto sql/02_carga.sql)
  --destino=RUTA    carpeta de extracción del ZIP
  --ruta=RUTA       ruta base que se escribe en los LOAD DATA
  --sin-ingles      borrar las descripciones en inglés después de cargar
  --con-stated      cargar relaciones declaradas (todas inactivas)
  --con-owl         cargar expresiones OWL
  --con-mp          cargar refset de productos medicinales (todas inactivas)
  --con-identifier  cargar identificadores alternativos (vacío en esta edición)
  --todo            cargar todo lo anterior
  --sin-track       no insertar en standardized_tables_track
  --sin-extraer     no extraer el ZIP (solo trabajar con carpetas)
  --stdout          mostrar el SQL en pantalla

TXT);
    exit(1);
}

$fuente = rtrim(str_replace(['/', '\\'], DIRECTORY_SEPARATOR, $fuente), DIRECTORY_SEPARATOR);
if (!file_exists($fuente)) {
    fwrite(STDERR, "No existe: $fuente\n");
    exit(1);
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
function aviso(string $texto): void
{
    fwrite(STDOUT, $texto . "\n");
}

function error(string $texto): never
{
    fwrite(STDERR, "ERROR: $texto\n");
    exit(1);
}

/** Escapa una ruta para usarla dentro de una cadena SQL. */
function rutaSql(string $ruta): string
{
    return str_replace("'", "''", str_replace('\\', '/', $ruta));
}

/**
 * Devuelve todos los .txt bajo $base, como rutas relativas con "/".
 * @return string[]
 */
function listarTxt(string $base): array
{
    $salida = [];
    $it = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($base, FilesystemIterator::SKIP_DOTS)
    );
    foreach ($it as $archivo) {
        /** @var SplFileInfo $archivo */
        if (!$archivo->isFile()) {
            continue;
        }
        if (strtolower($archivo->getExtension()) !== 'txt') {
            continue;
        }
        $rel = substr($archivo->getPathname(), strlen($base) + 1);
        $salida[] = str_replace('\\', '/', $rel);
    }
    sort($salida);
    return $salida;
}

/** Elige, para un prefijo, el archivo Snapshot (nunca Full ni Delta). */
function buscarArchivo(array $archivos, string $prefijo): ?string
{
    $candidatos = [];
    foreach ($archivos as $rel) {
        $base = basename($rel);
        if (!str_starts_with($base, $prefijo)) {
            continue;
        }
        if (str_contains($rel, '/Full/') || str_contains($rel, '/Delta/')) {
            continue;
        }
        if (!str_contains($base, 'Snapshot')) {
            continue;
        }
        $candidatos[] = $rel;
    }
    if ($candidatos === []) {
        return null;
    }
    // Si hubiera más de uno, se queda con el de fecha más alta.
    rsort($candidatos);
    return $candidatos[0];
}

// -----------------------------------------------------------------------------
// Resolver el origen: carpeta o ZIP
// -----------------------------------------------------------------------------
$esZip      = is_file($fuente) && preg_match('/\.zip$/i', $fuente) === 1;
$checksum   = '';
$baseArchivos = null;

if (!$esZip) {
    if (!is_dir($fuente)) {
        error("La ruta no es una carpeta ni un ZIP: $fuente");
    }
    $baseArchivos = $fuente;
    aviso("Origen: carpeta $baseArchivos");
} else {
    if (!class_exists('ZipArchive')) {
        error("La extensión zip de PHP no está habilitada (php.ini: extension=zip).\n" .
              '       Alternativas: descomprimir el ZIP y pasar la carpeta, o usar' . "\n" .
              '       scripts/extraer_release.ps1 (PowerShell).');
    }
    $zip = new ZipArchive();
    if ($zip->open($fuente) !== true) {
        error("No se pudo abrir el ZIP: $fuente");
    }

    // Fecha de la release a partir del nombre de un archivo Snapshot.
    $fechaRelease = null;
    $raizZip      = '';
    for ($i = 0; $i < $zip->numFiles; $i++) {
        $nombre = $zip->getNameIndex($i);
        if ($nombre === false) {
            continue;
        }
        if ($raizZip === '' && str_contains($nombre, '/')) {
            $raizZip = substr($nombre, 0, strpos($nombre, '/'));
        }
        if ($fechaRelease === null
            && preg_match('/Snapshot[^\/]*?_(\d{8})\.txt$/i', $nombre, $m) === 1) {
            $fechaRelease = $m[1];
        }
    }
    if ($fechaRelease === null) {
        $fechaRelease = date('Ymd');
    }

    $destino = $opciones['destino']
        ?? dirname($fuente) . DIRECTORY_SEPARATOR . 'sct_carga_' . $fechaRelease;

    if ($opciones['sin-extraer']) {
        if (!is_dir($destino)) {
            $zip->close();
            error("Se pidió --sin-extraer pero la carpeta no existe: $destino");
        }
        $zip->close();
        $baseArchivos = $destino;
        aviso("Origen: carpeta ya extraída $baseArchivos");
    } else {
        aviso("Extrayendo archivos Snapshot a: $destino");
        @mkdir($destino, 0775, true);
        if (!is_dir($destino)) {
            error("No se pudo crear la carpeta de destino: $destino");
        }

        $extraidos = 0;
        $bytes     = 0;
        for ($i = 0; $i < $zip->numFiles; $i++) {
            $nombre = $zip->getNameIndex($i);
            if ($nombre === false || str_ends_with($nombre, '/')) {
                continue;
            }
            if (!preg_match('/\.txt$/i', $nombre)) {
                continue;
            }
            if (!str_contains($nombre, '/Snapshot/')) {
                continue;
            }
            $rel = $raizZip !== '' && str_starts_with($nombre, $raizZip . '/')
                ? substr($nombre, strlen($raizZip) + 1)
                : $nombre;
            $destinoArchivo = $destino . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $rel);
            if (is_file($destinoArchivo) && filesize($destinoArchivo) > 0) {
                continue; // ya extraído
            }
            @mkdir(dirname($destinoArchivo), 0775, true);

            $entrada = $zip->getStream($nombre);
            if ($entrada === false) {
                error("No se pudo leer del ZIP: $nombre");
            }
            $salida = @fopen($destinoArchivo, 'wb');
            if ($salida === false) {
                error("No se pudo escribir: $destinoArchivo\n" .
                      "(si es un problema de rutas largas de Windows, use --destino=C:\\sct_carga)");
            }
            $copiados = stream_copy_to_stream($entrada, $salida);
            fclose($salida);
            fclose($entrada);
            $extraidos++;
            $bytes += (int) $copiados;
            aviso(sprintf('  %-72s %6.1f MB', basename($rel), ((int) $copiados) / 1048576));
        }
        aviso(sprintf('Extraídos %d archivos (%.1f MB).', $extraidos, $bytes / 1048576));
        $baseArchivos = $destino;
    }

    aviso('Calculando MD5 del ZIP para standardized_tables_track...');
    $checksum = (string) md5_file($fuente);
    $zip->close();
}

// -----------------------------------------------------------------------------
// Detectar la release y los archivos
// -----------------------------------------------------------------------------
$archivos = listarTxt($baseArchivos);
if ($archivos === []) {
    error("No se encontraron archivos .txt en $baseArchivos");
}

$fechaRelease = null;
foreach ($archivos as $rel) {
    if (preg_match('/_(\d{8})\.txt$/', $rel, $m) === 1) {
        $fechaRelease = $m[1];
        break;
    }
}
if ($fechaRelease === null) {
    error('No se pudo deducir la fecha de la release desde los nombres de archivo.');
}
$fechaIso    = substr($fechaRelease, 0, 4) . '-' . substr($fechaRelease, 4, 2) . '-' . substr($fechaRelease, 6, 2);
$nombreCarpeta = basename($baseArchivos);

aviso("Release detectada: $fechaIso");

// Resolver cada definición a un archivo real
$plan    = [];
$faltan  = [];
foreach ($DEFINICIONES as $def) {
    $archivo = buscarArchivo($archivos, $def['prefijo']);
    $incluir = $archivo !== null
        && ($def['obligatorio'] || ($opciones[$def['opcion'] ?? ''] ?? false));

    if ($archivo === null) {
        if ($def['obligatorio']) {
            $faltan[] = $def['prefijo'];
        }
        continue;
    }
    if (!$incluir) {
        continue;
    }
    $plan[] = $def + ['archivo' => $archivo];
}
if ($faltan !== []) {
    error("Faltan archivos obligatorios: " . implode(', ', $faltan));
}
if ($plan === []) {
    error('No hay nada para cargar.');
}

// Si se indicó --ruta, avisar si desde ahí no están los archivos.
$rutaCarga = rtrim(str_replace(['/', '\\'], DIRECTORY_SEPARATOR, $opciones['ruta'] ?? $baseArchivos), DIRECTORY_SEPARATOR);
$faltantes = 0;
foreach ($plan as $def) {
    if (!is_file($rutaCarga . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $def['archivo']))) {
        $faltantes++;
    }
}
if ($faltantes > 0) {
    aviso("ATENCIÓN: en $rutaCarga faltan $faltantes de los archivos a cargar.");
    aviso('El SQL se generó igual. Si se ejecuta en otro equipo, la ruta debe');
    aviso('existir ahí; si no, corregí el path con --ruta y volvé a generar.');
}

// -----------------------------------------------------------------------------
// Generar el SQL
// -----------------------------------------------------------------------------
$lineas   = [];
$lineas[] = '-- =============================================================================';
$lineas[] = '-- 02_carga.sql  ::  LOAD DATA de la Edición Argentina de SNOMED CT';
$lineas[] = '-- =============================================================================';
$lineas[] = '-- GENERADO AUTOMÁTICAMENTE por scripts/generar_carga.php. No editar a mano:';
$lineas[] = '-- si cambia la release, vuelva a generarlo.';
$lineas[] = '--';
$lineas[] = '-- Release           : ' . $fechaIso;
$lineas[] = '-- Generado          : ' . date('Y-m-d H:i:s');
$lineas[] = '-- Carpeta de archivos: ' . $baseArchivos;
$lineas[] = '-- Ruta en los LOAD   : ' . ($opciones['ruta'] ?? $baseArchivos);
$lineas[] = '-- Bloques incluidos : ' . count($plan);
$lineas[] = '-- Inglés            : ' . ($opciones['sin-ingles'] ? 'SE BORRA al final' : 'se conserva');
$lineas[] = '--';
$lineas[] = '-- ANTES DE EJECUTAR';
$lineas[] = '--   1) En el servidor MySQL: SET GLOBAL local_infile = 1;';
$lineas[] = '--   2) En la conexión de DBeaver: AllowLoadLocalInfile = true';
$lineas[] = '--      (Propiedades del driver -> allowLoadLocalInfile).';
$lineas[] = '--   3) Las rutas de abajo son del equipo desde donde se EJECUTA el SQL:';
$lineas[] = '--      - con mysql < 02_carga.sql en el servidor, la ruta debe ser del';
$lineas[] = '--        servidor;';
$lineas[] = '--      - ejecutado desde DBeaver-CE, la ruta debe ser de la PC donde está';
$lineas[] = '--        DBeaver (los archivos se leen del cliente y viajan por el túnel).';
$lineas[] = '--   4) Ejecute 01_esquema.sql antes de este archivo.';
$lineas[] = '--';
$lineas[] = '-- Duración estimada: 20-60 minutos según el equipo.';
$lineas[] = '-- =============================================================================';
$lineas[] = '';
$lineas[] = 'SET NAMES utf8mb4;';
$lineas[] = '';

$n = 0;
foreach ($plan as $def) {
    $n++;
    $tabla    = $def['tabla'];
    $columnas = $def['columnas'];
    $nulos    = $def['nulos'] ?? [];

    // Las columnas anulables se leen en variables y se convierten después.
    $listaColumnas = [];
    foreach ($columnas as $col) {
        $listaColumnas[] = isset($nulos[$col]) ? '@' . $col : '`' . $col . '`';
    }
    $asignaciones = [];
    foreach ($nulos as $col => $tipo) {
        $asignaciones[] = $tipo === 'int'
            ? "`$col` = IF(@$col = '', NULL, CAST(@$col AS UNSIGNED))"
            : "`$col` = NULLIF(@$col, '')";
    }

    $lineas[] = '-- -----------------------------------------------------------------------------';
    $lineas[] = "-- [$n/" . count($plan) . "] $tabla";
    $lineas[] = '-- ' . $def['nota'];
    $lineas[] = '-- Archivo: ' . $def['archivo'];
    $lineas[] = '-- -----------------------------------------------------------------------------';
    $lineas[] = "TRUNCATE TABLE `$tabla`;";
    $lineas[] = 'LOAD DATA LOCAL INFILE ' . "'" . rutaSql($rutaCarga . '/' . $def['archivo']) . "'";
    $lineas[] = "  INTO TABLE `$tabla`";
    $lineas[] = '  CHARACTER SET utf8mb4';
    $lineas[] = "  FIELDS TERMINATED BY '\\t' ESCAPED BY ''";
    $lineas[] = "  LINES TERMINATED BY '\\r\\n'";
    $lineas[] = '  IGNORE 1 LINES';
    $lineas[] = '  (' . implode(', ', $listaColumnas) . ')';
    if ($asignaciones !== []) {
        $lineas[] = '  SET ' . implode(",\n      ", $asignaciones);
    }
    $lineas[] = ';';
    $lineas[] = '';

    if ($tabla === 'sct2_description' && $opciones['sin-ingles']) {
        $lineas[] = '-- Descripciones en inglés (opción --sin-ingles).';
        $lineas[] = '-- Recuerde: 41.129 conceptos activos no tienen descripción en español.';
        $lineas[] = "DELETE FROM `sct2_description` WHERE `languageCode` = 'en';";
        $lineas[] = "DELETE FROM `sct2_textdefinition` WHERE `languageCode` = 'en';";
        $lineas[] = '';
    }
}

if (!$opciones['sin-track']) {
    $lineas[] = '-- -----------------------------------------------------------------------------';
    $lineas[] = '-- Registro de la versión importada (lo lee OpenEMR en la pantalla de';
    $lineas[] = '-- Administración -> Codificación -> Tablas estandarizadas).';
    $lineas[] = '-- -----------------------------------------------------------------------------';
    $lineas[] = 'INSERT INTO `standardized_tables_track`';
    $lineas[] = '  (`imported_date`, `name`, `revision_version`, `revision_date`, `file_checksum`)';
    $lineas[] = 'VALUES (NOW(), ' . "'SNOMED', "
        . "'" . rutaSql('Argentina ' . $fechaIso) . "', "
        . "'" . $fechaIso . "', "
        . "'" . $checksum . "');";
    $lineas[] = '';
}

$lineas[] = "SELECT 'Carga terminada. Continúe con 03_postcarga.sql.' AS resultado;";
$lineas[] = '';

$sql = implode("\n", $lineas);

if ($opciones['stdout']) {
    fwrite(STDOUT, $sql);
    exit(0);
}

$salida = $opciones['salida'];
if (!is_dir(dirname($salida))) {
    error("No existe la carpeta de salida: " . dirname($salida));
}
if (file_put_contents($salida, $sql) === false) {
    error("No se pudo escribir: $salida");
}

aviso('');
aviso("SQL generado: $salida");
aviso('Bloques: ' . count($plan) . ' | Release: ' . $fechaIso
    . ' | Inglés: ' . ($opciones['sin-ingles'] ? 'se borra' : 'se conserva'));
aviso('Siguiente paso: ejecutar sql/02_carga.sql en DBeaver y después sql/03_postcarga.sql.');
