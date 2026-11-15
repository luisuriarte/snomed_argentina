# Fuentes

De dónde salen los datos de este repositorio y qué se sabe (y qué no) de cada fuente. Completar los datos que faltan cuando se conozcan.

## 1. Documento de referencia: normas del nomenclador

- **Archivo:** `NORMAS-trabajoVIGENTES.pdf`
- **URL:** `https://circulo.com.org.ar/wp-content/uploads/2022/09/NORMAS-trabajoVIGENTES.pdf`
- **Título:** "Nomenclador Nacional de Prestaciones Odontológicas", en forma de anexo de normas.
- **Entidad emisora y fecha:** **no figuran en el texto**. El dominio sugiere un círculo odontológico y la ruta del archivo sugiere septiembre de 2022. Completar con la entidad, el título completo y la fecha si se consigue la versión original.
- **Nombra siempre a "la Obra Social" en general**, sin referirse a ninguna en particular.
- **Estructura:** una norma general al principio (un tope de prestaciones mensuales por afiliado, además de la consulta anual), normas generales de capítulo y normas particulares por código.
- **Normas generales de capítulo** solo en los capítulos II, III, VIII, IX y X. Los capítulos I, V y VII no las tienen.
- **Capítulos que contiene:** I, II, III, V, VII, VIII, IX y X.
- **Capítulos que NO contiene:** IV (prótesis) y VI. Los códigos de esos capítulos y sus normas vienen de otros listados.

Lo que se verificó contra este documento: las marcas de radiografía (`rx_pre`, `rx_post`), las unidades de registro, las normas de `02.03`, `02.04` y `08.06`, y el título de `02.06`. Los códigos con radiografía pendientes de decisión están en `20_correcciones.sql` (sección C) y en `99_verificaciones.sql` (sección 2).

## 2. Otros listados para odontólogos

- La tabla `odontologico` se armó **copiando a mano de varios listados**, que no se identificaron.
- De otras fuentes salen, entre otros, los códigos que el documento de referencia no trae: `01.02`, `01.06`, `01.07`, `02.03`, `03.03`, `03.04` y todo el capítulo `04`.
- La numeración y los títulos cambian entre listados (ver D10 en `decisiones.md`).
- **Pendiente:** identificar cada listado (título, entidad, fecha) y anotarlo por capítulo en `odontologico_capitulo.fuente`.

## 3. Hoja de las marcas

Las columnas `ficha_odontolog` y `ficha_periodontal` se copiaron de una hoja que **no se conserva**. No se sabe si las demás marcas (`factura`, `material`, `maxilar`, `pieza`, `caras`) vienen de la misma. Su significado exacto no está confirmado (ver `diccionario_columnas.md`).

## 4. SNOMED CT Edición Argentina

- Cargada con el repositorio `snomed_argentina`. Edición **2026-08-20**.
- Refsets usados: diagnósticos de odontología (`398711000221107`, 344 conceptos), procedimientos de odontología (`399211000221109`, 118 conceptos) y el mapa extendido de SNOMED CT a CIE-10 (`447562003`).
- El paquete **no trae ningún mapa hacia este nomenclador**: los otros mapas que contiene son a CIE-10, CIE-O, CTV3 y NOMIVAC (vacunas).
