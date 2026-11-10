# SNOMED CT Edición Argentina para OpenEMR

Importación **manual** de la **Edición Argentina de SNOMED CT** (release
trimestral del Centro Nacional de Terminología en Salud / DGTDIS / Ministerio
de Salud de la Nación) en una base **OpenEMR**.

La edición de referencia es la de **agosto de 2026**
(`SnomedCT_Argentina-EditionRelease_PRODUCTION_20260820T120000Z.zip`), que
depende de la edición internacional de **julio de 2026**.

Este proyecto **reemplaza** el procedimiento anterior (parche de
`list_staged.php` + carga manual de archivos `Full`). Ver
[Apéndice D](#apéndice-d-el-parche-anterior-no-usar).

---

## Índice

1. [Qué hace este proyecto](#1-qué-hace-este-proyecto)
2. [Requisitos](#2-requisitos)
3. [Archivos del proyecto](#3-archivos-del-proyecto)
4. [Estructura del ZIP de la release](#4-estructura-del-zip-de-la-release)
5. [Novedades de la edición 2026-08-20](#5-novedades-de-la-edición-2026-08-20)
6. [Decisiones de diseño](#6-decisiones-de-diseño)
7. [Procedimiento de carga](#7-procedimiento-de-carga)
8. [Modelo de datos](#8-modelo-de-datos)
9. [Vistas y consultas de ejemplo](#9-vistas-y-consultas-de-ejemplo)
10. [Publicar la terminología en `codes`](#10-publicar-la-terminología-en-codes)
11. [Actualización trimestral](#11-actualización-trimestral)
12. [Solución de problemas](#12-solución-de-problemas)
13. [Apéndice A: conjuntos de referencia (refsets)](#apéndice-a-conjuntos-de-referencia-refsets)
14. [Apéndice B: atributos y relaciones](#apéndice-b-atributos-y-relaciones)
15. [Apéndice C: conteos de control](#apéndice-c-conteos-de-control)
16. [Apéndice D: el parche anterior (no usar)](#apéndice-d-el-parche-anterior-no-usar)
17. [Licencia y avisos](#17-licencia-y-avisos)

---

## 1. Qué hace este proyecto

Carga el contenido completo de la Edición Argentina de SNOMED CT en tablas
propias (`sct2_*`), construye las tablas derivadas que hacen falta para
consultar la terminología en español y crea un juego de vistas que resumen
los catálogos clínicos argentinos (medicamentos, prácticas, odontología,
vacunas, ENO) y el mapeo a CIE-10.

**No modifica ninguna tabla clínica de OpenEMR.** Las tablas `sct2_*` son un
depósito de terminología; OpenEMR no las lee en tiempo de ejecución (el único
código que las usa es `library/standard_tables_capture.inc.php`, que no hace
falta ejecutar con este procedimiento).

El contenido publicado en la tabla `codes` de OpenEMR es **opcional** y usa
tipos de código propios (201 a 206) para no pisar nada de lo que ya estaba.

---

## 2. Requisitos

| Dónde | Requisito |
|---|---|
| Base de datos | MySQL 8.0.14+ o MariaDB 10.4+ (se usan funciones de ventana `ROW_NUMBER`) |
| Servidor | `local_infile = 1` (para `LOAD DATA LOCAL INFILE`) |
| Cliente | DBeaver-CE (cualquier versión reciente) o el cliente `mysql` |
| PHP (opcional) | PHP 7.4+ con `ext-zip` sólo para generar el script de carga. Si el PHP no tiene `ext-zip`, usar `scripts/extraer_release.ps1` (PowerShell) o descomprimir el ZIP a mano |
| Disco | ~12 GB para la base (la carga completa ocupa unos 6-8 GB) y ~2,2 GB para los archivos extraídos |
| Memoria | 4 GB libres en el servidor durante la carga |

Comprobación rápida de la versión:

```sql
SELECT VERSION();
SELECT @@local_infile, @@sql_mode;
```

> `sql_mode` debe incluir `STRICT_TRANS_TABLES` (o similar). Si el servidor
> está en modo permisivo, la carga también funciona, pero se pierde la
> validación de datos.

---

## 3. Archivos del proyecto

```
snomed_argentina/
├── readme.md                        <- este documento
├── sql/
│   ├── 01_esquema.sql               <- crea las tablas sct2_* (borra las anteriores)
│   ├── 02_carga.sql                 <- GENERADO por el script: los LOAD DATA
│   ├── 03_postcarga.sql             <- índices, tablas derivadas y vistas
│   ├── 04_codigos_opcional.sql      <- publica conceptos en la tabla codes
│   └── 99_verificacion.sql          <- controles de la carga (sólo SELECT)
├── scripts/
│   ├── generar_carga.php            <- genera sql/02_carga.sql a partir del ZIP
│   └── extraer_release.ps1          <- alternativa en PowerShell (sin ext-zip)
├── interface/code_systems/
│   └── list_staged.php              <- parche viejo, NO usar (ver apéndice D)
└── library/
    └── standard_tables_capture.inc.php  <- parche viejo, NO usar (ver apéndice D)
```

Los archivos `.sql` se pueden ejecutar **en el servidor** (con el cliente
`mysql`) o **desde DBeaver-CE** (abriéndolos y presionando *Execute Script*).
Las dos formas funcionan igual salvo por el paso 2 de la carga, que depende de
dónde se lean los archivos (ver [sección 7](#7-procedimiento-de-carga)).

---

## 4. Estructura del ZIP de la release

El ZIP `SnomedCT_Argentina-EditionRelease_PRODUCTION_AAAAMMDDT120000Z.zip` trae
106 entradas. Las que se usan están todas bajo `Snapshot/`:

```
SnomedCT_Argentina-EditionRelease_PRODUCTION_20260820T120000Z/
├── release_package_information.json
└── Snapshot/
    ├── Terminology/
    │   ├── sct2_Concept_Snapshot_ArgentinaEdition_20260820.txt
    │   ├── sct2_Description_Snapshot_ArgentinaEdition_20260820.txt
    │   ├── sct2_Relationship_Snapshot_ArgentinaEdition_20260820.txt
    │   ├── sct2_StatedRelationship_Snapshot_ArgentinaEdition_20260820.txt
    │   ├── sct2_Identifier_Snapshot_ArgentinaEdition_20260820.txt
    │   ├── sct2_TextDefinition_Snapshot_ArgentinaEdition_20260820.txt
    │   ├── sct2_RelationshipConcreteValues_Snapshot_ArgentinaEdition_20260820.txt
    │   └── sct2_sRefset_OWLExpressionSnapshot_ArgentinaEdition_20260820.txt
    ├── Refset/
    │   ├── Content/
    │   │   ├── der2_Refset_SimpleSnapshot_ArgentinaEdition_20260820.txt
    │   │   ├── der2_cRefset_AttributeValueSnapshot_ArgentinaEdition_20260820.txt
    │   │   ├── der2_cRefset_AssociationSnapshot_ArgentinaEdition_20260820.txt
    │   │   └── der2_ccccccRefset_MedicinalProductsSnapshot_ArgentinaEdition_20260820.txt
    │   ├── Language/
    │   │   └── der2_cRefset_LanguageSnapshot_ArgentinaEdition_20260820.txt
    │   ├── Map/
    │   │   ├── der2_sRefset_SimpleMapSnapshot_ArgentinaEdition_20260820.txt
    │   │   └── der2_iisssccRefset_ExtendedMapSnapshot_ArgentinaEdition_20260820.txt
    │   └── Metadata/                   (no se carga: son metadatos de la release)
    ├── Full/                           (NO se usa, ver sección 6.1)
    └── Delta/                          (no se usa)
```

Fuera del ZIP, la release trae además dos planillas Excel: el **mapeo de
GTIN** (presentación comercial ↔ GTIN) y el **mapeo con el NBU**. Los carga
el CNTS fuera del paquete RF2; este proyecto no los procesa.

Todos los archivos `.txt` de esta release están en **UTF-8 sin BOM**, con
final de línea **CRLF**, separados por tabulador, sin tabuladores ni saltos de
línea embebidos y con la cantidad exacta de columnas del encabezado. Por eso
la carga usa `LINES TERMINATED BY '\r\n'` y `FIELDS TERMINATED BY '\t'`.

---

## 5. Novedades de la edición 2026-08-20

Del *Release Note 20260820* (Notas de la Edición Argentina de agosto de 2026):

- **Publicación trimestral**: la edición argentina pasó a publicarse cada
  tres meses, con revisión más frecuente del contenido.
- **Dependencia de la edición internacional de julio de 2026**: los cambios de
  la edición internacional se reincorporan por reconciliación de contenido.
- **Diccionario Nacional de Medicamentos (DNM)**: se actualizan las
  presentaciones del Vademecum Nacional de Medicamentos (VNM) de ANMAT
  reconocidas y en estado de comercialización al **7 de julio de 2026**, y se
  mantienen los **8 refsets** de clases y estado de comercialización.
- **Nuevo: categoría de expendio controlado**. Se incorporan atributos y
  calificadores para representar los listados controlados de estupefacientes y
  psicotrópicos en la Argentina, para medicamentos con condición de expendio
  bajo receta oficial y receta archivada:
  - `579631000221106` | tiene categoría de expendio controlado (atributo) |
  - `579641000221104` | categoría de expendio controlado del DNM (calificador) |
    con las categorías: Estupefaciente lista I / II / III y Psicotrópico
    lista II / III / IV.
- **GTIN**: se actualiza el mapeo entre cada presentación comercializada y sus
  GTIN (se distribuye como Excel adicional dentro del paquete).
- **Mapeo con el NBU**: se publica el archivo de mapeo SNOMED CT ↔ Nomenclador
  Bioquímico Único (NBU 2012 con actualizaciones vigentes a 2026). Es una
  versión preliminar: no incluye determinaciones de enfermedades infecciosas
  ni determinaciones especiales.
- **Refset de prácticas de laboratorio ampliado**: el
  `537301000221103` incorporates todos los conceptos SNOMED CT usados en el
  mapeo a NBU.
- **Refset de prácticas y procedimientos** `577281000221100` actualizado por
  el mismo motivo.

---

## 6. Decisiones de diseño

### 6.1 Sólo archivos `Snapshot`, nunca `Full`

El archivo `Full` contiene **todo el histórico** de la terminología (conceptos,
descripciones y relaciones que ya fueron inactivos). OpenEMR, en cambio, carga
el `Full` esperando el estado actual, con lo que:

- se duplican filas (mismo `id` con distinto `effectiveTime`),
- el resultado es una mezcla de datos vigentes y datos históricos,
- y las tablas quedan ocupadas por filas que nunca van a usarse.

El `Snapshot` es el estado vigente: una fila por `id`. Por eso todo este
proyecto trabaja con `Snapshot`.

### 6.2 Listas explícitas de columnas en cada `LOAD DATA`

La tabla `sct2_relationship` de OpenEMR tiene **9 columnas** y el archivo RF2
tiene **10**: a OpenEMR le falta `relationshipGroup`, de modo que al cargar
sin lista explícita esa columna se corre y `relationshipGroup` terminaba
guardado en `typeId`. Todos los `LOAD DATA` de este proyecto nombran las
columnas una por una.

Lo mismo pasa con `sct2_identifier`: el archivo RF2 trae el encabezado en el
orden `alternateIdentifier, effectiveTime, active, moduleId, identifierSchemeId,
referencedComponentId`, que es distinto al de la tabla de OpenEMR.

### 6.3 `sct2_description.term` es `VARCHAR(1024)`

En esta edición hay **212 descripciones de más de 255 caracteres**; la más
larga mide 482 bytes (una definición de producto con antígenos). Con
`VARCHAR(255)` la carga falla o se truncan los términos. Por eso la columna
es `VARCHAR(1024)`.

`sct2_textdefinition.term` llega a 1.922 bytes: esa columna es `TEXT`.

### 6.4 Los índices se crean después de la carga

`01_esquema.sql` crea las tablas **sólo con la clave primaria**. Cargar 6,4
millones de filas del refset de idioma con todos los índices puestos tarda
varias veces más que cargar en una tabla limpia y construir los índices al
final. `03_postcarga.sql` los agrega (y es idempotente: se puede volver a
ejecutar).

### 6.5 Regla de idioma: prevailece el módulo argentino

En el refset de idioma español `450828004` una misma descripción puede estar
registrada por el módulo internacional de español (`450829007`) y por el módulo
argentino (`11000221109`). Cuando ambas existen, **prevalece la argentina**.

La tabla `sct2_language_efectivo` resuelve esto dejando una sola fila por
descripción, con este orden de prioridad:

1. aceptabilidad `PREFERIDO` (`900000000000548007`) sobre `ACEPTABLE`
   (`900000000000549004`),
2. módulo argentino sobre el internacional,
3. `effectiveTime` más reciente,
4. `id` más alto como desempate.

Como el FSN de un concepto está marcado como *aceptable* y su sinónimo como
*preferido*, el término que queda elegido es el que se usa en la práctica
("clonazepam 500 mcg comprimido oral" y no
"clonazepam 500 mcg comprimido oral (medicamento)").

### 6.6 Marca → genérico por la relación inferida "es un"

El vínculo entre una marca comercial y su genérico se obtiene de la relación
inferida `116680003` | es un |, **no** del refset de productos medicinales.

En esta edición:

- 15.139 marcas en el catálogo `425071000221108` (11.745 en estado
  comercializado, refset `574461000221103`),
- 14.975 tienen **exactamente una** relación "es un" y 164 tienen más de una
  (en cuyo caso el vínculo queda ambiguo y `genericoId` es `NULL`),
- todas tienen laboratorio (`774159003`); 14.638 tienen condición de expendio
  (`574941000221106`) y 151 tienen categoría de expendio controlado.

### 6.7 El refset de productos medicinales no se usa

El refset `552511000221107` (productos medicinales del DNM) tiene 19.068 filas
y **las 19.068 están inactivas** en esta edición. Por eso se carga en su
tabla (si se pide) pero **ninguna vista lo usa**: trabajar con él devolvería
conjuntos vacíos o datos históricos.

### 6.8 El inglés no se borra por defecto

El proyecto anterior terminaba con:

```sql
DELETE FROM sct2_description WHERE languageCode = 'en';
```

Eso deja **41.129 conceptos activos sin término**, porque el 93 % de los
conceptos tiene descripción en español pero el 7 % restante (41.129) sólo
tiene la de inglés.

Por defecto la terminología se conserva completa y las tablas derivadas
priorizan el español:

- `sct2_termino_preferido`: un término por concepto, español primero,
  inglés como respaldo. **Los 600.374 conceptos quedan con término.**
- `sct2_termino_busqueda`: todas las descripciones activas en español y, para
  los conceptos que no tienen ninguna, las descripciones en inglés.

Si igual se quiere borrar el inglés (por ejemplo para que el listado de
OpenEMR no muestre términos en inglés), el generador tiene la opción
`--sin-ingles`. En ese caso la tabla `sct2_description` queda con 1.617.125
filas en vez de 3.337.073 y hay que actualizar los valores esperados de
`99_verificacion.sql`.

### 6.9 `codes`: no se borra nada

El proyecto anterior hacía `DELETE FROM codes WHERE code_type = '109'` y
`DELETE FROM codes WHERE code_type = '100'`, lo que destruía los códigos de
vacunas (CVX) y de medicamentos (RXCUI) que ya estaban cargados.

`04_codigos_opcional.sql` **no borra nada**: crea seis tipos de código
propios (201 a 206) y agrega los conceptos que no existan todavía. El campo
`codes.code` se completa con el **ID de concepto de SNOMED CT**, no con un
`ROW_NUMBER()`, para que el código sea el identificador real y se pueda
cruzar con la terminología.

---

## 7. Procedimiento de carga

### 7.0 Preparación

1. Bajar el ZIP de la release del CNTS.
2. **Respaldar** la base (o al menos las tablas `sct2_*` si ya había una
   carga):

   ```bash
   mysqldump --single-transaction --routines openemr sct2_concept sct2_description \
     sct2_relationship sct2_statedrelationship sct2_textdefinition sct2_identifier \
     sct2_refset_simple sct2_refset_language sct2_refset_attributevalue \
     sct2_refset_association sct2_refset_simplemap sct2_refset_extendedmap \
     sct2_rel_concrete sct2_generico sct2_marca_generico \
     sct2_language_efectivo sct2_termino_preferido sct2_termino_busqueda \
     > respaldo_sct2_$(date +%F).sql
   ```

3. En el servidor, habilitar la carga local:

   ```sql
   SET GLOBAL local_infile = 1;
   SHOW VARIABLES LIKE 'local_infile';
   ```

   (si es una instalación persistente, agregar `local_infile=1` al `my.cnf`).

### 7.1 Opción A: en el servidor (recomendado)

Es la forma más rápida: los archivos se leen del disco del servidor y no
viajan por el túnel.

```bash
# 1. Subir el ZIP al servidor y descomprimirlo
mkdir -p /opt/sct && cd /opt/sct
unzip -q SnomedCT_Argentina-EditionRelease_PRODUCTION_20260820T120000Z.zip
mv SnomedCT_Argentina-EditionRelease_PRODUCTION_20260820T120000Z 20260820

# 2. Generar el script de carga con las rutas del servidor
cd /ruta/del/proyecto/snomed_argentina
php scripts/generar_carga.php /opt/sct/20260820 --ruta=/opt/sct/20260820

# 3. Ejecutar los scripts, en orden
mysql -u USUARIO -p BASE < sql/01_esquema.sql
mysql -u USUARIO -p --local-infile=1 BASE < sql/02_carga.sql
mysql -u USUARIO -p BASE < sql/03_postcarga.sql
mysql -u USUARIO -p BASE < sql/04_codigos_opcional.sql   # opcional
mysql -u USUARIO -p BASE < sql/99_verificacion.sql
```

> `unzip` descomprime todo el ZIP (incluidas las carpetas `Full/` y `Delta/`,
> que no se usan y ocupan bastante). Para quedarse sólo con lo necesario:
>
> ```bash
> unzip -q -j ZIP '*/Snapshot/Terminology/*' -d /opt/sct/20260820/Terminology
> unzip -q -j ZIP '*/Snapshot/Refset/*'      -d /opt/sct/20260820/Refset
> ```
>
> o usar el generador, que ya extrae sólo lo necesario
> (`php scripts/generar_carga.php ZIP`).

Si el servidor no tiene PHP, el generador se puede correr en la PC contra la
carpeta descomprimida y después corregir las rutas del archivo generado con un
cambio de texto (`/ruta/de/la/pc/` → `/opt/sct/20260820/`) o regenerarlo con
`--ruta`.

### 7.2 Opción B: desde DBeaver-CE (PC con túnel SSH)

```bash
# En la PC: descomprimir el ZIP (Windows Explorer o 7-Zip) en, por ejemplo,
#            D:\sct\20260820
# Generar el script de carga con las rutas de la PC
php scripts/generar_carga.php "D:\sct\20260820" --ruta="D:\sct\20260820"
```

Si el PHP de la PC no tiene `ext-zip`, la extracción se puede hacer con el
script de PowerShell que viene incluido (extrae sólo `Snapshot/`, sin las
carpetas `Full/` ni `Delta/`):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\extraer_release.ps1 `
  -Zip "D:\...\SnomedCT_Argentina-EditionRelease_PRODUCTION_20260820T120000Z.zip"
```

Después, en DBeaver-CE:

1. **Conexión → Editar conexión → Propiedades del driver → Agregar propiedad**:
   - Nombre: `allowLoadLocalInfile`
   - Valor: `true`
   - (algunas versiones de DBeaver lo escriben en minúsculas:
     `allowloadlocalinfile`; el driver lo normaliza).
2. Volver a conectar (la propiedad se aplica en la apertura de la conexión).
3. Abrir `sql/01_esquema.sql` → *Execute Script* (Ctrl+Shift+Enter).
4. Abrir `sql/02_carga.sql` → *Execute Script*. **Acá tarda más**: DBeaver
   lee los archivos desde la PC y los manda por el túnel. Si el túnel es
   lento, conviene subir los archivos al servidor y usar la opción A.
5. `sql/03_postcarga.sql` → *Execute Script*.
6. `sql/04_codigos_opcional.sql` → *Execute Script* (opcional).
7. `sql/99_verificacion.sql` → *Execute Script* y revisar que todo diga `OK`.

> En DBeaver hay que ejecutar los scripts **completo** (no sentencia por
> sentencia) porque `03_postcarga.sql` usa `DELIMITER $$` para crear un
> procedimiento auxiliar.

### 7.3 Qué se ve al terminar

| Script | Qué hace | Tiempo estimado |
|---|---|---|
| `01_esquema.sql` | Crea las tablas `sct2_*` y borra las vistas anteriores | segundos |
| `02_carga.sql` | 11-15 bloques `LOAD DATA` (12-15 millones de filas) | 20-60 min (servidor) / 1-3 h (túnel) |
| `03_postcarga.sql` | Índices + 5 tablas derivadas + 16 vistas | 10-25 min |
| `04_codigos_opcional.sql` | ~9.600 filas en `codes` | segundos |
| `99_verificacion.sql` | Controles | segundos |

---

## 8. Modelo de datos

Cada tabla y cada columna de `01_esquema.sql` tiene su `COMMENT` con la
definición oficial del campo. La fuente es la especificación de SNOMED
International en **Release Format 2 (RF2)**:

- <https://docs.snomed.org/snomed-ct-specifications/snomed-ct-release-file-specification>
  - Apéndice B *Specification Reference Information*: definición de cada campo
    (`id`, `effectiveTime`, `active`, `moduleId`, `typeId`, `term`,
    `relationshipGroup`, `acceptabilityId`, `mapTarget`, `mapRule`, ...).
  - Capítulo 4 *File Format Specifications*: estructura de los archivos de
    concepto, descripción, relación, relación declarada, identificador y
    valor concreto.
  - Capítulo 5 *Reference Set Release File Specification*: estructura de los
    refsets (simple, de idioma, de valor de atributo, de asociación, de mapa
    simple, de mapa extendido, de expresión OWL).
  - Apéndice E: enumeraciones de conceptos para `moduleId`,
    `definitionStatusId`, `typeId`, `caseSignificanceId`,
    `characteristicTypeId` y `modifierId`.

Los valores concretos que aparecen en los comentarios (por ejemplo
`900000000000073002` = definido por condiciones necesarias suficientes) se
verificaron además contra los datos de la release 2026-08-20.

Las columnas del refset de productos medicinales del DNM
(`referencedComponentIdRCD`, `referencedComponentIdCD_UP`,
`referencedComponentIdCD`, `referencedComponentIdMPFonlyId`,
`referencedComponentIdMPonlyId`, `referenceComponentIdMP`) **no están en la
especificación RF2 internacional**: son del modelo de datos del Diccionario
Nacional de Medicamentos del CNTS (MP = producto medicinal, MPF = forma de
presentación, CD = medicamento genérico, CD_UP = genérico con unidad de
presentación definida, RCD = genérico de referencia), y así están aclarados en
el comentario de la tabla.

### 8.1 Tablas de terminología (RF2)

| Tabla | Origen | Filas (2026-08-20) |
|---|---|---|
| `sct2_concept` | `sct2_Concept_Snapshot` | 600.374 |
| `sct2_description` | `sct2_Description_Snapshot` | 3.337.073 |
| `sct2_relationship` | `sct2_Relationship_Snapshot` | 4.087.686 |
| `sct2_statedrelationship` | `sct2_StatedRelationship_Snapshot` | 1.172.419 (todas inactivas) |
| `sct2_identifier` | `sct2_Identifier_Snapshot` | 0 |
| `sct2_textdefinition` | `sct2_TextDefinition_Snapshot` | 29.051 |
| `sct2_rel_concrete` | `sct2_RelationshipConcreteValues_Snapshot` | 152.675 |
| `sct2_refset_simple` | `der2_Refset_SimpleSnapshot` | 120.740 |
| `sct2_refset_language` | `der2_cRefset_LanguageSnapshot` | 6.394.288 |
| `sct2_refset_attributevalue` | `der2_cRefset_AttributeValueSnapshot` | 1.045.476 |
| `sct2_refset_association` | `der2_cRefset_AssociationSnapshot` | 227.886 |
| `sct2_refset_simplemap` | `der2_sRefset_SimpleMapSnapshot` | 562.075 |
| `sct2_refset_extendedmap` | `der2_iisssccRefset_ExtendedMapSnapshot` | 217.373 |
| `sct2_refset_medicinalproducts` | `der2_ccccccRefset_MedicinalProductsSnapshot` | 19.068 (todas inactivas) |
| `sct2_refset_owl` | `sct2_sRefset_OWLExpressionSnapshot` | 520.295 |

Los nombres de tabla son los que usa OpenEMR para que el importador nativo
(no usado acá) y los scripts anteriores sigan funcionando.

### 8.2 Tablas derivadas (se reconstruyen en `03_postcarga.sql`)

| Tabla | Contenido | Filas (2026-08-20) |
|---|---|---|
| `sct2_language_efectivo` | Idioma y aceptabilidad efectiva de cada descripción | 2.755.885 |
| `sct2_termino_preferido` | Un término por concepto (español primero) | 600.374 |
| `sct2_termino_busqueda` | Índice de búsqueda con sinónimos | 1.433.264 |
| `sct2_generico` | Catálogo de genéricos prescribibles | 5.607 |
| `sct2_marca_generico` | Vínculo marca → genérico / laboratorio | 15.139 |

---

## 9. Vistas y consultas de ejemplo

### 9.1 Vistas disponibles

| Vista | Contenido |
|---|---|
| `v_sct_termino` | Término preferido de cada concepto |
| `v_sct_refset_resumen` | Todos los refsets con su nombre y cantidad de miembros |
| `v_sct_refset_miembro` | Miembros de un refset con su término |
| `v_sct_generico` | Genéricos prescribibles (5.607) |
| `v_sct_marca` | Marcas con genérico, laboratorio y condición de expendio |
| `v_sct_generico_marca` | Genéricos con la cantidad de marcas que tienen |
| `v_sct_presentacion` | Presentaciones comercializadas |
| `v_sct_practica_lab` | Prácticas de laboratorio de Argentina |
| `v_sct_practica_imagen` | Prácticas de diagnóstico por imágenes |
| `v_sct_prestacion` | Prácticas y procedimientos de la Edición Argentina |
| `v_sct_odonto_dx` / `v_sct_odonto_pr` | Odontología: diagnósticos y procedimientos |
| `v_sct_vacuna` | Inmunizaciones de Argentina |
| `v_sct_eno` | Enfermedades de notificación obligatoria |
| `v_sct_dispositivo` | Productos sanitarios y dispositivos médicos |
| `v_sct_cie10` | Mapeo SNOMED CT → CIE-10 |

### 9.2 Consultas

**Buscar un medicamento por nombre (autocompletado):**

```sql
SELECT `conceptoId`, `terminoPreferido`
  FROM `sct2_termino_busqueda`
 WHERE `term` LIKE '%clonazepam%'
 LIMIT 20;
```

La collation `utf8mb4_general_ci` no distingue mayúsculas, minúsculas ni
acentos: `%clonazepam%` también encuentra "clonazepám".

**Ver un genérico con sus marcas:**

```sql
SELECT g.`termino`        AS `generico`,
       g.`conUnidad`      AS `conUnidad`,
       m.`marca`          AS `marca`,
       m.`laboratorio`    AS `laboratorio`,
       m.`condicionExpendio`
  FROM `v_sct_generico` g
  JOIN `v_sct_marca` m ON m.`genericoId` = g.`conceptoId`
 WHERE g.`termino` LIKE 'clonazepam%';
```

**Genéricos con la cantidad de marcas:**

```sql
SELECT `generico`, `marcas`, `marcasComercializadas`
  FROM `v_sct_generico_marca`
 ORDER BY `marcasComercializadas` DESC
 LIMIT 30;
```

**Prácticas de laboratorio de Argentina:**

```sql
SELECT `conceptoId`, `termino` FROM `v_sct_practica_lab` ORDER BY `termino`;
```

**Equivalencias con CIE-10:**

```sql
SELECT `conceptoId`, `termino`, `cie10`
  FROM `v_sct_cie10`
 WHERE `cie10` LIKE 'E11%';
```

**Productos con expendio controlado (nuevo 2026-08):**

```sql
SELECT `marca`, `generico`, `categoriaControl`
  FROM `v_sct_marca`
 WHERE `categoriaControlId` IS NOT NULL
 ORDER BY `categoriaControl`, `marca`;
```

**Qué refsets hay y cuántos miembros tienen:**

```sql
SELECT * FROM `v_sct_refset_resumen` ORDER BY `activos` DESC;
```

---

## 10. Publicar la terminología en `codes`

`04_codigos_opcional.sql` agrega conceptos a la tabla `codes` con seis tipos
de código propios:

| `ct_id` | `ct_key` | Contenido | Filas (2026-08-20) |
|---|---|---|---|
| 201 | `SNOMEDAR` | Genéricos prescribibles | 5.607 |
| 202 | `SNOMEDARVAC` | Inmunizaciones | 407 |
| 203 | `SNOMEDARLAB` | Prácticas de laboratorio | 1.007 |
| 204 | `SNOMEDARIMG` | Prácticas de imágenes | 579 |
| 205 | `SNOMEDARODO` | Odontología (dx + pr) | 462 |
| 206 | `SNOMEDARPR` | Prácticas y procedimientos | 2.143 |

Antes de ejecutarlo, el script muestra los tipos de código que ya existen
entre 200 y 210: si alguno está ocupado por otro nombre, el `INSERT IGNORE`
lo saltea y los códigos quedan colgados de un tipo ajeno. En ese caso,
elegir otros `ct_id` libres y ajustarlos en el script.

Después se los ve en OpenEMR en *Administración → Codificación → Tipos de
código* y en los listados de diagnóstico/procedimiento.

---

## 11. Actualización trimestral

La edición argentina se publica cada tres meses. Para actualizar:

```bash
# 1. Descargar el ZIP nuevo y descomprimirlo
# 2. Volver a generar el script de carga
php scripts/generar_carga.php /opt/sct/20261120 --ruta=/opt/sct/20261120

# 3. Ejecutar los scripts en orden
mysql -u USUARIO -p BASE < sql/01_esquema.sql
mysql -u USUARIO -p --local-infile=1 BASE < sql/02_carga.sql
mysql -u USUARIO -p BASE < sql/03_postcarga.sql
mysql -u USUARIO -p BASE < sql/99_verificacion.sql
```

`01_esquema.sql` borra y recrea las tablas `sct2_*`, así que **no hay que
borrar nada a mano**. `04_codigos_opcional.sql` se puede volver a ejecutar:
es idempotente y sólo agrega lo que falta.

**Antes de dar por buena una edición nueva**, hay que actualizar los valores
esperados de `99_verificacion.sql` (ver [Apéndice C](#apéndice-c-conteos-de-control)),
que están calculados para la edición 2026-08-20. Los conteos que se mantienen
entre ediciones son los de `sct2_concept`; los demás cambian.

También conviene revisar:

- si el NRC agregó **refsets nuevos** (aparecerán en `v_sct_refset_resumen`
  con el rótulo genérico "Refset &lt;id&gt;"): hay que agregarles el nombre en
  el `INSERT` de `sct2_refset_catalogo` dentro de `03_postcarga.sql`;
- si cambió la lista de atributos del DNM (por ejemplo, el nuevo
  `579631000221106`).

---

## 12. Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `The used command is not allowed with this MySQL version` (error 1148) | `local_infile` desactivado | `SET GLOBAL local_infile = 1;` y reiniciar la conexión |
| `Error reading file` / `Can't find file` | La ruta del `LOAD DATA` no existe en el equipo desde donde se ejecuta | Regenerar con `--ruta` apuntando a la ruta correcta |
| `Data too long for column 'term'` | Se está usando el esquema viejo (`VARCHAR(255)`) | Ejecutar `01_esquema.sql` de este proyecto |
| `Column count doesn't match value count` | Se editó a mano el `LOAD DATA` y se sacaron las columnas | Regenerar con el script |
| `Table 'sct2_description' doesn't exist` | Se saltó `01_esquema.sql` | Ejecutarlo primero |
| `Unknown column 'relationshipGroup'` | Quedó el esquema viejo de OpenEMR (9 columnas) | Ejecutar `01_esquema.sql` (borra y recrea las tablas) |
| `Access denied` en `SET GLOBAL` | Falta privilegio `SUPER` | Ejecutarlo con un usuario con privilegio, o usar `local_infile=1` en el `my.cnf` |
| Carga muy lenta desde DBeaver | Los archivos viajan por el túnel SSH | Copiar los archivos al servidor y usar la opción A |
| `Row size too large` | Motor con formato de fila antiguo | `SET ROW_FORMAT=DYNAMIC` (MySQL 5.7) — con InnoDB de MySQL 8 no hace falta |
| Faltan filas en `v_sct_generico` | Se ejecutó `03_postcarga.sql` antes de `02_carga.sql` | Ejecutar `03_postcarga.sql` de nuevo (reconstruye las derivadas) |
| `v_sct_marca` sin genéricos | La relación "es un" tiene más de un destino | Es lo esperable para 164 marcas ambiguas: ver `sct2_marca_generico.relaciones` |
| Los acentos se ven mal (DBeaver) | DBeaver leyó el archivo con otra codificación | Los `.sql` están en UTF-8 sin BOM: en el editor de DBeaver, cambiar la codificación a UTF-8 (icono de codificación en la barra lateral derecha), recargar el archivo y ejecutarlo de nuevo |

### Copia de seguridad antes de tocar nada

```bash
mysqldump --single-transaction openemr > openemr_completo_$(date +%F).sql
```

---

## Apéndice A: conjuntos de referencia (refsets)

### A.1 Los 8 refsets del DNM

| Refset | Nombre en las Notas de la Edición | Activos |
|---|---|---|
| `574451000221100` | Presentaciones farmacéuticas comerciales | 21.925 |
| `425071000221108` | Fármacos de uso clínico comerciales | 15.139 |
| `425081000221106` | Fármacos de uso clínico con unidad de presentación definida | 5.244 |
| `425091000221109` | Fármacos de uso clínico sin unidad de presentación definida | 1.375 |
| `331101000221109` | Presentaciones farmacéuticas comerciales en estado comercializado | 15.941 |
| `574461000221103` | Fármacos de uso clínico comerciales en estado comercializado | 11.745 |
| `574471000221107` | Fármacos de uso clínico con unidad de presentación definidos y comercializados | 4.401 |
| `574481000221105` | Fármacos de uso clínico sin unidad de presentación definidos y comercializados | 1.206 |

> Los dos refsets de genéricos comercializados (`574471000221107` +
> `574481000221105`) suman **5.607** conceptos: ese es el catálogo de
> genéricos prescribibles que usa `v_sct_generico`.

### A.2 Conjuntos clínicos

| Refset | Descripción | Activos |
|---|---|---|
| `577281000221100` | Prácticas y procedimientos de la Edición Argentina | 2.143 |
| `537301000221103` | Prácticas de laboratorio de Argentina | 1.007 |
| `536561000221108` | Prácticas prescribibles de diagnóstico por imágenes | 579 |
| `371201000221100` | Prácticas y procedimientos SUMAR | 436 |
| `2281000221106` | Inmunizaciones de Argentina | 407 |
| `398711000221107` | Diagnósticos de odontología de Argentina | 344 |
| `399211000221109` | Procedimientos de odontología de Argentina | 118 |
| `651000221107` | Enfermedades de notificación obligatoria | 195 |
| `869651000221108` | Productos sanitarios y dispositivos médicos | 1.088 |
| `93491000221103` | Pueblos originarios | 59 |

### A.3 Refsets de la edición internacional

| Refset | Descripción | Filas |
|---|---|---|
| `450828004` | Español de América Latina (preferido / aceptable) | 3.033.105 |
| `900000000000509007` | Inglés (US) | 1.682.158 |
| `900000000000508004` | Inglés (GB) | 1.679.025 |
| `447562003` | Mapa complejo SNOMED CT → CIE-10 | 217.373 |
| `900000000000497000` | Mapa simple → CIE-10 | 534.401 |
| `552511000221107` | Productos medicinales del DNM (inactivo) | 19.068 |

---

## Apéndice B: atributos y relaciones

### B.1 Relaciones usadas

| ID | Significado | Uso |
|---|---|---|
| `116680003` | es un | Marca → genérico |
| `411116001` | forma farmacéutica | `v_sct_generico.formaFarmaceutica` |
| `763032000` | unidad de presentación | Atributo de los genéricos con unidad |
| `774158006` | nombre de producto | Atributo |
| `774159003` | proveedor / laboratorio | `v_sct_marca.laboratorio` |
| `574941000221106` | condición de expendio | `v_sct_marca.condicionExpendio` |
| `579631000221106` | tiene categoría de expendio controlado | Nuevo en 2026-08 |
| `900000000000548007` | aceptabilidad: preferido | `sct2_language_efectivo` |
| `900000000000549004` | aceptabilidad: aceptable | `sct2_language_efectivo` |
| `900000000000003001` | tipo de descripción: FSN | — |
| `900000000000013009` | tipo de descripción: sinónimo | — |

### B.2 Módulos

| ID | Módulo |
|---|---|
| `11000221109` | Extensión Argentina (prevalece) |
| `450829007` | Español internacional (se cede ante el argentino) |
| `900000000000207008` | Módulo central de la edición internacional |

### B.3 Categorías de expendio controlado (nuevo 2026-08)

`579641000221104` | categoría de expendio controlado del DNM |, con las
categorías:

- Estupefaciente lista I
- Estupefaciente lista II
- Estupefaciente lista III
- Psicotrópico lista II
- Psicotrópico lista III
- Psicotrópico lista IV

---

## Apéndice C: conteos de control

Valores esperados para la edición **Argentina 2026-08-20**. `99_verificacion.sql`
los comprueba todos y devuelve `OK` o `REVISAR`.

| Tabla | Esperado |
|---|---|
| `sct2_concept` | 600.374 |
| `sct2_description` | 3.337.073 (es 1.617.125 / en 1.719.948) |
| `sct2_description` activas | 2.733.899 |
| `sct2_relationship` | 4.087.686 (activas 1.751.826) |
| `sct2_textdefinition` | 29.051 |
| `sct2_rel_concrete` | 152.675 |
| `sct2_refset_simple` | 120.740 (activas 105.912) |
| `sct2_refset_language` | 6.394.288 |
| `sct2_refset_attributevalue` | 1.045.476 |
| `sct2_refset_association` | 227.886 |
| `sct2_refset_simplemap` | 562.075 |
| `sct2_refset_extendedmap` | 217.373 |
| `sct2_identifier` | 0 |
| `sct2_language_efectivo` | 2.755.885 |
| `sct2_termino_preferido` | 600.374 |
| `sct2_termino_busqueda` | 1.433.264 |
| `sct2_generico` | 5.607 |
| `sct2_marca_generico` | 15.139 (14.975 con un único genérico) |
| `v_sct_vacuna` | 407 |
| `v_sct_practica_lab` | 1.007 |
| `v_sct_practica_imagen` | 579 |
| `v_sct_prestacion` | 2.143 |
| `v_sct_odonto_dx` | 344 |
| `v_sct_odonto_pr` | 118 |
| `v_sct_eno` | 195 |
| `v_sct_presentacion` | 15.941 |
| `v_sct_dispositivo` | 1.088 |

Si se cargó con `--sin-ingles`, `sct2_description` queda en 1.617.125 y
`sct2_termino_busqueda` en 1.321.856 + 111.408 (conceptos sin español).

---

## Apéndice D: el parche anterior (no usar)

Este repositorio conserva, por historial, dos archivos del procedimiento
anterior:

- `interface/code_systems/list_staged.php`: hacking de la pantalla de
  "tablas estandarizadas" para que reconozca el ZIP de la edición argentina.
- `library/standard_tables_capture.inc.php`: importador parcheado que carga
  `Full/Terminology` con la tabla de 9 columnas.

**No hay que copiar ninguno de los dos al código de OpenEMR.** Motivos:

1. El importador parcheado carga el archivo `Full`, con todo el histórico
   (ver [sección 6.1](#61-sólo-archivos-snapshot-nunca-full)).
2. La tabla de relaciones del importador tiene 9 columnas: al cargar sin
   lista explícita, `relationshipGroup` se guarda en `typeId`
   (ver [sección 6.2](#62-listas-explícitas-de-columnas-en-cada-load-data)).
3. La carga por la interfaz web no permite elegir `Snapshot`, no avisa de
   errores y deja la base en un estado distinto del que espera esta
   documentación.

---

## 17. Licencia y avisos

- SNOMED CT® es marca registrada de SNOMED International. Su uso en Argentina
  está autorizado por el Centro Nacional de Terminología en Salud (CNTS) como
  *National Release Center*. Los licenciatarios nacionales deben cumplir las
  condiciones de la licencia de SNOMED International.
- La Extensión Argentina se publica trimestralmente por el CNTS
  (coordinación: Marina Zanetti) con el equipo técnico del NRC.
- Este repositorio contiene **scripts de carga y consultas**, no contenido de
  la terminología: el contenido viene del ZIP oficial y no se redistribute con
  este proyecto.
- Antes de publicar los scripts en un repositorio o compartirlos, verificar
  las condiciones de la licencia vigente de SNOMED International para
  licenciatarios.
