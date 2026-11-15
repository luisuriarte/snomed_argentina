# odontologia_nomenclador

Datos y reglas de carga del **nomenclador de prestaciones odontológicas** para el módulo de odontología de OpenEMR, y su cruce con **SNOMED CT Edición Argentina**.

El nomenclador es el código que el odontólogo conoce y con el que se factura, y sus columnas dicen qué hay que pedir al registrar cada código (diente, caras, radiografías). SNOMED CT aporta el significado clínico estándar para poder intercambiar datos. Los dos conviven y no se reemplazan: ver [docs/decisiones.md](docs/decisiones.md).

## Relación con otros repositorios

| Repositorio | Qué aporta | Visibilidad |
|---|---|---|
| `snomed_argentina` | Carga de SNOMED CT Edición Argentina en OpenEMR. De él dependen los scripts `35_*`: necesitan sus tablas `sct2_*` y su `sql/06_odontologia.sql` | público |
| este | El nomenclador, sus correcciones, el mapeo a SNOMED y las vistas para el módulo | **privado** |

Este repositorio **no incluye ni crea la tabla `odontologico`**: es la fuente de datos y ya existe en la base. Los scripts la completan (clave, columnas, tablas auxiliares) y la corrigen.

## Requisitos

- La tabla `odontologico` (con las columnas descritas en [docs/diccionario_columnas.md](docs/diccionario_columnas.md)).
- Para los scripts `35_*`: `snomed_argentina` cargado, incluido su `sql/06_odontologia.sql`.
- MariaDB 10.4 o superior, o MySQL 8.0.14 o superior. Los scripts se probaron en MariaDB 10.11; **no se probaron en MySQL 8**.

## Orden de ejecución

Todo se ejecuta sobre la misma base donde está `odontologico`. Los scripts son idempotentes (se pueden repetir) salvo el respaldo, que crea una copia nueva cada vez.

| # | Script | Qué hace |
|---|---|---|
| 1 | `sql/00_respaldo.sql` | Copia de `odontologico` con fecha y hora en el nombre |
| 2 | `sql/10_estructura.sql` | Clave primaria, columnas `unidad` y `cantidad_max`, tablas auxiliares y lista de capítulos |
| 3 | `sql/20_correcciones.sql` | Correcciones puntuales, cada una con su fundamento. Las decisiones pendientes están comentadas |
| 4 | `sql/30_vistas.sql` | `v_odontologico_reglas`, `v_odontologico_mapeo` y `v_odontologico_mapeo_avance` |
| 5 | `sql/35_vistas_snomed.sql` | Vistas que cruzan con SNOMED CT (`v_odo_diagnosticos` y los controles de mapeo) |
| 6 | `sql/99_verificaciones.sql` | Controles de integridad (solo `SELECT`). Todo tiene que decir `OK` |

Con una edición nueva de SNOMED CT:

1. Cargarla con `snomed_argentina` (`01` a `03`) y volver a ejecutar su `06_odontologia.sql`.
2. Volver a ejecutar `sql/35_vistas_snomed.sql` de este repositorio. El de SNOMED recrea sus tablas y las vistas de este módulo quedarían apuntando a tablas que ya no existen.
3. Revisar que `SELECT * FROM v_odontologico_sct_control;` devuelva **cero filas** (mapeos a conceptos que desaparecieron o se dieron de baja) y mirar `v_odontologico_mapeo_avance`.

Los datos curados a mano (mapeo, estados, ámbitos) viven en tablas propias de este módulo y **sobreviven** a las recargas de SNOMED.

## Respaldo completo

`00_respaldo.sql` solo copia la tabla de origen. Para respaldar también las tablas auxiliares:

```bash
mysqldump BASE odontologico odontologico_capitulo odontologico_sct \
  odontologico_sct_estado odontologico_dx odo_dx_ambito_manual \
  | gzip > odontologia_$(date +%F).sql.gz
```

## Privacidad y licencias

- **Mantener este repositorio privado.** `20_correcciones.sql` contiene textos de normas copiados de documentos de terceros, y los datos del nomenclador tienen su propio origen y derechos.
- **No subir** datos, volcados, planillas ni PDF: el `.gitignore` los excluye.
- No incluir archivos ni listados de términos de SNOMED CT. Las condiciones de uso de la edición argentina se consultan con el Centro Nacional de Terminología en Salud.

## Documentación

- [docs/diccionario_columnas.md](docs/diccionario_columnas.md): qué significa cada columna y cuánta certeza hay de ello.
- [docs/decisiones.md](docs/decisiones.md): qué se decidió y por qué.
- [docs/fuentes.md](docs/fuentes.md): de dónde salen los datos.
- [docs/pendientes.md](docs/pendientes.md): lo que quedó sin resolver o sin verificar.
