##Start-Transcript -Path "$PSScriptRoot\app_update_debug_transcript.txt" -Force
Write-Host "=== Início do processo (CSV + scraping com fallback Chocolatey→GitHub→Website) ===" -ForegroundColor Green

$csvPath = $PSScriptRoot + '\apps.csv'

if (-not (Test-Path $csvPath)) {
    Write-Host "ERRO: exporta primeiro o Excel para CSV: $csvPath" -ForegroundColor Red
    exit 1
}

# Função auxiliar para converter PSObject para Hashtable
function ConvertTo-Hashtable {
    param([Parameter(ValueFromPipeline)]$InputObject)
    if ($null -eq $InputObject) { return @{} }
    if ($InputObject -is [System.Collections.Hashtable]) { return $InputObject }
    
    $ht = @{}
    $InputObject.PSObject.Properties | ForEach-Object {
        if ($_.Value -is [PSCustomObject]) {
            $ht[$_.Name] = (ConvertTo-Hashtable $_.Value)
        } else {
            $ht[$_.Name] = $_.Value
        }
    }
    return $ht
}

#$data = Import-Csv -Path $csvPath
$data = Import-Csv -Path $csvPath | Select-Object `
    @{ Name = 'AppName'; Expression = { $_.'System_Name3' } }, `
    @{ Name = 'appversion'; Expression = { $_.'Version2' } }


# ---------------------- Carregar mapeamento apps do JSON ------------------------------------
$jsonPath = $PSScriptRoot + '\appSources.json'
if (Test-Path $jsonPath) {
    Write-Host "[JSON] Carregando appSources.json..."
    $AppSources = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json | ConvertTo-Hashtable
} else {
    # Fallback se não houver JSON
    Write-Host "[JSON] appSources.json não encontrado, usando defaults."
    $AppSources = @{
        '7zip' = @{
            Type = 'Website'
            ScrapeUrl = 'https://www.7-zip.org/download.html'
            OutputUrl = 'https://www.7-zip.org/'
            VersionPattern = 'Download 7-Zip\s+([0-9]+\.[0-9]+)'
        }

        'notepad++' = @{
            Type = 'GitHub'
            ApiUrl = 'https://api.github.com/repos/notepad-plus-plus/notepad-plus-plus/releases/latest'
            RepoUrl = 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases/latest'
            OutputUrl = 'https://notepad-plus-plus.org/downloads/'
        }

        'google chrome' = @{
            Type = 'Website'
            ScrapeUrl = 'https://googlechromelabs.github.io/chrome-for-testing/'
            OutputUrl  = 'https://chromeenterprise.google/intl/pt_br/download/?modal-id=download-chrome'
            VersionPattern = '([0-9]{3}\.[0-9]+\.[0-9]+\.[0-9]+)'
        }
    }
}

# ---------------------- funções --------------------------------------------

function Get-InstalledVersion {
    param(
        [string]$AppName,
        [string]$AppVersion
    )

    # 1) Se existe AppVersion, usar ela
    if ($AppVersion -and $AppVersion -match '(\d+(\.\d+)*(\.[A-Z0-9]+)?)') {
        return (Normalize-Version $matches[1] $AppName)
    }

    # 2) Tentar extrair do AppName
    if ($AppName -match '(\d+(\.\d+)*(\.[A-Z0-9]+)?)') {
        return (Normalize-Version $matches[1] $AppName)
    }

    # 3) Fallback: pegar o último número (ex: "05-2025" → 2025 → 25)
    if ($AppName -match '(\d+)(?!.*\d)') {
        $v = $matches[1]
        if ($v.Length -eq 4 -and $v -match '^20\d{2}$') {
            return Normalize-Version "$(([int]$v) - 2000)" $AppName
        }
        return $v
    }

    return $null
}

function Normalize-Version {
    param(
        [string]$Version,
        [string]$AppName = $null
    )

    if (-not $Version) { return $null }

    # Tratamento específico para Node.js: manter versão original (ex: 25.6.0)
    if ($AppName) {
        $normApp = Get-NormalizedAppName -RawName $AppName
        if ($normApp -eq 'node.js') {
            return $Version
        }
    }

    # Caso "2025" => "25"
    if ($Version -match '^\d{4}$' -and $Version -match '^20\d{2}$') {
        return "$(([int]$Version) - 2000)"
    }

    
# Caso "2025.1.21111" => "25.1.21111" (somente se o segundo segmento < 10)
    # Exceção: "2026.23.3.1" deve ficar como está (23 >= 10)
    if ($Version -match '^20(?<yy>\d{2})\.(?<seg2>\d+)(?<rest>(\..*)?)$') {
        $seg2 = [int]$Matches['seg2']
        if ($seg2 -lt 10) {
            return "$($Matches['yy']).$seg2$($Matches['rest'])"
        } else {
            return $Version  # mantém íntegro
        }
    }


    # ---- Normalização específica para 7-Zip / padrões semânticos mistos ----
    # Chocolatey costuma usar "25.1.0" para o mesmo build que o site oficial "25.01"
    # (vide 7-Zip 25.01 publicado em 03/08/2025). [1](https://archive.org/download/7zip-version-archive/7-Zip%20Versions/)[2](https://www.afterdawn.com/software/version_history.cfm/7-zip)
    if ($Version -match '^(?<maj>\d+)\.(?<min>\d+)\.(?<patch>\d+)$') {
        $maj   = [int]$Matches['maj']
        $min   = [int]$Matches['min']
        $patch = [int]$Matches['patch']

        # Se patch == 0, padronizar para "x.yy" (ex.: 25.1.0 -> 25.01)
        if ($patch -eq 0) {
            $minPadded = '{0:D2}' -f $min
            return "$maj.$minPadded"
        }

        # Se houver patch != 0, retornar como está; comparação deve ser semântica depois
        return "$maj.$min.$patch"
    }

    # Caso "25" => "25.0" (compatibilidade)
    if ($Version -match '^\d{2}$' -and -not ($Version -match '\.')) {
        return $Version + '.0'
    }

    return $Version
}

# Função auxiliar para comparação semântica segura entre formatos diferentes
function Compare-Version {
    param(
        [Parameter(Mandatory=$true)][string]$A,
        [Parameter(Mandatory=$true)][string]$B
    )
    # Normaliza ambos
    $NA = Normalize-Version $A
    $NB = Normalize-Version $B

    # Tenta comparação semântica completa se ambos forem "x.y.z"
    if ($NA -match '^\d+\.\d+\.\d+$' -and $NB -match '^\d+\.\d+\.\d+$') {
        $vA = [version]$NA
        $vB = [version]$NB
        if ($vA -gt $vB) { return 1 }
        elseif ($vA -lt $vB) { return -1 }
        else { return 0 }
    }

    # Caso típico do 7-Zip: "25.01" vs "25.1.0" => ambos viram "25.01" e "25.01"
    # ou "25.02" vs "25.2.0" => "25.02" e "25.02"
    if ($NA -match '^\d+\.\d{2}$' -and $NB -match '^\d+\.\d{2}$') {
        # Comparação lexicográfica funciona (mesmo número de dígitos)
        if ($NA -gt $NB) { return 1 }
        elseif ($NA -lt $NB) { return -1 }
        else { return 0 }
    }

    # Fallback: remover sufixos não numéricos e comparar
    $FA = ($NA -replace '[^\d\.]','')
    $FB = ($NB -replace '[^\d\.]','')
    try {
        $vA = [version]$FA
        $vB = [version]$FB
        if ($vA -gt $vB) { return 1 }
        elseif ($vA -lt $vB) { return -1 }
        else { return 0 }
    } catch {
        # Último recurso: comparar strings
        return ([string]::Compare($NA, $NB))
    }
}

# Exemplo de uso com seu inventário:
$installed = '25.01'      # inventário (site oficial)
$latest    = '25.1.0'     # vindo do Chocolatey OData

switch (Compare-Version -A $latest -B $installed) {
    1 { $status = 'UpdateAvailable' }
   -1 { $status = 'UpToDate' }
    0 { $status = 'UpToDate' }
}

function Compare-AppVersion {
    param(
        [string]$Installed,
        [string]$Latest,
        [bool]$IsDiscontinued = $false,
        [string]$AppName = $null
    )

    # Se é descontinuado, sempre retornar "Discontinued"
    if ($IsDiscontinued) {
        return 'Discontinued'
    }

    if (-not $Installed -or -not $Latest) { return 'Unknown' }

    # Normalizar ambas as versões
    $Installed = Normalize-Version $Installed $AppName
    $Latest = Normalize-Version $Latest $AppName

    try {
        # Para versões com sufixo tipo ".AM17", extrair e comparar base separadamente
        # Se encontrar sufixo tipo ".AM" ou ".RC", comparar base+sufixo diferente
        $baseInstalled = $Installed -replace '\.[A-Z][A-Z0-9]*$', ''
        $baseLatest = $Latest -replace '\.[A-Z][A-Z0-9]*$', ''
        
        $vInstalled = [version]$baseInstalled
        $vLatest    = [version]$baseLatest
        
        # Se base é igual, comparar o sufixo também
        if ($vInstalled -eq $vLatest) {
            # Extrair sufixos
            $suffixInstalled = $Installed -replace '^[0-9.]*', ''
            $suffixLatest = $Latest -replace '^[0-9.]*', ''
            
            if ($suffixInstalled -and $suffixLatest) {
                $numInstalled = [int]($suffixInstalled -replace '[^0-9]', '')
                $numLatest = [int]($suffixLatest -replace '[^0-9]', '')
                if ($numInstalled -lt $numLatest) { return 'UpdateAvailable' }
                if ($numInstalled -gt $numLatest) { return 'UpToDate' }
            }
            return 'UpToDate'
        }
    }
    catch {
        return 'Unknown'
    }

    if ($vInstalled -lt $vLatest) { return 'UpdateAvailable' }
    return 'UpToDate'
}
function Get-ChocolateyLatestVersion {
    param(
        [Parameter(Mandatory = $true)][string]$PackageId,
        [string]$OutputUrl
    )

    Write-Host " [Chocolatey] Buscando: $PackageId"

    try {
        $chocoUrl = "https://community.chocolatey.org/api/v2/Packages()?`$filter=Id%20eq%20'$PackageId'%20and%20IsLatestVersion"
        $response = Invoke-WebRequest `
            -Uri $chocoUrl `
            -UseBasicParsing `
            -TimeoutSec 5 `
            -ErrorAction Stop

        $content = $response.Content
        
$pattern = '(?:<|&lt;)d:Version(?:>|&gt;)\s*([0-9]+(?:\.[0-9]+){1,3})\s*(?:</|&lt;/)d:Version(?:>|&gt;)'
if ($content -match $pattern) {
    $version = $matches[1]
    Write-Host " [Chocolatey] ✓ Versão encontrada: $version"
    return [PSCustomObject]@{ Version = $version; Website = $OutputUrl; IsDiscontinued = $false }
}

    }
    catch {
        Write-Host " [Chocolatey] Timeout/Erro: $($_.Exception.Message)" -ForegroundColor Gray
    }
    
    return [PSCustomObject]@{ Version = $null; Website = $OutputUrl; IsDiscontinued = $false }
}

function Get-GitHubLatestVersionAPI {
    param(
        [Parameter(Mandatory = $true)][string]$ApiUrl,
        [string]$OutputUrl
    )

    Write-Host " [GitHubAPI] API: $ApiUrl"

    try {
        $response = Invoke-WebRequest `
            -Uri $ApiUrl `
            -Headers @{ 'User-Agent' = 'PowerShell' } `
            -UseBasicParsing `
            -TimeoutSec 5 `
            -ErrorAction Stop

        $json = $response.Content | ConvertFrom-Json
        $version = $json.tag_name -replace '^v',''

        Write-Host " [GitHubAPI] ✓ Versão encontrada: $version"

        return [PSCustomObject]@{ Version = $version; Website = $OutputUrl; IsDiscontinued = $false }
    }
    catch {
        Write-Host " [GitHubAPI] Timeout/Erro: $($_.Exception.Message)" -ForegroundColor Gray
        return [PSCustomObject]@{ Version = $null; Website = $OutputUrl; IsDiscontinued = $false }
    }
}

function Get-GitHubLatestVersionHTML {
    param(
        [Parameter(Mandatory = $true)][string]$RepoUrl,
        [string]$OutputUrl
    )

    Write-Host " [GitHubHTML] URL: $RepoUrl"

    try {
        $html = Invoke-WebRequest `
            -Uri $RepoUrl `
            -UseBasicParsing `
            -Headers @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } `
            -TimeoutSec 5 `
            -ErrorAction Stop

        $content = $html.Content
    }
    catch {
        Write-Host " [GitHubHTML] Timeout/Erro: $($_.Exception.Message)" -ForegroundColor Gray
        return [PSCustomObject]@{ Version=$null; Website=$OutputUrl; IsDiscontinued=$false }
    }

    if ($content -match '/tag/v?([0-9]+\.[0-9]+(\.[0-9]+)?)') {
        return [PSCustomObject]@{ Version = $matches[1]; Website = $OutputUrl; IsDiscontinued=$false }
    }

    if ($content -match 'Latest release.*?v?([0-9]+\.[0-9]+(\.[0-9]+)?)') {
        return [PSCustomObject]@{ Version = $matches[1]; Website = $OutputUrl; IsDiscontinued=$false }
    }

    return [PSCustomObject]@{ Version=$null; Website=$OutputUrl; IsDiscontinued=$false }
}

function Find-BestSourceForApp {
    param([string]$AppName)
    
    <#
    Estratégia: Tenta encontrar a melhor fonte na ordem de eficiência
    1. Chocolatey (mais rápido)
    2. GitHub (rápido)
    3. Maven/Web (mais lento)
    #>
    
    $normalized = $AppName.ToLower() -replace '\s+', ' ' -replace '[\-\(\)\.]+', ''
    
    # Tenta match no JSON primeiro (já tem tudo configurado)
    foreach ($key in $AppSources.Keys) {
        $keyNorm = $key -replace '[\s\-]+', ''
        $appNorm = $normalized -replace '[\s\-]+', ''
        
        if ($appNorm -like "*$keyNorm*" -or $keyNorm -like "*$appNorm*") {
            return $key
        }
    }
    
    return $null
}

function Get-WebsiteLatestVersion {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$VersionPattern,
        [string]$OutputUrl
    )

    Write-Host " [Web] URL: $Url"

    $finalUrl = if ($OutputUrl) { $OutputUrl } else { $Url }

    try {
        $html = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        $content = $html.Content
    }
    catch {
        Write-Host " [Web] Timeout/Erro: $($_.Exception.Message)" -ForegroundColor Gray
        return [PSCustomObject]@{
            Version = $null
            Website = $finalUrl
            IsDiscontinued = $false
        }
    }

    if ($content -match $VersionPattern) {
        $version = $matches[1]
        Write-Host " [Web] ✓ Versão encontrada: $version"
        return [PSCustomObject]@{
            Version = $version
            Website = $finalUrl
            IsDiscontinued = $false
        }
    }
    else {
        Write-Host " [Web] ✗ Versão NÃO encontrada (regex)"
        return [PSCustomObject]@{
            Version = $null
            Website = $finalUrl
            IsDiscontinued = $false
        }
    }
}

function Resolve-AppInfoOnline {
    param([string]$RawName)

    $normalized = Get-NormalizedAppName -RawName $RawName
    if (-not $normalized) { return [PSCustomObject]@{ Version=$null; Website=$null; IsDiscontinued=$false } }

    Write-Host "  [*] A resolver app: '$RawName' (normalizado: '$normalized')"

    if (-not $AppSources.ContainsKey($normalized)) {
        Write-Host "    - Não há configuração para '$normalized'."
        return [PSCustomObject]@{ Version=$null; Website=$null; IsDiscontinued=$false }
    }

    $src = $AppSources[$normalized]

    # Estratégia de fallback: Chocolatey → GitHub → Website
    # 1) Tenta Chocolatey (mais rápido e confiável)
    if ($src.ChocolateyId) {
        Write-Host "   [Fallback 1] Tentando Chocolatey..."
        $result = Get-ChocolateyLatestVersion -PackageId $src.ChocolateyId -OutputUrl $src.OutputUrl
        if ($result.Version) { return $result }
    }

    # 2) Tenta GitHub
    if ($src.Type -eq 'GitHub') {
        Write-Host "   [Fallback 2] Tentando GitHub..."
        
        # 2a) tenta API (se existir)
        if ($src.ApiUrl) {
            $result = Get-GitHubLatestVersionAPI -ApiUrl $src.ApiUrl -OutputUrl $src.OutputUrl
            if ($result.Version) { return $result }
        }

        # 2b) tenta HTML
        if ($src.RepoUrl) {
            $result = Get-GitHubLatestVersionHTML -RepoUrl $src.RepoUrl -OutputUrl $src.OutputUrl
            if ($result.Version) { return $result }
        }
    }

    # 3) Tenta Website (scraping com regex)
    if ($src.Type -eq 'Website') {
        Write-Host "   [Fallback 3] Tentando Web scraping..."
        return Get-WebsiteLatestVersion `
            -Url $src.ScrapeUrl `
            -VersionPattern $src.VersionPattern `
            -OutputUrl $src.OutputUrl
    }

    # 4) Type Fixed: versão descontinuada
    if ($src.Type -eq 'Fixed') {
        Write-Host " [Fixed] Versão fixa: $($src.Version)"
        return [PSCustomObject]@{
            Version = $src.Version
            Website = $src.OutputUrl
            IsDiscontinued = $true
        }
    }elseif ($src.Type -eq 'Licenced') {
        Write-Host " [Licenced] Versão Licenciada: $($src.Version)"
        return [PSCustomObject]@{
            Version = $src.Version
            Website = $src.OutputUrl
            IsDiscontinued = $false
        }
    }

    return [PSCustomObject]@{ Version=$null; Website=$null; IsDiscontinued=$false }
}

function Get-NormalizedAppName {
    param([string]$RawName)

    if ([string]::IsNullOrWhiteSpace($RawName)) { return $null }

    $name = $RawName.ToLower().Trim()
    #$name = $name -replace '\s+v?\d+(\.\d+)*.*$',''  # Remove versões e sufixos

    
    # 1) remover versão (já com o patch que você aplicou)
    $name = $name -replace '\s+v?\d+(\.\d+)*.*$',''

    # 2) remover separadores/resíduos no fim (hífen, en/em dash, dois-pontos, espaço)
$name = $name -replace '\s*[-–—:]\s*$', ''

    # 3) trim final por garantia
    $name = $name.Trim()

    # Match apps registrados no JSON (via MatchRegex)
    if ($AppSources) {
        foreach ($key in $AppSources.Keys) {
            $entry = $AppSources[$key]
            if ($entry.MatchRegex) {
                foreach ($pattern in $entry.MatchRegex) {
                    if ($name -match $pattern) { return $key }
                }
            }
        }
    }

    return $name
}

function Get-LicenseForApp {
    param([string]$RawName)

    if ([string]::IsNullOrWhiteSpace($RawName)) { return 'licensed' }

    $norm = Get-NormalizedAppName -RawName $RawName

    if ($AppSources -and $norm -and $AppSources.ContainsKey($norm)) {
        $src = $AppSources[$norm]
        if ($src.License) { return $src.License }
        if ($src.Type -eq 'Licenced') { return 'licensed' }
    }

    return 'licensed'
}

# 2) Processar linhas do CSV em memória
$index = 0
$totalApps = @($data).Count
$processedApps = @{} # Hashtable para rastrear apps duplicados
$uniqueData = @()    # Lista para armazenar apenas linhas únicas

foreach ($row in $data) {
    $index++
    $appName = $row.AppName

    if (-not $appName) { continue }

    # Normalizar nome para verificar duplicidade
    $normalizedCheck = Get-NormalizedAppName -RawName $appName
    if ($normalizedCheck) {
        if ($processedApps.ContainsKey($normalizedCheck)) {
            Write-Host "[$index/$totalApps] IGNORADO (Duplicado): '$appName' -> '$normalizedCheck'" -ForegroundColor Yellow
            continue
        }
        $processedApps[$normalizedCheck] = $true
    }

    Write-Host "[$index/$totalApps] AppName: '$appName'" -ForegroundColor Cyan

    try {
        $info = Resolve-AppInfoOnline -RawName $appName
    }
    catch {
        Write-Host "    ✗ ERRO CRÍTICO ao resolver '$appName': $($_.Exception.Message)" -ForegroundColor Red
        $info = [PSCustomObject]@{ Version=$null; Website=$null; IsDiscontinued=$false }
    }

    # garantir colunas
    foreach ($col in 'LatestVersion','Website','InstalledVersion','Status','License','SourceKey','SearchUrl','Observacao') {
        if (-not ($row.PSObject.Properties.Name -contains $col)) {
            $row | Add-Member -NotePropertyName $col -NotePropertyValue $null
        }
    }

    # obter chave e url de busca do JSON
    $normKey = Get-NormalizedAppName -RawName $row.AppName
    $searchUrlVal = $null
    if ($normKey -and $AppSources.ContainsKey($normKey)) {
        $srcObj = $AppSources[$normKey]
        # Preferência: RepoUrl (GitHub) > ScrapeUrl (Website) > ApiUrl
        if ($srcObj.RepoUrl) { $searchUrlVal = $srcObj.RepoUrl }
        elseif ($srcObj.ScrapeUrl) { $searchUrlVal = $srcObj.ScrapeUrl }
        elseif ($srcObj.ApiUrl) { $searchUrlVal = $srcObj.ApiUrl }
    }

    # versão instalada
    $installedVersion = Get-InstalledVersion -AppName $row.AppName -AppVersion $row.appversion

    # Normalizar versão online antes de comparar e salvar
    $normalizedLatestVersion = Normalize-Version $info.Version $row.AppName

    # comparar - passar o flag IsDiscontinued
    $status = Compare-AppVersion -Installed $installedVersion -Latest $normalizedLatestVersion -IsDiscontinued $info.IsDiscontinued -AppName $row.AppName

    # preencher dados
    $row.InstalledVersion = $installedVersion
    $row.LatestVersion    = $normalizedLatestVersion
    $row.Website          = $info.Website
    $row.Status           = $status
    $row.SourceKey        = $normKey
    $row.SearchUrl        = $searchUrlVal
    $row.License          = Get-LicenseForApp -RawName $row.AppName

    # Adicionar à lista de dados únicos
    $uniqueData += $row
}

# 3) Gravar CSV de saída
$outPath =  $PSScriptRoot + "\apps_output.csv"
Write-Host "A gravar CSV em: $outPath"
$uniqueData | Export-Csv -Path $outPath -NoTypeInformation -Encoding UTF8
Write-Host "=== Fim. Abre $outPath no Excel. ==="

#Stop-Transcript
