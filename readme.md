Consideraciones:

Editar código (estos ya estan agregados a los scripts):
/openemr/interface/code_systems/list_staged.php Linea 226, agregar:
```php
                } elseif (preg_match("/SnomedCT_Argentina-EditionRelease_PRODUCTION_([0-9]{8})[0-9a-zA-Z]{8}.zip/", $file, $matches)) {
                    // Hard code the version SNOMED feed to be International:Spanish
                    // Contains the Snapshot, Delta and Full folders with the Argentina extension files already unified
                    // with the Spanish and International files
                    //
                    $version = "International:Spanish";
                    $rf2 = true;
                    $date_release = substr($matches[1], 0, 4) . "-" . substr($matches[1], 4, -2) . "-" . substr($matches[1], 6);
                    $temp_date = array('date' => $date_release, 'version' => $version, 'path' => $mainPATH . "/" . $matches[0]);
                    array_push($revisions, $temp_date);
                    $supported_file = 1;
```

Borrar codigos en ingles de la version Argentina de Snomed:
```sql
DELETE FROM sct2_description WHERE languageCode='en'; (10 min aprox.)
DELETE FROM sct2_textdefinition WHERE languageCode='en';
```
Verificar:
```sql
SELECT * FROM sct2_description WHERE languageCode <> 'en'
```
Para Ver los códigos agregados en Argentina (PDF, ReleaseNotes)
es necesario crear una tabla auxiliar (sct2_refset) con este script:
```sql
CREATE TABLE IF NOT EXISTS `sct2_refset` (
            `id` varchar(80) NOT NULL,
            `effectiveTime` date NOT NULL,
            `active` int(11) NOT NULL,
            `moduleId` bigint(20) NOT NULL,
            `refsetId` bigint(25) NOT NULL,
			`referencedComponentId` bigint(25) NOT NULL,
			`owlExpression` text NOT NULL,
             PRIMARY KEY (`id`)
            ) 
			COLLATE='utf8mb4_general_ci'
            ENGINE=InnoDB;
```
			
Luego hay que tomar el archivo der2_Refset_SimpleFull_ArgentinaEdition_AAAAMMDD.txt
que esta en la carpeta Full/Refset/Content/
Cargar ese archivo en la tabla sct2_refset con el script (en consola mysql):
```mysql
LOAD DATA LOCAL INFILE 'der2_Refset_SimpleFull_ArgentinaEdition_AAAAMMDD.txt' INTO TABLE sct2_refset FIELDS TERMINATED BY '\\t' ESCAPED BY '' LINES TERMINATED BY '\\n' IGNORE 1 LINES;
```
En caso que no se cargen los datos en la tabla sct2_descriptions desde el script modificado, se debe hacer manualmente desde la consola ingresando a mysql:
```mysql
LOAD DATA LOCAL INFILE './sct2_Description_Full_ArgentinaEdition_20250820.txt' INTO TABLE sct2_description FIELDS TERMINATED BY '\t' ESCAPED BY '' LINES TERMINATED BY '\r\n' IGNORE 1 LINES;
```
Tabla donde esta cargadas las versiones de SNOMED: standardized_tables_track

Para encontrar los conjuntos de datos que hace referencia el PDF de Notas para la emision.
Se debe relacionar el campo referencedComponentId(conjunto de datos) de la tabla sct2_refset.
Con el campo conceptId de la tabla sct2_description y la condicion del valor de la referencia , 
campo refSetId de la tabla sct2_refset.
Por ejemplo refset 331101000221109 = conjunto de referencias simples de
presentaciones farmacéuticas comerciales del Vademecum Nacional de
Medicamentos en estado comercializado (metadato fundacional)
```sql
SELECT d.id, d.effectiveTime, r.active, d.term FROM sct2_description AS d
	INNER JOIN sct2_refset AS r
		ON r.referencedComponentId = d.conceptId
	WHERE r.refsetId = '331101000221109' 
		AND r.active = '1'
		AND d.`active` = '1'
		AND d.effectiveTime > '2003-10-31'
		AND d.term NOT LIKE '%(presentación farmacéutica comercial)'
		AND d.term NOT LIKE '%(fármaco de uso clínico comercial)'
		GROUP BY d.term;
```		
Ejemplo conjunto de referencias simples de Diagnósticos
de odontología de Argentina
```sql
SELECT d.id, d.effectiveTime, r.active, d.term FROM sct2_description AS d
	INNER JOIN sct2_refset AS r
		ON r.referencedComponentId = d.conceptId
	WHERE r.refsetId = '398711000221107' 
		AND r.active = '1'
		AND d.`active` = '1'
		AND d.effectiveTime > '2003-10-31'
		AND d.term NOT LIKE '%(hallazgo)'
		AND d.term NOT LIKE '%(trastorno)'
		GROUP BY d.term;
```

Ejemplo conjunto de referencias simples de Procedimientos
de odontología de Argentina
```sql
SELECT d.id, d.effectiveTime, r.active, d.term FROM sct2_description AS d
	INNER JOIN sct2_refset AS r
		ON r.referencedComponentId = d.conceptId
	WHERE r.refsetId = '399211000221109' 
		AND r.active = '1'
		AND d.`active` = '1'
		AND d.effectiveTime > '2003-10-31'
		AND d.term NOT LIKE '%(hallazgo)'
		AND d.term NOT LIKE '%(trastorno)'
		AND d.term NOT LIKE '%(procedimiento)'
		AND d.term NOT LIKE '%(objeto físico)'
		AND d.term NOT LIKE '%(régimen/tratamiento)'
		GROUP BY d.term;
```

conjunto de referencias simples de prácticas de laboratorio de Argentina:
```sql
SELECT d.id, d.effectiveTime, r.active, d.term FROM sct2_description AS d
	INNER JOIN sct2_refset AS r
		ON r.referencedComponentId = d.conceptId
	WHERE r.refsetId = '537301000221103' 
		AND r.active = '1'
		AND d.`active` = '1'
		AND d.effectiveTime > '2003-10-31'
		AND d.term NOT LIKE '%(procedimiento)'
		GROUP BY d.term;
```

Conjunto de referencias de prácticas prescribibles de diagnóstico por imágenes Argentina:
```sql
SELECT d.id, d.effectiveTime, r.active, d.term FROM sct2_description AS d
	INNER JOIN sct2_refset AS r
		ON r.referencedComponentId = d.conceptId
	WHERE r.refsetId = '536561000221108' 
		AND r.active = '1'
		AND d.`active` = '1'
		AND d.effectiveTime > '2003-10-31'
		AND d.term NOT LIKE '%(procedimiento)'
		GROUP BY d.term;	
```		
Para buscar medicamentos en recetas, estos estan en la tabla code. Para insertar los medicamentos de ANMAT en codes es:
Primero:
```sql
DELETE FROM codes WHERE code_type = '109';
```
Luego:
```sql
INSERT INTO codes
	SELECT 0 AS id, d.term AS code_text, '' AS code_text_short, ROW_NUMBER() OVER(ORDER BY id) AS code, '109' AS code_type,
		'' AS modifier, 0 AS units, NULL AS fee, 0.0 AS superbill, '' AS related_code, '' AS taxrates, 0 AS cyp_factor,
		1 AS active, 0 AS reportable, 0 AS financial_reporting, '' AS revenue_code 
	FROM sct2_description AS d
		INNER JOIN sct2_refset AS r
		ON r.referencedComponentId = d.conceptId
	WHERE r.refsetId = '331101000221109' 
		AND r.active = '1'
		AND d.`active` = '1'
		AND d.effectiveTime > '2003-10-31'
		AND d.term NOT LIKE '%presentación farmacéutica comercial%'
		AND d.term NOT LIKE '%fármaco de uso clínico comercial%'
		GROUP BY code_text;
```		
Agregar Vacunas de Argentina. Primero borrar otras vacunas (tabla codes)
Primero:
```sql
DELETE FROM codes WHERE code_type = '100';
```
Luego:
```sql
INSERT INTO codes
	SELECT 0 AS id, d.term AS code_text, d.term AS code_text_short, ROW_NUMBER() OVER(ORDER BY id) AS code, '100' AS code_type,
		'' AS modifier, 0 AS units, NULL AS fee, 0.0 AS superbill, '' AS related_code, '' AS taxrates, 0 AS cyp_factor,
		1 AS active, 0 AS reportable, 0 AS financial_reporting, '' AS revenue_code 
	FROM sct2_description AS d
		INNER JOIN sct2_refset AS r
		ON r.referencedComponentId = d.conceptId
	WHERE r.refsetId = '2281000221106' 
		AND r.active = '1'
		AND d.`active` = '1'
		AND d.effectiveTime > '2003-10-31'
		AND d.term NOT LIKE '%(fármaco de uso clínico%'
		AND d.term NOT LIKE '%(producto medicinal)'
		GROUP BY code_text;		
```	
		
