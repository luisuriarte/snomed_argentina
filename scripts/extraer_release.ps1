<#
.SYNOPSIS
    Extrae los archivos de la release de SNOMED CT que se usan para la carga.

.DESCRIPTION
    Extrae SÓLO los archivos .txt de la carpeta Snapshot/ del ZIP oficial y
    quita la carpeta raíz, dejando esta estructura:

        <Destino>\Snapshot\Terminology\sct2_Concept_Snapshot_....txt
        <Destino>\Snapshot\Refset\Content\der2_Refset_SimpleSnapshot_....txt
        ...

    No se extraen las carpetas Full/ ni Delta/ (ocupan mucho más y no se usan)
    ni los metadatos de Refset/Metadata/.

    Es la alternativa a la extracción que hace scripts/generar_carga.php, que
    necesita la extensión ext-zip de PHP.

.PARAMETER Zip
    Ruta del ZIP de la release.

.PARAMETER Destino
    Carpeta de destino. Si no se indica, se usa <carpeta del ZIP>\sct_carga_AAAAMMDD.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\extraer_release.ps1 `
        -Zip "D:\...\SnomedCT_Argentina-EditionRelease_PRODUCTION_20260820T120000Z.zip"
#>
param(
    [Parameter(Mandatory = $true)][string]$Zip,
    [string]$Destino
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Zip)) {
    Write-Error "No existe el ZIP: $Zip"
    exit 1
}

$zipFull = (Resolve-Path -LiteralPath $Zip).Path
$zipDir  = Split-Path -Parent $zipFull
$base    = [System.IO.Path]::GetFileNameWithoutExtension($zipFull)
if ($base -match '(\d{8})') {
    $fecha = $Matches[1]
} else {
    $fecha = Get-Date -Format 'yyyyMMdd'
}

if (-not $Destino) {
    $Destino = Join-Path $zipDir "sct_carga_$fecha"
}
$Destino = [System.IO.Path]::GetFullPath($Destino)

Write-Host "ZIP      : $zipFull"
Write-Host "Destino  : $Destino"

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($zipFull)
try {
    $total = 0
    $bytes = 0
    foreach ($entry in $archive.Entries) {
        if ($entry.FullName -notmatch '/Snapshot/') { continue }
        if ($entry.FullName -match '/Refset/Metadata/') { continue }
        if (-not $entry.Name.ToLower().EndsWith('.txt')) { continue }
        if ($entry.FullName.EndsWith('/')) { continue }

        # quitar la carpeta raíz del ZIP
        $rel = $entry.FullName -replace '^[^/]+/', ''
        $dest = Join-Path $Destino ($rel -replace '/', '\')

        $dir = Split-Path -Parent $dest
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
        }
        if ((Test-Path -LiteralPath $dest) -and (Get-Item -LiteralPath $dest).Length -eq $entry.Length) {
            Write-Host ("  (ya existe) {0}" -f $rel)
            continue
        }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dest, $true)
        $total++
        $bytes += $entry.Length
        Write-Host ("  {0,-78} {1,8:N1} MB" -f $rel, ($entry.Length / 1MB))
    }
    Write-Host ("Extraidos {0} archivos ({1:N1} MB) en {2}" -f $total, ($bytes / 1MB), $Destino)
}
finally {
    $archive.Dispose()
}
