#-----------------------------------------------------------------------
# Best Practice Analyzer para reportes de Microsoft Fabric Power BI
#
# Este script analiza los reportes de Power BI (PBIR) para verificar el cumplimiento
# de buenas prácticas de diseño, rendimiento y usabilidad. Descarga automáticamente
# la herramienta PBI-Inspector si no está presente y genera resultados en formato XML
# compatible con sistemas de pruebas automatizadas.
#
# Basado en el trabajo de Rui Romano: https://github.com/RuiRomano/fabric-cli-powerbi-cicd-sample
# 
# Funcionalidades principales:
# - Análisis automatizado de reportes de Power BI
# - Detección de problemas de rendimiento y diseño
# - Generación de resultados en formato NUnit para integración con CI/CD
# - Clasificación de problemas por severidad (error, warning, info)
#-----------------------------------------------------------------------

param ($path = $null, $src = ".\..\src\*.Report")

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

    # Descargar PBI Inspector
    $destinationPath = "$currentFolder\_tools\PBIInspector"

    if (!(Test-Path "$destinationPath\win-x64\CLI\PBIRInspectorCLI.exe")) {
        New-Item -ItemType Directory -Path $destinationPath -ErrorAction SilentlyContinue | Out-Null            

        Write-Host "Downloading binaries"
    
        $downloadUrl = "https://github.com/NatVanG/PBI-InspectorV2/releases/latest/download/win-x64-CLI.zip"
    
        $zipFile = "$destinationPath\PBIInspector.zip"
    
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile
    
        Expand-Archive -Path $zipFile -DestinationPath $destinationPath -Force     
    
        Remove-Item $zipFile          
    }    
    
    $rulesPath = "$currentFolder\bpa-report-rules.json"

    if (!(Test-Path $rulesPath)) {
        Write-Host "Downloading default BPA rules"
    
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/NatVanG/PBI-InspectorV2/refs/heads/main/Rules/Base-rules.json" -OutFile "$destinationPath\bpa-report-rules.json"
        
        $rulesPath = "$destinationPath\bpa-report-rules.json"
    }

    # Ejecutar reglas BPA
    $itemsFolders = Get-ChildItem -Path $src -Recurse -Include ("*.pbir")

    foreach ($itemFolder in $itemsFolders) {    
        $itemPath = "$($itemFolder.Directory.FullName)\definition"

        if (!(Test-Path $itemPath)) {
            throw "Cannot find report PBIR definition. If you are using PBIR-Legacy (report.json), please convert it to PBIR using Power BI Desktop."
        }

        Write-Host "Running BPA rules for: '$itemPath'"

        # Crear directorio para resultados si no existe
        $testResultsDir = "$path\TestResults"
        if (!(Test-Path $testResultsDir)) {
            New-Item -ItemType Directory -Path $testResultsDir -Force | Out-Null
        }

        # Cambiar el método de ejecución para capturar la salida
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.FileName = "$destinationPath\win-x64\CLI\PBIRInspectorCLI.exe"
        $processStartInfo.Arguments = "-pbipreport ""$itemPath"" -rules ""$rulesPath"" -formats ""GitHub"""
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
        $reportName = Split-Path -Leaf (Split-Path -Parent $itemPath)
        
        # Guardar la salida cruda en un archivo de texto
        $txtFile = "$testResultsDir\bpa-$reportName-results.txt"
        "BPA Analysis for $itemPath - Exit code: $exitCode" | Out-File -FilePath $txtFile
        $stdout | Out-File -FilePath $txtFile -Append
        
        # Crear archivo XML con los resultados
        $xmlFile = "$testResultsDir\bpa-$reportName-results.xml"
        
        # Analizar las líneas para extraer violaciones
        $lines = $stdout -split "`n"
        $violations = @()
        $errors = 0
        $warnings = 0
        
        $currentRule = $null
        $currentIssue = $null
        $inIssuesList = $false
        
        foreach ($line in $lines) {
            $line = $line.Trim()
            
            # Detectar las secciones de reglas
            if ($line -match "^# (.+)$") {
                $currentRule = $matches[1]
                $inIssuesList = $false
                continue
            }
            
            # Detectar la lista de issues
            if ($line -eq "Issues found:") {
                $inIssuesList = $true
                continue
            }
            
            # Extraer items de la lista de issues (formato markdown)
            if ($inIssuesList -and $line -match "^\* (.+)$") {
                $issue = $matches[1].Trim()
                
                # Intentar determinar la severidad basada en contenido
                $severity = "Info"
                if ($issue -match "error|critical|critical issue|fail|incorrect|invalid" -or $line -match "::error::") {
                    $severity = "Error"
                    $errors++
                }
                elseif ($issue -match "warning|recommend|should|best practice|consider" -or $line -match "::warning::") {
                    $severity = "Warning"
                    $warnings++
                }
                
                $violations += @{
                    Rule = $currentRule
                    Issue = $issue
                    Severity = $severity
                    Message = "$currentRule - $issue"
                }
            }
            # También buscar formatos diferentes usando ::warning:: o ::error::
            elseif ($line -match "::(warning|error):: (.+)") {
                $severity = $matches[1]
                $issue = $matches[2].Trim()
                
                if ($severity -eq "error") {
                    $errors++
                }
                else {
                    $warnings++
                }
                
                $violations += @{
                    Rule = if ($currentRule) { $currentRule } else { "BPA Rule" }
                    Issue = $issue
                    Severity = $severity
                    Message = if ($currentRule) { "$currentRule - $issue" } else { $issue }
                }
            }
        }
        
        # Crear XML en formato NUnit
        $xmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<test-results name="BPA.Report.$reportName" total="$totalTests" errors="$errors" failures="$warnings" not-run="0" inconclusive="0" skipped="0" invalid="0" date="$(Get-Date -Format "yyyy-MM-dd")" time="$(Get-Date -Format "HH:mm:ss")">
  <test-suite name="PBIInspectorBPA" success="$($exitCode -eq 0)" time="0" asserts="$totalTests">
    <results>
"@

        # Si no hay violaciones, agregar un test-case de éxito
        if ($violations.Count -eq 0) {
            $xmlContent += @"
      <test-case name="BPA.$reportName.NoViolations" executed="True" success="True" result="Success" time="0" asserts="0">
        <message>No BPA rule violations found</message>
      </test-case>
"@
        }
        else {
            # Agregar un test-case por cada violación
            foreach ($violation in $violations) {
                $ruleSafe = $violation.Rule -replace '[^a-zA-Z0-9]', ''
                $issueSafe = $violation.Issue.Substring(0, [Math]::Min(30, $violation.Issue.Length)) -replace '[^a-zA-Z0-9]', ''
                $testName = "BPA.$reportName.$ruleSafe.$issueSafe"
                $success = $violation.Severity -ne "Error"
                $result = if ($violation.Severity -eq "Error") { "Failure" } elseif ($violation.Severity -eq "Warning") { "Warning" } else { "Success" }
                
                $xmlContent += @"
      <test-case name="$testName" executed="True" success="$success" result="$result" time="0" asserts="1">
        <message><![CDATA[$($violation.Message)]]></message>
        <failure>
          <message><![CDATA[$($violation.Message)]]></message>
          <stack-trace><![CDATA[Rule: $($violation.Rule)
Issue: $($violation.Issue)
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

        # Guardar el XML de formato NUnit
        $xmlContent | Out-File -FilePath $xmlFile -Encoding UTF8

        if ($exitCode -ne 0) {
            throw "Error running BPA rules for: '$itemPath'"
        }    
    }
}