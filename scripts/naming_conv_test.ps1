param (
    [string]$srcPath = "$PSScriptRoot\..\src"
)

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
    exit 1
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

# Mostrar resultados
if ($invalidFiles.Count -gt 0) {
    Write-Host "Los siguientes archivos .platform tienen un displayName que no cumple con la convencion de nombres:"
    foreach ($item in $invalidFiles) {
        Write-Host "- Archivo: $($item.FilePath)"
        Write-Host "  DisplayName: $($item.DisplayName)"
        Write-Host "  Tipo: $($item.Type)"
        Write-Host "  Prefijo esperado: $($item.ExpectedPrefix)_"
    }
    exit 1
} else {
    Write-Host "Todos los displayName en archivos .platform cumplen con la convencion de nombres para su tipo correspondiente."}