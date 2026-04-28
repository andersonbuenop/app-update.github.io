# Script para processamento individual usando o apps_update.ps1 existente
param(
    [Parameter(Mandatory=$true)]
    [string]$SingleAppName,
    
    [switch]$Quiet = $false
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScriptPath = Join-Path $scriptPath "apps_update.ps1"
$csvPath = Join-Path $scriptPath 'data\apps.csv'
$tempCsvPath = Join-Path $scriptPath 'data\temp_single_app.csv'

try {
    # Limpar nome do app - remover aspas extras se existirem
    $SingleAppName = $SingleAppName.Trim('"')
    
    # Carregar CSV original
    $csvData = Import-Csv -Path $csvPath
    
    # Encontrar o app específico
    $targetApp = $csvData | Where-Object { $_.'System_Name3' -eq $SingleAppName }
    
    if (-not $targetApp) {
        $errorResult = @{
            success = $false
            error = "App '$SingleAppName' não encontrado no CSV"
            appName = $SingleAppName
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        ConvertTo-Json $errorResult -Depth 10
        return
    }
    
    # Criar CSV temporário com apenas um app
    $targetApp | Export-Csv -Path $tempCsvPath -NoTypeInformation -Encoding UTF8
    
    # Backup do CSV original
    $originalCsvBackup = Join-Path $scriptPath 'data\apps_backup.csv'
    try {
        Copy-Item -Path $csvPath -Destination $originalCsvBackup -Force -ErrorAction Stop
    } catch {
        $errorResult = @{
            success = $false
            error = "Não foi possível criar backup do CSV original: $($_.Exception.Message)"
            appName = $SingleAppName
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        ConvertTo-Json $errorResult -Depth 10
        return
    }
    
    # Substituir CSV original pelo temporário
    Copy-Item -Path $tempCsvPath -Destination $csvPath -Force
    
    # Executar o apps_update.ps1 principal (redirecionar output para arquivo temporário)
    $tempOutputPath = Join-Path $scriptPath 'data\temp_update_output.txt'
    & $mainScriptPath > $tempOutputPath 2>&1
    
    # Restaurar CSV original (só se backup existir)
    if (Test-Path $originalCsvBackup) {
        Copy-Item -Path $originalCsvBackup -Destination $csvPath -Force
    }
    
    # Ler o resultado do apps_single_output.csv (arquivo separado)
    $outputPath = Join-Path $scriptPath 'data\apps_single_output.csv'
    if (Test-Path $outputPath) {
        $result = Import-Csv -Path $outputPath | Where-Object { $_.'AppName' -eq $SingleAppName }
        
        if ($result) {
            # Preparar resultado JSON
            $resultObj = [PSCustomObject]@{
                success = $true
                app = [PSCustomObject]@{
                    appName = $result.'AppName'
                    appversion = $result.'appversion'
                    latestVersion = $result.'LatestVersion'
                    website = $result.'Website'
                    installedVersion = $result.'InstalledVersion'
                    status = $result.'Status'
                    license = $result.'License'
                    observation = $result.'Observacao'
                }
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            
            # Retornar JSON
            ConvertTo-Json $resultObj -Depth 10
        } else {
            $errorResult = @{
                success = $false
                error = "Resultado não encontrado no output"
                appName = $SingleAppName
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            ConvertTo-Json $errorResult -Depth 10
        }
    } else {
        $errorResult = @{
            success = $false
            error = "Arquivo de output não encontrado"
            appName = $SingleAppName
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        ConvertTo-Json $errorResult -Depth 10
    }
    
} catch {
    # Restaurar CSV original em caso de erro
    if ($originalCsvBackup -and (Test-Path $originalCsvBackup)) {
        Copy-Item -Path $originalCsvBackup -Destination $csvPath -Force
    }
    
    $errorResult = @{
        success = $false
        error = $_.Exception.Message
        appName = $SingleAppName
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    ConvertTo-Json $errorResult -Depth 10
} finally {
    # Limpar arquivos temporários
    if (Test-Path $tempCsvPath) { Remove-Item $tempCsvPath -Force }
    if ($originalCsvBackup -and (Test-Path $originalCsvBackup)) { Remove-Item $originalCsvBackup -Force }
    if (Test-Path $tempOutputPath) { Remove-Item $tempOutputPath -Force }
    
    # Limpar apenas o apps_single_output.csv para evitar filtro/loop (NÃO limpar o apps_output.csv principal)
    # DESCOMENTAR: Não limpar o arquivo para que os dados possam ser lidos pelo frontend
    # $singleOutputPath = Join-Path $scriptPath 'data\apps_single_output.csv'
    # if (Test-Path $singleOutputPath) {
    #     # Manter apenas o cabeçalho, limpar dados
    #     $header = "AppName,appversion,LatestVersion,Website,InstalledVersion,Status,License,SourceKey,SearchUrl,Observacao,IsNewVersion,SourceId,IconUrl,TipoApp,IsDeleted"
    #     Set-Content -Path $singleOutputPath -Value $header -Encoding UTF8
    # }
}
