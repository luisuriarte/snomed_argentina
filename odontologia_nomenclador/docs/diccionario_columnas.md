# Diccionario de columnas

Qué significa cada columna de `odontologico` y de las tablas auxiliares, y **cuánta certeza hay de ese significado**. Es el documento que hay que actualizar cuando aparezca la hoja original de las marcas o cuando un odontólogo confirme algo.

Grados de certeza:

- **Alta**: respaldada por un documento o evidente por la descripción de la prestación.
- **Media**: razonable, pero con casos que no encajan.
- **Sin confirmar**: se desconoce el significado exacto. No construir validaciones sobre estas columnas.

Las cantidades son las observadas en 2026-11, **antes** de aplicar `20_correcciones.sql`, y se desactualizan solas. Sirven de referencia, no de control.

## Tabla `odontologico` (138 códigos al 2026-11)

| Columna | Valores | Significado | Certeza |
|---|---|---|---|
| `codigo` | texto, clave primaria | Código de la prestación. Admite sufijos (`02.15 F`, `04.01.07 bis`, `04.02.04 i`, `08.04 C`). **La numeración cambia entre listados**: el mismo código puede ser otra prestación según la fuente (ver 08.06 en `docs/decisiones.md`) | Alta |
| `descripcion` | texto | Título de la prestación. Varía entre listados (por ejemplo `05.02` y `05.04`) | Media |
| `factura` | `1` o vacío | Probablemente "la prestación se factura". 130 con `1` y 8 vacías | Sin confirmar |
| `ficha_odontolog` | `1` o vacío | Hay dos lecturas posibles: "en qué ficha se registra" o "qué ficha debe acompañar a la prestación". Viene de una hoja que no se conserva | Sin confirmar |
| `ficha_periodontal` | `1` o vacío | Solo `08.03` y `08.04`, donde el documento exige una "ficha periodontal debidamente confeccionada". Coincide con esa lectura, pero no la prueba | Sin confirmar |
| `pieza` | `1` o vacío | Hay que indicar el diente. 76 con `1`. **Dudoso en prótesis**: está marcada en dentaduras completas y parciales, que no se hacen sobre un diente | Media |
| `caras` | `1` o vacío | Hay que indicar las caras del diente. 14 con `1` (obturaciones, incrustaciones) | Alta |
| `rx_pre` | `1` o vacío | Se exige radiografía preoperatoria. 35 con `1` | Alta donde el documento de referencia cubre el capítulo. Sin verificar en los capítulos que no cubre |
| `rx_post` | `1` o vacío | Se exige radiografía postoperatoria. 50 con `1` | Ídem |
| `material` | `1` o vacío | Solo `04.02.01` a `04.02.04` y `04.02.04 i`. Hipótesis: registrar los gramos de metal usados (la norma de `04.04.12` habla de "gramos estimados de los metales"), pero el dato no se copió | Sin confirmar |
| `maxilar` | `1` o vacío | Solo `04.04.01`, `04.04.10`, `04.04.11` y `10.16`. Hipótesis: pedir si es superior o inferior. Inconsistente: las prótesis parciales `04.02.01` a `04.02.05` lo necesitarían y no lo tienen | Sin confirmar |
| `agrupamiento` | texto | Capítulo escrito a mano. Tenía "Cápitulo" y "Capítulo", y guiones distintos; `20_correcciones.sql` los unifica | Alta |
| `norma_particular` | texto | Norma de cada código, copiada a mano del documento de referencia. **Puede estar en el código equivocado** (pasó con `02.03` y `02.04`, y queda dudoso `08.06`) | Media |
| `unidad` | texto, nueva | Sobre qué se registra cuando no es un diente: `sector`, `zona`, `glandula`, `arcada`, `piezas`, `elemento`, `protesis`, `estudio`, `exposicion`, `lado`. Vacía = no especificada; la vista deduce `pieza` si `pieza = 1` | Alta en las cargadas desde el documento (`08.03`, `08.04`, `10.04`, `10.15`, `09.02.06`) |
| `cantidad_max` | número, nueva | Cantidad máxima de esa unidad (por ejemplo 6 sectores o 6 zonas) | Alta |

## Tablas auxiliares

| Tabla | Para qué |
|---|---|
| `odontologico_capitulo` | Nombre de cada capítulo, su norma general y de qué documento se tomó. `capitulo` es el prefijo del código; el `00` guarda la norma general de todo el nomenclador |
| `odontologico_sct` | Mapeo de prestaciones a conceptos SNOMED CT (procedimientos). Relación N a N, con el tipo de relación: `equivalente`, `mas_general`, `mas_especifico` o `parcial`. Sin clave foránea hacia SNOMED a propósito |
| `odontologico_sct_estado` | Prestaciones que se decidió no mapear (`sin_equivalente`) o dejar para revisar (`revisar`) |
| `odontologico_dx` | Opcional. Diagnósticos habituales para los que se indica una prestación. Es una relación de **indicación**, no de equivalencia |
| `odo_dx_ambito_manual` | Correcciones manuales del ámbito de un diagnóstico SNOMED (`diente`, `glandulas`, `mucosa` u `otro`). Criterio clínico, por eso vive fuera de las vistas |

## Vistas

| Vista | Qué devuelve |
|---|---|
| `v_odontologico_reglas` | Una fila por código con las reglas de carga ya en `1` y `0`. Las marcas confirmadas se llaman `requiere_*`; las **sin confirmar** se llaman `marca_*` a propósito, para que ninguna pantalla prometa algo que nadie sabe si es cierto |
| `v_odontologico_mapeo` | Una fila por código con su mapeo y su situación: `mapeado`, `sin_equivalente`, `revisar` o `pendiente` |
| `v_odontologico_mapeo_avance` | Avance del mapeo por capítulo |
| `v_odo_diagnosticos` | Catálogo de diagnósticos (344 en la edición 2026-08-20) con todos sus códigos CIE-10 y su ámbito. Usa `v_sct_odonto_dx_cie10` de `snomed_argentina` |
| `v_odontologico_sct_control` | Mapeos que apuntan a conceptos que no existen o están dados de baja. **Debe devolver cero filas** |
| `v_odo_practicas_snomed_libres` | Prácticas SNOMED de odontología que todavía ningún código usa. Ayuda a mapear |
