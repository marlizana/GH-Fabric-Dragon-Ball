#-----------------------------------------------------------------------
# Naming Convention Test for Microsoft Fabric Items
#
# Este script verifica que los displayName en los archivos .platform cumplan
# con las convenciones de nomenclatura establecidas para cada tipo de item.
#
# Inspirado en: https://data-marc.com/2025/02/13/structure-fabric-items-by-applying-naming-conventions/
#-----------------------------------------------------------------------

param (
    [string]$path = $null,
    [string]$srcPath = "$PSScriptRoot\..\src"
)

$currentFolder = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

if ($path -eq $null) {
    $path = $currentFolder
}

# Usar la misma estructura de carpetas que los demás scripts
$testResultsDir = "$currentFolder\testResults"

# También asegurar que la carpeta existe
if (-not (Test-Path $testResultsDir)) {
    New-Item -Path $testResultsDir -ItemType Directory -Force | Out-Null
}

# Mapeo de tipos a códigos de prefijo
$typeMapping = @{
    "CopyJob" = "CJ"
    "DataPipeline" = "DP"
    "Dataflow" = "DF"
    "Eventstream" = "ES"
    "Notebook" = "NB"
    "Environment" = "EN"
    "Experiment" = "EX"
    "Lakehouse" = "LH"
    "Warehouse" = "WH"
    "Eventhouse" = "EH"
    "SQL" = "DB"
    "SemanticModel" = "SM"
    "KQLQuerySet" = "KQ"
    "Report" = "RP"
    "Dashboard" = "DS"
    "Scorecard" = "SC"
}

# Resolver la ruta absoluta de srcPath
$srcPath = Resolve-Path -Path $srcPath -ErrorAction SilentlyContinue

# Verificar si la carpeta src existe
if (-not $srcPath) {
    Write-Host "Error: La carpeta 'src' no existe en la ruta especificada."
    
    # Crear carpeta de resultados si no existe
    if (-not (Test-Path $testResultsDir)) {
        New-Item -Path $testResultsDir -ItemType Directory -Force | Out-Null
    }
    
    # Crear archivo XML con error
    $modelName = "NamingConventions"
    $testResultFile = "$testResultsDir\bpa-$modelName-results.xml"
    @"
<?xml version="1.0" encoding="utf-8"?>
<test-results name="NamingConventions" total="1" errors="1" failures="0" not-run="0">
  <test-suite name="NamingConventionTests" executed="True" success="False" result="Failure">
    <results>
      <test-case name="SourceFolderExists" executed="True" success="False" result="Error">
        <failure>
          <message>La carpeta 'src' no existe en la ruta especificada.</message>
        </failure>
      </test-case>
    </results>
  </test-suite>
</test-results>
"@ | Out-File -FilePath $testResultFile -Encoding UTF8
    
    Write-Error "La carpeta 'src' no existe en la ruta especificada."
    exit 0 # Terminamos con éxito aunque hubo error
}

# Lista para almacenar archivos con displayName inválido
$invalidFiles = @()

# Buscar todos los archivos .platform en el directorio src y sus subdirectorios
$platformFiles = Get-ChildItem -Path $srcPath -Recurse -Include "*.platform" -ErrorAction SilentlyContinue

foreach ($file in $platformFiles) {
    $displayName = $null
    $filePath = $file.FullName
    
    try {
        # Leer el archivo .platform (que es un archivo JSON)
        $platformContent = Get-Content -Path $filePath -Raw | ConvertFrom-Json -ErrorAction Stop
        
        # Extraer el displayName y type desde la propiedad metadata
        if ($platformContent.PSObject.Properties.Name -contains "metadata") {
            $metadata = $platformContent.metadata
            
            if ($metadata.PSObject.Properties.Name -contains "displayName" -and 
                $metadata.PSObject.Properties.Name -contains "type") {
                
                $displayName = $metadata.displayName
                $type = $metadata.type
                
                # Determinar el prefijo correcto según el tipo
                $expectedPrefix = $typeMapping[$type]
                
                if ($expectedPrefix) {
                    # Patrón específico para este tipo
                    $typePattern = "^$expectedPrefix`_[A-Za-z0-9]+"
                    
                    # Validar el displayName
                    if (-not ($displayName -match $typePattern)) {
                        $invalidFiles += @{
                            FilePath = $filePath
                            DisplayName = $displayName
                            Type = $type
                            ExpectedPrefix = $expectedPrefix
                        }
                    }
                } else {
                    # Tipo desconocido
                    Write-Host "Advertencia: Tipo desconocido '$type' en archivo $filePath"
                }
            }
        }
    } catch {
        Write-Host "Error al procesar el archivo $filePath`: $_"
    }
}

# Crear carpeta de resultados si no existe
if (-not (Test-Path $testResultsDir)) {
    New-Item -Path $testResultsDir -ItemType Directory -Force | Out-Null
}

# Crear archivo XML de resultados
$modelName = "NamingConventions"
$testResultFile = "$testResultsDir\bpa-$modelName-results.xml"

# Mostrar resultados y generar XML
if ($invalidFiles.Count -gt 0) {
    Write-Host "Los siguientes archivos .platform tienen un displayName que no cumple con la convencion de nombres:"
    
    foreach ($item in $invalidFiles) {
        Write-Host "- Archivo: $($item.FilePath)"
        Write-Host "  DisplayName: $($item.DisplayName)"
        Write-Host "  Tipo: $($item.Type)"
        Write-Host "  Prefijo esperado: $($item.ExpectedPrefix)_"
    }
    
    # Preparar XML en formato idéntico al de semantic model
    $totalTests = $invalidFiles.Count + 1  # +1 por la prueba de "FilesFound"
    $errors = 0
    $warnings = $invalidFiles.Count
    
    $xmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<test-results name="NamingConventions" total="$totalTests" errors="$errors" failures="$warnings" not-run="0" inconclusive="0" skipped="0" invalid="0" date="$(Get-Date -Format "yyyy-MM-dd")" time="$(Get-Date -Format "HH:mm:ss")">
  <test-suite name="NamingConventionTests" executed="True" success="False" result="Failure" time="0" asserts="$totalTests">
    <results>
      <test-case name="NamingConventions.FilesFound" executed="True" success="True" result="Success" time="0" asserts="1">
        <message><![CDATA[Se encontraron $($platformFiles.Count) archivos .platform para analizar]]></message>
      </test-case>

"@

    foreach ($item in $invalidFiles) {
        $fileName = Split-Path -Leaf (Split-Path -Parent $item.FilePath)
        $safeFileName = $fileName -replace '[^a-zA-Z0-9]', ''
        
        $xmlContent += @"
      <test-case name="NamingConventions.$safeFileName" executed="True" success="False" result="Warning" time="0" asserts="1">
        <message><![CDATA[El displayName '$($item.DisplayName)' no cumple con la convencion de nombres para tipo $($item.Type)]]></message>
        <failure>
          <message><![CDATA[El displayName '$($item.DisplayName)' no cumple con la convencion de nombres]]></message>
          <stack-trace><![CDATA[Tipo: $($item.Type)
Prefijo esperado: $($item.ExpectedPrefix)_
Archivo: $($item.FilePath)]]></stack-trace>
        </failure>
      </test-case>

"@
    }
    
    $xmlContent += @"
    </results>
  </test-suite>
</test-results>
"@
    
    # Guardar XML
    $xmlContent | Out-File -FilePath $testResultFile -Encoding UTF8
    
    exit 0  # Terminamos con éxito aunque hubo errores
} else {
    Write-Host "Todos los displayName en archivos .platform cumplen con la convencion de nombres para su tipo correspondiente."
    
    # Crear XML de éxito en formato idéntico al de semantic model
    @"
<?xml version="1.0" encoding="utf-8"?>
<test-results name="NamingConventions" total="1" errors="0" failures="0" not-run="0" inconclusive="0" skipped="0" invalid="0" date="$(Get-Date -Format "yyyy-MM-dd")" time="$(Get-Date -Format "HH:mm:ss")">
  <test-suite name="NamingConventionTests" executed="True" success="True" result="Success" time="0" asserts="1">
    <results>
      <test-case name="NamingConventions.AllFiles" executed="True" success="True" result="Success" time="0" asserts="1">
        <message><![CDATA[Todos los archivos cumplen con la convencion de nombres]]></message>
      </test-case>
    </results>
  </test-suite>
</test-results>
"@ | Out-File -FilePath $testResultFile -Encoding UTF8
    
    exit 0
}