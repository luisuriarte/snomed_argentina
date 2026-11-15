# Pendientes

Lo que quedó sin resolver o sin verificar. Tachar (o borrar) cada ítem cuando se resuelva y, si la solución cambia una decisión, anotarlo en `decisiones.md`.

## Datos que requieren una fuente o a un odontólogo

- [ ] **Significado de las marcas** `ficha_odontolog`, `ficha_periodontal`, `factura`, `material` y `maxilar`. Buscar la hoja original; si no aparece, mostrarle a un odontólogo tres filas (`08.01`, `08.03` y `04.02.01`) y preguntarle qué entiende de cada marca. Hasta entonces la vista las expone como `marca_*`.
- [ ] **`08.03` y `08.04`: radiografía postoperatoria.** El documento de referencia exige solo la preoperatoria y la tabla tiene también `rx_post`. Decisión C.1 de `20_correcciones.sql`.
- [ ] **`08.06` y `02.15 F`.** La norma de `08.06` (placas oclusales) es la de ferulización en el documento de referencia. Decidir qué código la lleva (decisión C.2).
- [ ] **`02.03`: norma.** Se copió la de `02.02` por suposición (en el documento van juntos). Confirmar con el listado donde `02.02` y `02.03` están separados.
- [ ] **`pieza = 1` en prótesis.** Está marcada en dentaduras completas y parciales, que no se hacen sobre un diente. Definir `unidad` para esos códigos (decisión C.3).
- [ ] **`maxilar` vacío en las prótesis parciales** (`04.02.01` a `04.02.05`), que necesitarían saber si es superior o inferior.
- [ ] **`08.05.01` a `08.05.03`** (ATM, bruxismo, aparatos oclusales) no tienen ninguna marca. Puede faltar el dato o puede que no se registren en ninguna ficha.
- [ ] **`01.07`** (bonos de otras obras sociales) está marcada para la ficha odontológica, siendo administrativa.
- [ ] **Unidades sin cargar:** prótesis, `04.04.05`, `04.04.06`, `04.04.10`, `09.02.02` y `09.02.03` (decisión C.3).
- [ ] **Radiografías en los capítulos que el documento no cubre** (IV, VI): sin verificar.

## Documentación de las fuentes

- [ ] Completar entidad, título completo y fecha del documento de referencia.
- [ ] Identificar los demás listados de los que se copió y anotar el origen por capítulo en `odontologico_capitulo.fuente`.
- [ ] **Cargar las normas generales** en `odontologico_capitulo.norma_general` (capítulos `00`, `02`, `03`, `08`, `09` y `10`, desde el PDF).
- [ ] **Agregar los capítulos `04` y `06`** a `odontologico_capitulo` (el script `99` los avisa) con su fuente.

## Mapeo a SNOMED CT

- [ ] **Mapear las prestaciones** a mano en `odontologico_sct`, por capítulo (seguimiento con `v_odontologico_mapeo_avance`). Sugerido: empezar por Endodoncia y Prótesis fija, y dejar Consultas para el final, porque mezcla prestaciones clínicas con administrativas.
- [ ] **Decidir qué códigos quedan `sin_equivalente`** (por ejemplo `01.07`).
- [ ] Revisar `v_odo_practicas_snomed_libres`: los procedimientos SNOMED que ningún código usa.

## Diagnósticos

- [ ] **Revisión clínica del ámbito** de los tres diagnósticos reasignados a mano (`odo_dx_ambito_manual`) y decisión sobre "celulitis", que queda en `otro`.
- [ ] **Revisión clínica de algunos mapas a CIE-10** que llaman la atención, por ejemplo "traumatismo oclusal primario" con `S09.9` y "pelo bucal" con `K13.3`. No se sabe si son errores del mapa o criterios que se desconocen.
- [ ] **Ortodoncia y maxilares:** el refset no trae diagnósticos con `K07` ni `K10` como código principal. Si el módulo los cubre, buscarlos en todo SNOMED CT.

## Reglas del texto libre

- [ ] **Estructurar dentición y sector** (temporaria o permanente, anterior o posterior) para el odontograma, como advertencias.
- [ ] **Pasar al módulo de cobertura** las edades, los topes, las esperas, los códigos incluidos y las autorizaciones previas (ver D9 de `decisiones.md`).
- [ ] El documento de referencia tiene una norma general de todo el nomenclador (un tope mensual de prestaciones por afiliado) que corresponde a cobertura.

## Pruebas

- [ ] Los scripts se probaron en **MariaDB 10.11** con una copia reducida de la tabla. **No se probaron en MySQL 8**, ni con los datos completos ni con medición de tiempos.
- [ ] Ejecutar `sql/99_verificaciones.sql` sobre la base real y revisar los `REVISAR`.
