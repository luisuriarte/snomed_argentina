# Decisiones

Qué se decidió, por qué, y qué se corrigió en el camino (2026-11). Si una decisión cambia, no borrarla: agregar una nueva debajo explicando el cambio.

## D1. El nomenclador y SNOMED CT conviven; no se reemplazan

El nomenclador es el código con el que se factura, y sus columnas son reglas de carga (qué pedir al registrar). SNOMED CT no tiene nada de eso: sus procedimientos son conceptos clínicos, sin reglas de facturación ni de datos obligatorios. SNOMED se suma para dar significado clínico estándar e interoperar.

## D2. Repositorio separado de `snomed_argentina`

- `snomed_argentina` es público y por diseño solo tiene scripts. El nomenclador y sus normas son datos de terceros, copiados a mano, con su propio origen y derechos.
- Los datos curados cambian cuando alguien los revisa; SNOMED CT cambia con cada edición. Y cada edición nueva reconstruye las tablas `sct2_*`.
- Lo que se deriva solo de SNOMED CT (por ejemplo diagnósticos con su CIE-10) sí va en `snomed_argentina/sql/06_odontologia.sql`. Lo que se cura a mano va acá.

## D3. El mapeo a SNOMED CT va en tablas, no en columnas

Un código del nomenclador puede apuntar a varios conceptos SNOMED y un concepto a varios códigos ("Corona colada" y "Corona colada con frente estético" pueden compartirlo). Una columna obligaría a guardar listas separadas por comas, que no se pueden validar. No hay clave foránea hacia las tablas de SNOMED porque se recargan en cada edición; en su lugar, `v_odontologico_sct_control` detecta conceptos que desaparecieron.

El mapeo es parcial por naturaleza. Muchas prestaciones son administrativas ("Bonos otras Obras Sociales") y no tienen equivalente clínico. Para eso existe `odontologico_sct_estado`. El paquete de SNOMED CT Edición Argentina **no trae ningún mapa** hacia este nomenclador, así que se arma a mano.

## D4. El CIE-10 no es equivalente de una prestación

El CIE-10 clasifica enfermedades. Lo que puede relacionarse con una prestación es el diagnóstico para el que suele indicarse, y es una relación de **indicación** (`odontologico_dx`), opcional y distinta de la equivalencia con SNOMED.

## D5. Los diagnósticos salen del refset de SNOMED CT; el CIE-10 se deriva

Los 344 diagnósticos del refset de odontología (`398711000221107`) tienen todos CIE-10, obtenido del mapa extendido de la edición. Todas las reglas del mapa en esta edición valen `TRUE` y la prioridad máxima es 1: el CIE-10 se puede derivar sin preguntar nada.

**El orden de los códigos CIE-10 no es clínico.** En "gingivitis inducida por placa dental", el grupo 1 es `K03.6` (depósitos en los dientes) y el 2 es `K05.1` (gingivitis). En "enfermedad gingival causada por el embarazo", el grupo 1 es `O26.8` (obstétrico). No usar el primero como diagnóstico principal; que el profesional elija cuál lo es, en especial para facturar. (Una versión anterior de este trabajo decía que el grupo 1 era el principal; era incorrecto.)

## D6. El ámbito de un diagnóstico sale del CIE-10, con correcciones manuales aparte

El refset no es solo de dientes: incluye glándulas salivales, mucosa, lengua y labios. El ámbito (`diente`, `glandulas`, `mucosa`, `otro`) se deduce del CIE-10 (K00 a K08, K11, K09 y K12 a K14). Ese criterio deja cuatro diagnósticos en `otro`; tres se reasignaron a mano (lesión dental y traumatismo oclusal primario a `diente`, y el síndrome de hipoacusia e insensibilidad de glándulas salivales a `glandulas`). **Es criterio mío y no clínico: falta la revisión de un odontólogo.** Las correcciones viven en `odo_dx_ambito_manual`, fuera de las vistas, para sobrevivir a las recargas de SNOMED.

El refset **no tiene diagnósticos con K07 (anomalías dentofaciales) ni K10 (maxilares) como código principal**. Si el módulo va a cubrir ortodoncia o cirugía de maxilares, hay que buscar y mapear esos conceptos aparte.

## D7. Las marcas sin confirmar se exponen con nombre neutro

`ficha_odontolog`, `ficha_periodontal`, `factura`, `material` y `maxilar` vienen de una hoja que no se conserva. En `v_odontologico_reglas` se llaman `marca_*`, y las confirmadas `requiere_*`. Ninguna pantalla debe validar sobre las primeras hasta confirmar qué significan.

## D8. Toda corrección lleva respaldo y fundamento

`20_correcciones.sql` marca cada una como `[PDF]` (respaldada por el documento de referencia) o `[CRITERIO]` (criterio clínico o de coherencia, a confirmar). Las decisiones sin resolver están comentadas. Antes de ejecutarlo, `00_respaldo.sql`.

## D9. Las reglas que están en texto libre

La columna `norma_particular` tiene reglas que el odontograma no puede validar mientras sigan siendo texto. Qué hacer con cada tipo:

| Tipo | Ejemplos | Dónde vive |
|---|---|---|
| Unidad de registro | por sector (`08.03`, `08.04`), por zona (`10.04`, `10.15`), por glándula (`09.02.06`) | **Columnas `unidad` y `cantidad_max`**: dato clínico |
| Dentición (temporaria o permanente) y sector (anterior o posterior) | `02.05`, `02.08`, `02.09`, `03.06` | Advertencia en el odontograma; todavía sin estructurar |
| Edad | `07.08` hasta 6 años, `05.05` hasta 15, `05.02` hasta 18 | **Módulo de cobertura**; en el odontograma solo advertencia |
| Frecuencia y topes | `01.01` una por año, `08.07` cada seis meses | Módulo de cobertura |
| Códigos incluidos | `08.03` incluye `05.01`, `05.04`, `08.02` y `08.05` | Módulo de cobertura |
| Esperas y prerrequisitos | `03.05` un año sin otra endodoncia, `08.07` requiere `08.03` u `08.04` | Módulo de cobertura |
| Autorización y documentos | autorización previa, fundamentar el motivo | Módulo de cobertura |

Las edades, topes y esperas pertenecen a la cobertura y no al acto clínico: el documento de referencia las atribuye genéricamente a "la Obra Social", y cada una puede fijar las suyas. Por eso en el odontograma solo se muestran como **advertencias, nunca como bloqueos**.

## D10. La numeración y los títulos cambian entre listados

La tabla se armó copiando de varios listados. Un mismo código puede ser otra prestación según la fuente: **`08.06` es "Placas oclusales" en la tabla y "Ferulización dentaria en sector anterior" en el documento de referencia**, y su norma (autorización previa, tres años de cobertura) es la de ferulización. También pasó con `02.03` y `02.04`, cuyas normas estaban cruzadas.

Consecuencias:

- Antes de confiar en una norma, comparar su texto con la descripción del código.
- **Mapear a SNOMED CT por lo que significa cada prestación, no por el texto ni por el número.**
- Anotar en `odontologico_capitulo.fuente` de qué documento sale cada capítulo.
