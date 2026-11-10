#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
convertir_excel_maps.py
=======================
Convierte los archivos Excel de mapeo del paquete SNOMED CT Argentina
(NBU y GTIN) a CSV tab-separado listo para LOAD DATA INFILE.

Uso:
    python convertir_excel_maps.py <carpeta_resources> [--solo-nbu | --solo-gtin]

Donde <carpeta_resources> es la carpeta que contiene:
    - Mapeo_NBU_SCT_Agosto26.xlsx
    - MAP_GTIN_a_RPCD_comercializadas_20260820.xlsx

Los CSV resultantes se escriben en la misma carpeta:
    - Mapeo_NBU_SCT_Agosto26.csv
    - MAP_GTIN_a_RPCD_comercializadas_20260820.csv

Requisitos:
    pip install openpyxl
"""

import sys
import os
import csv
import re
import glob
import argparse

try:
    import openpyxl
except ImportError:
    print("Error: falta openpyxl. Instalar con:  pip install openpyxl", file=sys.stderr)
    sys.exit(1)


def encontrar_archivo(carpeta, patron):
    """Busca un archivo en la carpeta usando glob case-insensitive."""
    hits = glob.glob(os.path.join(carpeta, patron), recursive=False)
    if hits:
        return hits[0]
    # intento case-insensitive en Windows/Linux
    for f in os.listdir(carpeta):
        if re.match(patron.replace('*', '.*'), f, re.IGNORECASE):
            return os.path.join(carpeta, f)
    return None


def normalizar_valor(v):
    """Normaliza un valor de celda Excel para CSV."""
    if v is None:
        return ''
    if isinstance(v, float) and v == int(v):
        return str(int(v))   # 660002.0 → '660002'
    return str(v)


def extraer_sctid(valor):
    """
    El campo SCT_IdConcept_FSN tiene formato:
        '879241000221101 |medición de acetona en orina de 24 horas (procedimiento)|'
    Extrae solo el ID numérico inicial.
    """
    m = re.match(r'^(\d+)', str(valor))
    return m.group(1) if m else str(valor)


def excel_a_csv(xlsx_path, csv_path, hoja=0, transformar_fila=None):
    """Abre un XLSX y escribe un CSV tab-separado UTF-8 sin BOM."""
    wb = openpyxl.load_workbook(xlsx_path, read_only=True, data_only=True)
    if isinstance(hoja, int):
        ws = wb.worksheets[hoja]
    else:
        ws = wb[hoja]

    filas = 0
    es_header = True
    with open(csv_path, 'w', newline='', encoding='utf-8') as fout:
        writer = csv.writer(fout, delimiter='\t', quotechar='"',
                            quoting=csv.QUOTE_MINIMAL, lineterminator='\n')
        for row in ws.iter_rows(values_only=True):
            if es_header:
                # Escribir encabezado tal cual (no transformar)
                writer.writerow([normalizar_valor(v) for v in row])
                es_header = False
            else:
                valores = [normalizar_valor(v) for v in row]
                if transformar_fila:
                    valores = transformar_fila(valores)
                writer.writerow(valores)
                filas += 1

    wb.close()
    return filas


def procesar_nbu(carpeta):
    patron = "Mapeo_NBU_SCT*.xlsx"
    xlsx = encontrar_archivo(carpeta, patron)
    if not xlsx:
        print(f"  ! No se encontró archivo NBU ({patron}) en: {carpeta}")
        return False

    csv_path = os.path.splitext(xlsx)[0] + '.csv'
    print(f"  → NBU: {os.path.basename(xlsx)}")

    # Transformación: col[0] = 'SCTID |FSN|' → solo el SCTID numérico
    #                 col[1] = CodigoNBU ya normalizado (float→int por normalizar_valor)
    def transform_nbu(cols):
        cols[0] = extraer_sctid(cols[0])
        return cols

    filas = excel_a_csv(xlsx, csv_path, hoja=0, transformar_fila=transform_nbu)
    print(f"  ✓ Generado: {os.path.basename(csv_path)}  ({filas} filas de datos)")
    return csv_path


def procesar_gtin(carpeta):
    patron = "MAP_GTIN*.xlsx"
    xlsx = encontrar_archivo(carpeta, patron)
    if not xlsx:
        print(f"  ! No se encontró archivo GTIN ({patron}) en: {carpeta}")
        return False

    csv_path = os.path.splitext(xlsx)[0] + '.csv'
    print(f"  → GTIN: {os.path.basename(xlsx)}")

    # Transformación: col[2] = RPCD_ID puede venir como float si Excel lo vio numérico
    def transform_gtin(cols):
        cols[2] = extraer_sctid(cols[2])  # solo el ID numérico
        return cols

    filas = excel_a_csv(xlsx, csv_path, hoja=0, transformar_fila=transform_gtin)
    print(f"  ✓ Generado: {os.path.basename(csv_path)}  ({filas} filas de datos)")
    return csv_path


def main():
    parser = argparse.ArgumentParser(description='Convierte Excel de mapeo SNOMED AR a CSV.')
    parser.add_argument('carpeta', help='Carpeta Resources con los archivos XLSX')
    parser.add_argument('--solo-nbu',  action='store_true', help='Solo convierte NBU')
    parser.add_argument('--solo-gtin', action='store_true', help='Solo convierte GTIN')
    args = parser.parse_args()

    carpeta = os.path.abspath(args.carpeta)
    if not os.path.isdir(carpeta):
        print(f"Error: carpeta no encontrada: {carpeta}", file=sys.stderr)
        sys.exit(1)

    print(f"Carpeta: {carpeta}")
    print()

    nbu_csv = None
    gtin_csv = None

    if not args.solo_gtin:
        nbu_csv = procesar_nbu(carpeta)
    if not args.solo_nbu:
        gtin_csv = procesar_gtin(carpeta)

    print()
    print("Listo. Siguiente paso:")
    print("  Ejecutar  sql/05_map_excel.sql  en DBeaver (Execute Script).")
    print("  Verifica con  sql/99_verificacion.sql.")


if __name__ == '__main__':
    main()
