#-----------------------------------------------------------------------
# Análisis de campos no utilizados para modelos semánticos de Power BI
#-----------------------------------------------------------------------

Param(
    [string]$path = "..",
    [string]$srcFolder = "src"
)

# Configuración inicial básica
$currentFolder = (Split-Path $MyInvocation.MyCommand.Definition -Parent)
$testResultsDir = "$currentFolder\testResults"
if (-not (Test-Path $testResultsDir)) {
    New-Item -Path $testResultsDir -ItemType Directory -Force | Out-Null
}
$xmlFile = "$testResultsDir\bpa-UsedUnusedFields-results.xml"

# Resolver rutas
$pathResolved = Resolve-Path -Path $path -ErrorAction SilentlyContinue
$srcPath = Join-Path -Path $pathResolved -ChildPath $srcFolder
if (-not (Test-Path $srcPath)) {
    throw "No se encontró la carpeta '$srcFolder' en '$pathResolved'."
}

# Estructuras de datos para el análisis
$modelTables = @()
$modelColumns = @{}
$modelMeasures = @{}
$usedTables = @()
$usedColumns = @{}
$pageNameMap = @{}
$fieldPages = @{}

# 1. MAPEAR NOMBRES DE PÁGINAS
$pageFiles = Get-ChildItem -Path $srcPath -Recurse -File -Include "page.json"
foreach ($file in $pageFiles) {
    try {
        $pageContent = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
        if ($pageContent.name -and $pageContent.displayName) {
            $pageNameMap[$pageContent.name] = $pageContent.displayName
        }
    } catch {}
}

# 2. ANALIZAR ARCHIVOS TMDL
$tmdlFiles = Get-ChildItem -Path $srcPath -Recurse -File -Include "*.tmdl"
foreach ($file in $tmdlFiles) {
    $content = Get-Content -Path $file.FullName
    $currentTable = $null
    
    foreach ($line in $content) {
        $line = $line.TrimStart()
        
        # Identificar tabla
        if ($line -match "^table\s+(.+)$") {
            $currentTable = $matches[1]
            if (-not $modelTables.Contains($currentTable)) {
                $modelTables += $currentTable
                $modelColumns[$currentTable] = @()
                $modelMeasures[$currentTable] = @()
            }
            continue
        }
        
        # Identificar columnas
        if ($currentTable -and $line -match "^\s*column\s+(.+)$") {
            $columnName = $matches[1]
            if (-not $modelColumns[$currentTable].Contains($columnName)) {
                $modelColumns[$currentTable] += $columnName
            }
            continue
        }
        
        # Identificar medidas - mejorado para capturar medidas correctamente
        if ($currentTable -and $line -match "^\s*measure\s+([^\s=]+)\s*=") {
            $measureName = $matches[1]
            if (-not $modelMeasures[$currentTable].Contains($measureName)) {
                $modelMeasures[$currentTable] += $measureName
            }
            continue
        }
    }
}

# 3. ANALIZAR ARCHIVOS VISUAL.JSON
$visualFiles = Get-ChildItem -Path $srcPath -Recurse -File -Include "visual.json"
foreach ($file in $visualFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    
    # Obtener ID de página desde la ruta
    $pageId = "Desconocida"
    $pageMatch = [regex]::Match($file.FullName, "pages[/\\]([^/\\]+)[/\\]")
    if ($pageMatch.Success) {
        $pageId = $pageMatch.Groups[1].Value
    }
    
    # Obtener nombre de página
    $pageName = if ($pageNameMap.ContainsKey($pageId)) { $pageNameMap[$pageId] } else { "Desconocida" }
    
    # Obtener tipo de visual
    $visualType = "Desconocido"
    $visualTypeMatch = [regex]::Match($content, '"visualType"\s*:\s*"([^"]+)"')
    if ($visualTypeMatch.Success) {
        $visualType = $visualTypeMatch.Groups[1].Value
    }
    elseif ($content -match '"image"\s*:') {
        $visualType = "image"
    }
    elseif ($content -match '"advancedSlicer"\s*:') {
        $visualType = "advancedSlicerVisual"
    }
    
    # Analizar tablas y campos utilizados
    $entityMatches = [regex]::Matches($content, '"Entity"\s*:\s*"([^"]+)"')
    foreach ($match in $entityMatches) {
        $tableName = $match.Groups[1].Value
        if (-not $usedTables.Contains($tableName)) {
            $usedTables += $tableName
            $usedColumns[$tableName] = @()
        }
        
        # Buscar propiedades (columnas/medidas)
        $contextStart = [Math]::Max(0, $match.Index - 100)
        $contextLength = [Math]::Min(400, $content.Length - $contextStart)
        $context = $content.Substring($contextStart, $contextLength)
        
        $propertyMatches = [regex]::Matches($context, '"Property"\s*:\s*"([^"]+)"')
        foreach ($propMatch in $propertyMatches) {
            $fieldName = $propMatch.Groups[1].Value
            
            if (-not $usedColumns[$tableName].Contains($fieldName)) {
                $usedColumns[$tableName] += $fieldName
            }
            
            $fieldKey = "$tableName.$fieldName"
            if (-not $fieldPages.ContainsKey($fieldKey)) {
                $fieldPages[$fieldKey] = @{}
            }
            if (-not $fieldPages[$fieldKey].ContainsKey($pageName)) {
                $fieldPages[$fieldKey][$pageName] = @()
            }
            if (-not $fieldPages[$fieldKey][$pageName].Contains($visualType)) {
                $fieldPages[$fieldKey][$pageName] += $visualType
            }
        }
    }
}

# 4. GENERAR OUTPUT

# TABLAS Y CAMPOS UTILIZADOS
Write-Host "TABLAS Y CAMPOS UTILIZADOS EN VISUALIZACIONES:" -ForegroundColor Green
foreach ($table in $usedTables | Sort-Object) {
    Write-Host "TABLA: $table" -ForegroundColor Yellow
    
    foreach ($col in $usedColumns[$table] | Sort-Object) {
        $isColumn = $modelColumns.ContainsKey($table) -and $modelColumns[$table].Contains($col)
        $isMeasure = $modelMeasures.ContainsKey($table) -and $modelMeasures[$table].Contains($col)
        $fieldKey = "$table.$col"
        
        $usageInfo = ""
        if ($fieldPages.ContainsKey($fieldKey)) {
            $details = @()
            foreach ($page in $fieldPages[$fieldKey].Keys | Sort-Object) {
                $visualsInPage = $fieldPages[$fieldKey][$page] -join ", "
                $details += "Pagina: '$page' - Visuales: $visualsInPage"
            }
            $usageInfo = " [" + ($details -join " | ") + "]"
        }
        
        if ($isColumn) {
            Write-Host "  COLUMNA: $col$usageInfo" -ForegroundColor Green
        } elseif ($isMeasure) {
            Write-Host "  MEDIDA: $col$usageInfo" -ForegroundColor Magenta
        } else {
            # Verificar si podría ser una medida no detectada correctamente
            $possibleMeasureTable = $null
            foreach ($t in $modelTables) {
                if ($modelMeasures[$t] -contains $col) {
                    $possibleMeasureTable = $t
                    break
                }
            }
            
            if ($possibleMeasureTable) {
                Write-Host "  MEDIDA: $col$usageInfo" -ForegroundColor Magenta
            } else {
                Write-Host "  CAMPO: $col$usageInfo" -ForegroundColor DarkYellow
            }
        }
    }
}

# CAMPOS NO UTILIZADOS
Write-Host "`nCAMPOS NO UTILIZADOS EN VISUALIZACIONES:" -ForegroundColor Red
foreach ($table in $modelTables | Sort-Object) {
    $tableHasUnused = $false
    $unusedOutputLines = @()
    
    # Columnas no utilizadas
    foreach ($col in $modelColumns[$table] | Sort-Object) {
        if (-not $usedTables.Contains($table) -or -not $usedColumns[$table].Contains($col)) {
            $unusedOutputLines += "  COLUMNA: $col [NO USADA]"
            $tableHasUnused = $true
        }
    }
    
    # Medidas no utilizadas
    foreach ($measure in $modelMeasures[$table] | Sort-Object) {
        if (-not $usedTables.Contains($table) -or -not $usedColumns[$table].Contains($measure)) {
            $unusedOutputLines += "  MEDIDA: $measure [NO USADA]"
            $tableHasUnused = $true
        }
    }
    
    # Solo mostrar la tabla si tiene campos no utilizados
    if ($tableHasUnused) {
        Write-Host "TABLA: $table" -ForegroundColor Yellow
        foreach ($line in $unusedOutputLines) {
            Write-Host $line -ForegroundColor DarkRed
        }
    }
}

# Crear XML en formato NUnit para CI/CD
$testResults = @()
$failureCount = 0

# Agregar test para cada campo no utilizado
foreach ($table in $modelTables | Sort-Object) {
    # Columnas no utilizadas
    foreach ($col in $modelColumns[$table] | Sort-Object) {
        if (-not $usedTables.Contains($table) -or -not $usedColumns[$table].Contains($col)) {
            $testResults += @"
      <test-case name="UnusedFields.$table.Column.$col" executed="True" success="False" result="Failure" time="0" asserts="1">
        <failure>
          <message><![CDATA[Columna no utilizada: $table.$col]]></message>
          <stack-trace><![CDATA[Esta columna está definida en el modelo pero no se utiliza en ninguna visualización.]]></stack-trace>
        </failure>
      </test-case>
"@
            $failureCount++
        }
    }
    
    # Medidas no utilizadas
    foreach ($measure in $modelMeasures[$table] | Sort-Object) {
        if (-not $usedTables.Contains($table) -or -not $usedColumns[$table].Contains($measure)) {
            $testResults += @"
      <test-case name="UnusedFields.$table.Measure.$measure" executed="True" success="False" result="Failure" time="0" asserts="1">
        <failure>
          <message><![CDATA[Medida no utilizada: $table.$measure]]></message>
          <stack-trace><![CDATA[Esta medida está definida en el modelo pero no se utiliza en ninguna visualización.]]></stack-trace>
        </failure>
      </test-case>
"@
            $failureCount++
        }
    }
}

# Si no hay campos no utilizados, agregar un test exitoso
if ($failureCount -eq 0) {
    $testResults += @"
      <test-case name="UnusedFields.NoUnusedFields" executed="True" success="True" result="Success" time="0" asserts="0">
        <message><![CDATA[Todos los campos definidos se utilizan en visualizaciones.]]></message>
      </test-case>
"@
}

$date = Get-Date -Format "yyyy-MM-dd"
$time = Get-Date -Format "HH:mm:ss"
$totalTests = if ($failureCount -eq 0) { 1 } else { $failureCount }
$success = if ($failureCount -eq 0) { "True" } else { "False" }

$xmlContent = @"
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<test-results name="FieldUsageAnalysis" total="$totalTests" errors="0" failures="$failureCount" not-run="0" inconclusive="0" ignored="0" skipped="0" invalid="0" date="$date" time="$time">
  <environment os-version="Windows" platform="Windows" cwd="PowerShell" user="System" machine-name="$env:COMPUTERNAME" />
  <test-suite name="FieldUsageAnalysis" success="$success" time="0" asserts="0">
    <results>
$testResults
    </results>
  </test-suite>
</test-results>
"@

# Guardar XML
$xmlContent | Out-File -FilePath $xmlFile -Encoding UTF8

Write-Host "Resultados guardados en XML: $xmlFile" -ForegroundColor Cyan
Write-Host "`nProceso completado." -ForegroundColor Green