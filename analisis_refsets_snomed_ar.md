# Análisis de Refsets SNOMED CT Argentina — Qué se puede usar en OpenEMR

> Basado en Release Notes Noviembre 2025 y Agosto 2026 (CNTS / NRC Argentina)

---

## Estado actual del proyecto `snomed_argentina`

Los siguientes refsets **ya están expuestos como vistas** en `03_postcarga.sql`:

| Vista | Refset ID | Descripción | Filas (aprox.) |
|---|---|---|---|
| `v_sct_generico` | `574471000221107` / `574481000221105` | Fármacos genéricos (con/sin unidad) en comercialización | 5.607 |
| `v_sct_marca` | `425071000221108` | Fármacos comerciales ANMAT | 15.139 |
| `v_sct_vacuna` | `2281000221106` | Vacunas notificables a NOMIVAC | 407 |
| `v_sct_practica_lab` | `537301000221103` | Prácticas de laboratorio (con mapeo NBU) | 1.007 |
| `v_sct_practica_imagen` | `536561000221108` | Prácticas prescribibles de diagnóstico por imágenes | 579 |
| `v_sct_odonto_dx` | `398711000221107` | Diagnósticos odontológicos | 344 |
| `v_sct_odonto_pr` | `399211000221109` | Procedimientos odontológicos | 118 |
| `v_sct_eno` | `651000221107` | Enfermedades de Notificación Obligatoria (SNVS) | 195 |
| `v_sct_prestacion` | `577281000221100` | Prácticas y procedimientos de la Edición AR | 2.143 |
| `v_sct_dispositivo` | `869651000221108` | Dispositivos médicos | 1.088 |
| `v_sct_cie10` | `447562003` | Mapeo SNOMED CT → CIE-10 | 217.373 |

---

## Refsets disponibles en los datos pero SIN vista todavía

### 🔴 ALTA PRIORIDAD para OpenEMR

#### 1. Especialidades en salud reconocidas por el Ministerio
- **Refset:** `331151000221108`
- **Tipo:** Simple (lista de conceptos)
- **Contenido:** Especialidades médicas reconocidas oficialmente por el Ministerio de Salud de la Nación (anestesiología, cardiología, dermatología, etc.)
- **Uso en OpenEMR:** Desplegable de especialidad en el perfil del profesional (`users` table, campo `specialty`). Interoperabilidad en FHIR `Practitioner.qualification`.
- **Vista sugerida:** `v_sct_especialidad`

#### 2. Profesiones matriculadas en salud
- **Refset:** `2271000221108`
- **Tipo:** Simple
- **Contenido:** Profesiones con matrícula habilitante para ejercer en salud (médico, enfermero, bioquímico, kinesiólogo, etc.)
- **Uso en OpenEMR:** Tipo de profesional en altas de usuarios. Requisito para receta electrónica.
- **Vista sugerida:** `v_sct_profesion`

#### 3. Ocupaciones vinculadas a especialidades
- **Refset:** `331131000221104`
- **Tipo:** Simple
- **Contenido:** Ocupaciones (en el sentido de SNOMED Occupation hierarchy) vinculadas a especialidades del Ministerio
- **Uso en OpenEMR:** Complementa `v_sct_especialidad` para campos de ocupación en FHIR.
- **Vista sugerida:** `v_sct_ocupacion`

#### 4. Fármacos distribuidos por Remediar / Medicamentos Esenciales
- **Refset:** `349091000221101`
- **Tipo:** Simple
- **Contenido:** Fármacos del programa Remediar (medicamentos gratuitos del Ministerio distribuidos en CAPS)
- **Uso en OpenEMR:** Marcar medicamentos disponibles en CAPS. Prescripción con indicación de "disponible sin costo". Muy relevante para el primer nivel de atención.
- **Vista sugerida:** `v_sct_remediar`

---

### 🟡 PRIORIDAD MEDIA — Programa SUMAR

> El Programa SUMAR es el seguro público de salud para población sin obra social.
> Sus refsets permiten saber qué diagnósticos y procedimientos son facturables al SUMAR.

#### 5. Diagnósticos del Programa SUMAR
- **Refset:** `371191000221103`
- **Tipo:** Simple (actualizado en Nov 2025)
- **Contenido:** Diagnósticos que forman parte de las reglas de facturación del SUMAR
- **Vista sugerida:** `v_sct_sumar_diag`

#### 6. Procedimientos del Programa SUMAR
- **Refset:** `371201000221100`
- **Tipo:** Simple (actualizado en Nov 2025)
- **Contenido:** Prestaciones facturables al SUMAR
- **Vista sugerida:** `v_sct_sumar_proced`

#### 7. Ámbitos de atención del Programa SUMAR
- **Refset:** `371221000221107`
- **Tipo:** Simple
- **Contenido:** Tipos de establecimientos/ámbitos que habilitan la facturación SUMAR (CAPS, hospital, etc.)
- **Vista sugerida:** `v_sct_sumar_ambito`

#### 8. Profesionales habilitados para el Programa SUMAR
- **Refset:** `371211000221102`
- **Tipo:** Simple
- **Contenido:** Tipos de profesionales que pueden facturar prestaciones al SUMAR
- **Vista sugerida:** `v_sct_sumar_profesional`

---

### 🟡 PRIORIDAD MEDIA — Mapeos externos

#### 9. Mapeo SNOMED → NOMIVAC (vacunas)
- **Refset:** `401211000221103`
- **Tipo:** Asociación (crossmap)
- **Contenido:** Linkea cada concepto de vacuna SNOMED con su código en el sistema NOMIVAC (registro nacional de vacunación)
- **Uso en OpenEMR:** Integración con NOMIVAC para notificación de vacunas administradas. Muy útil si el establecimiento notifica vacunaciones.
- **Vista sugerida:** `v_sct_nomivac` (JOIN entre `sct2_refset_simple` y los datos de asociación)

---

### 🟢 INTERESANTE — Contenido nuevo en 2026

#### 10. Categoría de expendio controlado (estupefacientes/psicotrópicos)
- **Atributo:** `579631000221106` → valores bajo `579641000221104`
- **Valores:** Estupefaciente lista I/II/III · Psicotrópico lista II/III/IV
- **Uso en OpenEMR:** Al prescribir, marcar automáticamente si un fármaco requiere receta oficial archivada. Integración con módulo de prescripción.
- **Implementación:** No es un refset simple sino un atributo en el grafo de relaciones. Requiere consulta a `sct2_relationship` o `der2_RelationshipSnapshot`.

#### 11. Condición de expendio (venta libre / bajo receta / archivada)
- **Atributos:** `574941000221106` (registrada) · `574951000221108` (genérica)
- **Valores:** venta libre · bajo receta · bajo receta archivada · bajo receta oficial · venta exclusiva UMN
- **Uso en OpenEMR:** Validación en prescripción: saber si un medicamento requiere receta y de qué tipo.
- **Implementación:** Igual que el punto anterior, via `sct2_relationship`.

---

### 🟢 INTERESANTE — Servicios y estructura organizacional

#### 12. Servicios vinculados a especialidades
- **Refset:** `331161000221105`
- **Tipo:** Simple
- **Contenido:** Servicios hospitalarios vinculados a cada especialidad (ej: Cardiología → Servicio de Cardiología)
- **Vista sugerida:** `v_sct_servicio`

#### 13. Asociación especialidad ↔ servicio
- **Refset:** `331191000221100`
- **Tipo:** Asociación
- **Contenido:** Tabla de relación entre especialidades y los servicios que las atienden

#### 14. Asociación especialidad ↔ ocupación
- **Refset:** `331171000221101`
- **Tipo:** Asociación
- **Contenido:** Tabla de relación entre especialidades y las ocupaciones/profesionales que las ejercen

---

### 🔵 PARA FUTURO — Archivos Excel adicionales en el paquete

Estos NO están en las tablas SQL sino en la carpeta `Resources/` del ZIP de SNOMED:

| Archivo | Contenido | Uso |
|---|---|---|
| `GTIN_mapping.xlsx` | SNOMED CT concept ID → GTIN (código de barras) | Trazabilidad de medicamentos |
| `NBU_mapping.xlsx` | SNOMED CT → Nomenclador Bioquímico Único | Correlación laboratorio |

> Para incorporarlos habría que procesar estos Excel con un script similar a `generar_carga.php`
> y cargarlos en tablas auxiliares como `sct2_map_nbu` y `sct2_map_gtin`.

---

## Pueblos originarios (ya en datos, sin vista)

- **Refset:** `93491000221103`
- **Contenido:** Grupos de pueblos originarios reconocidos por el Ministerio de Salud
- **Uso potencial:** Campo de etnia/identidad cultural en datos del paciente (OpenEMR `patient_data.ethnicity`)
- **Vista sugerida:** `v_sct_pueblo_originario`

---

## Presentaciones farmacéuticas (ya parcialmente en datos)

Además de `v_sct_generico` y `v_sct_marca`, existen:

| Refset | Descripción | Nota |
|---|---|---|
| `574451000221100` | Presentaciones farmacéuticas comerciales (históricas + vigentes) | Incluye todas desde 2019 |
| `331101000221109` | Presentaciones farmacéuticas en estado **comercializado vigente** | Solo las activas hoy |

> La diferencia clave: `574451000221100` incluye medicamentos retirados del mercado (útil para historial),
> mientras que `331101000221109` es la lista "viva" para prescripción.

---

## Recomendación de implementación

### Fase 1 — Agregar a `03_postcarga.sql` ahora

```sql
-- v_sct_especialidad
CREATE OR REPLACE VIEW v_sct_especialidad AS
SELECT c.id AS sctid, d.term AS descripcion
FROM sct2_concept_snapshot c
JOIN sct2_description_snapshot d ON c.id = d.conceptId AND d.active = 1 AND d.typeId = '900000000000003001'
JOIN sct2_refset_snapshot r      ON c.id = r.referencedComponentId AND r.active = 1
WHERE r.refsetId = '331151000221108' AND c.active = 1;

-- v_sct_profesion
CREATE OR REPLACE VIEW v_sct_profesion AS
SELECT c.id AS sctid, d.term AS descripcion
FROM sct2_concept_snapshot c
JOIN sct2_description_snapshot d ON c.id = d.conceptId AND d.active = 1 AND d.typeId = '900000000000003001'
JOIN sct2_refset_snapshot r      ON c.id = r.referencedComponentId AND r.active = 1
WHERE r.refsetId = '2271000221108' AND c.active = 1;

-- v_sct_remediar
CREATE OR REPLACE VIEW v_sct_remediar AS
SELECT c.id AS sctid, d.term AS descripcion
FROM sct2_concept_snapshot c
JOIN sct2_description_snapshot d ON c.id = d.conceptId AND d.active = 1 AND d.typeId = '900000000000003001'
JOIN sct2_refset_snapshot r      ON c.id = r.referencedComponentId AND r.active = 1
WHERE r.refsetId = '349091000221101' AND c.active = 1;

-- v_sct_sumar_diag
CREATE OR REPLACE VIEW v_sct_sumar_diag AS
SELECT c.id AS sctid, d.term AS descripcion
FROM sct2_concept_snapshot c
JOIN sct2_description_snapshot d ON c.id = d.conceptId AND d.active = 1 AND d.typeId = '900000000000003001'
JOIN sct2_refset_snapshot r      ON c.id = r.referencedComponentId AND r.active = 1
WHERE r.refsetId = '371191000221103' AND c.active = 1;

-- v_sct_sumar_proced
CREATE OR REPLACE VIEW v_sct_sumar_proced AS
SELECT c.id AS sctid, d.term AS descripcion
FROM sct2_concept_snapshot c
JOIN sct2_description_snapshot d ON c.id = d.conceptId AND d.active = 1 AND d.typeId = '900000000000003001'
JOIN sct2_refset_snapshot r      ON c.id = r.referencedComponentId AND r.active = 1
WHERE r.refsetId = '371201000221100' AND c.active = 1;

-- v_sct_pueblo_originario
CREATE OR REPLACE VIEW v_sct_pueblo_originario AS
SELECT c.id AS sctid, d.term AS descripcion
FROM sct2_concept_snapshot c
JOIN sct2_description_snapshot d ON c.id = d.conceptId AND d.active = 1 AND d.typeId = '900000000000003001'
JOIN sct2_refset_snapshot r      ON c.id = r.referencedComponentId AND r.active = 1
WHERE r.refsetId = '93491000221103' AND c.active = 1;
```

> IMPORTANTE: Verificar el nombre real de la tabla de refsets en tu instalación.
> En el proyecto actual se usa `sct2_refset_snapshot` — confirmarlo antes de ejecutar.

### Fase 2 — Vistas de mapeo (requieren tabla de asociación)
- `v_sct_nomivac` — necesita verificar qué tabla almacena los refsets de tipo crossmap
- Atributos de expendio — requieren join a `sct2_relationship_snapshot`

---

## Estadísticas de la Edición Argentina (acumuladas desde 2018)

| Categoría | Conceptos |
|---|---|
| Producto biológico/farmacéutico | 41.946 (78%) |
| Calificadores | 10.844 (20%) |
| Procedimientos | 308 |
| Sustancias | 168 |
| Hallazgos clínicos | 69 |
| **Total** | **53.643** |

Descriptions: 114.197 · Relationships: 365.351

