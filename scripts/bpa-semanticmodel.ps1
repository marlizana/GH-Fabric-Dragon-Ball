#-----------------------------------------------------------------------
# Best Practice Analyzer para modelos semánticos de Microsoft Fabric
#
# Este script analiza modelos semánticos para verificar
# el cumplimiento de buenas prácticas de modelado, rendimiento y diseño.
# Descarga automáticamente Tabular Editor si no está presente y ejecuta
# reglas de análisis de mejores prácticas (BPA), generando resultados en
# formato XML compatible con sistemas de pruebas automatizadas.
#
# Basado en el trabajo de Rui Romano: https://github.com/RuiRomano/fabric-cli-powerbi-cicd-sample
# 
# Funcionalidades principales:
# - Análisis automatizado de modelos semánticos
# - Detección de problemas de diseño, rendimiento y mantenibilidad
# - Validación de convenciones y buenas prácticas en tablas, columnas y medidas
# - Generación de resultados en formato NUnit para integración con CI/CD
# - Clasificación de problemas por severidad (error, warning, info)
#-----------------------------------------------------------------------

param ($path = $null, $src = ".\..\src\*.SemanticModel")

$currentFolder = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

if ($path -eq $null) {
    $path =  $currentFolder
}

# Convertir las rutas a absolutas para evitar problemas
$path = Resolve-Path -Path $path
$src = Resolve-Path -Path $src -ErrorAction SilentlyContinue

if (-not $src) {
    throw "The source path '$src' does not exist. Please check the folder structure."
}

Set-Location $path

if ($src) {

    # Descargar Tabular Editor
    $destinationPath = "$currentFolder\_tools\TE"

    if (!(Test-Path "$destinationPath\TabularEditor.exe")) {
        New-Item -ItemType Directory -Path $destinationPath -ErrorAction SilentlyContinue | Out-Null            

        Write-Host "Downloading binaries"
    
        $downloadUrl = "https://github.com/TabularEditor/TabularEditor/releases/latest/download/TabularEditor.Portable.zip"
    
        $zipFile = "$destinationPath\TabularEditor.zip"
    
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile
    
        Expand-Archive -Path $zipFile -DestinationPath $destinationPath -Force     
    
        Remove-Item $zipFile          
    }    
    
    $rulesPath = "$currentFolder\bpa-semanticmodel-rules.json"

    if (!(Test-Path $rulesPath)) {
        Write-Host "Downloading default BPA rules"
    
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/microsoft/Analysis-Services/master/BestPracticeRules/BPARules.json" -OutFile "$destinationPath\bpa-semanticmodel-rules.json"
        
        $rulesPath = "$destinationPath\bpa-semanticmodel-rules.json"
    }

    # Ejecutar reglas BPA
    $itemsFolders = Get-ChildItem -Path $src -Recurse -Include ("*.pbidataset", "*.pbism")

    foreach ($itemFolder in $itemsFolders) {    
        $itemPath = "$($itemFolder.Directory.FullName)\definition"

        if (!(Test-Path $itemPath)) {
            $itemPath = "$($itemFolder.Directory.FullName)\model.bim"

            if (!(Test-Path $itemPath)) {
                throw "Cannot find semantic model definition."
            }
        }

        Write-Host "Running BPA rules for: '$itemPath'"

        # Cambiar el método de ejecución para capturar la salida
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.FileName = "$destinationPath\TabularEditor.exe"
        $processStartInfo.Arguments = """$itemPath"" -A ""$rulesPath"" -G"
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.RedirectStandardError = $true
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processStartInfo
        $process.Start() | Out-Null

        # Capturar y mostrar la salida en tiempo real
        $stdout = $process.StandardOutput.ReadToEnd()
        Write-Host $stdout

        # Completar el proceso
        $process.WaitForExit()

        # Capturar el código de salida
        $exitCode = $process.ExitCode
        
        # Analizar la salida y crear archivo XML
        $modelName = Split-Path -Leaf (Split-Path -Parent $itemPath)
        
        # Crear directorio si no existe
        $testResultsDir = "$path\TestResults"
        if (!(Test-Path $testResultsDir)) {
            New-Item -ItemType Directory -Path $testResultsDir -Force | Out-Null
        }
        
        # Guardar la salida cruda en un archivo de texto
        $txtFile = "$testResultsDir\bpa-$modelName-results.txt"
        "BPA Analysis for $itemPath - Exit code: $exitCode" | Out-File -FilePath $txtFile
        $stdout | Out-File -FilePath $txtFile -Append
        
        # Crear archivo XML con los resultados
        $xmlFile = "$testResultsDir\bpa-$modelName-results.xml"
        
        # Analizar las líneas para extraer violaciones
        $lines = $stdout -split "`n"
        $violations = @()
        $errors = 0
        $warnings = 0
        
        foreach ($line in $lines) {
            $line = $line.Trim()
            
            # Ignorar líneas vacías o de cabecera
            if ($line -eq "" -or $line -match "^={10,}$" -or $line -match "^Loading model\.\.\.$" -or $line -match "^Running Best Practice Analyzer\.\.\.$" -or $line -match "^Tabular Editor") {
                continue
            }
            
            $severity = "Info"
            $message = $line
            
            # Verificar si es un warning
            if ($line -match "^::warning::\s+(.*)$") {
                $severity = "Warning"
                $message = $matches[1]
                $warnings++ 
            }
            # Verificar si es un error
            elseif ($line -match "^::error::\s+(.*)$") {
                $severity = "Error" 
                $message = $matches[1]
                $errors++
            }
            
            # Si encontramos una violación (líneas que contienen "violates rule")
            if ($message -match "(.+)\s+violates rule\s+(.+)") {
                $object = $matches[1].Trim()
                $rule = $matches[2].Trim()
                
                $violations += @{
                    Object = $object
                    Rule = $rule
                    Severity = $severity
                    Message = $message
                }
            }
        }
        
        # Contar cuántas pruebas tenemos en total
        $totalTests = $violations.Count
        if ($totalTests -eq 0) { $totalTests = 1 } # Al menos una prueba (la general)
        
        # Crear XML
        $xmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<test-results name="BPA.SemanticModel.$modelName" total="$totalTests" errors="$errors" failures="$warnings" not-run="0" inconclusive="0" skipped="0" invalid="0" date="$(Get-Date -Format "yyyy-MM-dd")" time="$(Get-Date -Format "HH:mm:ss")">
  <test-suite name="TabularEditorBPA" success="$($exitCode -eq 0)" time="0" asserts="$totalTests">
    <results>
"@

        # Si no hay violaciones, agregar un test-case de éxito
        if ($violations.Count -eq 0) {
            $xmlContent += @"
      <test-case name="BPA.$modelName.NoViolations" executed="True" success="True" result="Success" time="0" asserts="0">
        <message>No BPA rule violations found</message>
      </test-case>
"@
        }
        else {
            # Agregar un test-case por cada violación
            foreach ($violation in $violations) {
                $testName = "BPA.$modelName.$($violation.Object).$($violation.Rule -replace '[^a-zA-Z0-9]', '')"
                $success = $violation.Severity -ne "Error"
                $result = if ($violation.Severity -eq "Error") { "Failure" } elseif ($violation.Severity -eq "Warning") { "Warning" } else { "Success" }
                
                $xmlContent += @"
      <test-case name="$testName" executed="True" success="$success" result="$result" time="0" asserts="1">
        <message><![CDATA[$($violation.Message)]]></message>
        <failure>
          <message><![CDATA[$($violation.Message)]]></message>
          <stack-trace><![CDATA[Object: $($violation.Object)
Rule: $($violation.Rule)
Severity: $($violation.Severity)]]></stack-trace>
        </failure>
      </test-case>
"@
            }
        }

        # Cerrar el XML
        $xmlContent += @"
    </results>
  </test-suite>
</test-results>
"@

        # Guardar el archivo XML
        $xmlContent | Out-File -FilePath $xmlFile -Encoding utf8
        
        Write-Host "Results saved to $xmlFile" -ForegroundColor Cyan
    }
}
