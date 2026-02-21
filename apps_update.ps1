##Start-Transcript -Path "$PSScriptRoot\app_update_debug_transcript.txt" -Force
Write-Host "=== Início do processo (CSV + scraping com fallback Chocolatey→GitHub→Website) ===" -ForegroundColor Green

$csvPath = $PSScriptRoot + '\data\apps.csv'

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
$jsonPath = $PSScriptRoot + '\data\appSources.json'
if (Test-Path $jsonPath) {
    Write-Host "[JSON] Carregando appSources.json..."
    $AppSources = Get-Content -Path $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json | ConvertTo-Hashtable
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

# ---------------------- RuckZuck API --------------------------------------------
$global:RuckZuckCatalog = $null
$global:RuckZuckApiUrl = "https://ruckzuck.tools"

function Initialize-RuckZuck {
    Write-Host "[RuckZuck] Inicializando catálogo..." -ForegroundColor Cyan
    try {
        $apiUrl = Invoke-RestMethod -Uri "https://ruckzuck.tools/rest/v2/geturl" -ErrorAction Stop
        $global:RuckZuckApiUrl = $apiUrl
        $global:RuckZuckCatalog = Invoke-RestMethod -Uri "$apiUrl/rest/v2/getcatalog" -ErrorAction Stop
        Write-Host "[RuckZuck] Catálogo carregado: $($global:RuckZuckCatalog.Count) itens." -ForegroundColor Green
    }
    catch {
        Write-Warning "[RuckZuck] Falha ao carregar catálogo: $_"
    }
}

function Get-RuckZuckInfo {
    param([string]$RawName)

    if (-not $global:RuckZuckCatalog) { return $null }

    # Limpeza básica do nome local
    $cleanName = $RawName -replace " \d+.*","" -replace " \(.*",""
    
    # Busca por ShortName (exato), ProductName (contains), ou ShortName (contains)
    $candidates = $global:RuckZuckCatalog | Where-Object { 
        $_.ShortName -eq $cleanName -or 
        $_.ProductName -like "*$cleanName*" -or
        $cleanName -like "*$($_.ShortName)*"
    }

    if ($candidates) {
        # Preferência 1: ShortName exato (match mais preciso)
        $byShortName = $candidates | Where-Object { $_.ShortName -eq $cleanName }
        if ($byShortName) {
            # Se múltiplos matches, pegar versão mais recente (por ProductVersion)
            $found = $byShortName | Sort-Object -Property @{Expression={[version]$_.ProductVersion -replace '[^0-9.]', ''}; Descending=$true} | Select-Object -First 1
        } else {
            # Fallback: ordenar por Downloads
            $found = $candidates | Sort-Object Downloads -Descending | Select-Object -First 1
        }
        
        Write-Host "   [RuckZuck] ✓ Encontrado: $($found.ProductName) ($($found.ProductVersion))"
        
        return [PSCustomObject]@{
            Version = $found.ProductVersion
            Website = $found.ProductURL
            IsDiscontinued = $false
            SourceId = $found.ShortName
            IconUrl = "$global:RuckZuckApiUrl/rest/v2/geticon?shortname=$($found.ShortName)"
        }
    }
    return $null
}

# Inicializar RuckZuck
Initialize-RuckZuck

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
        if ($normApp -eq 'android studio') {
            if ($Version -match '(\d{4}\.\d+\.\d+)') {
                $base = $Matches[1]
                if ($Version -match '(?i)patch\s*(\d+)') {
                    return "$base.$($Matches[1])"
                }
                return $base
            }
            if ($Version -match '(\d+\.\d+\.\d+)') {
                $base = $Matches[1]
                if ($Version -match '(?i)patch\s*(\d+)') {
                    return "$base.$($Matches[1])"
                }
                return $base
            }
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


    # Tratamento para versões de 4 partes com final .00.0 ou .0.0 (ex: 25.01.00.0 -> 25.01)
    if ($Version -match '^(?<maj>\d+)\.(?<min>\d+)\.0+\.0+$') {
        return "$($Matches['maj']).$($Matches['min'])"
    }

    # Normalização específica para 7-Zip: somente para este app
    if ($AppName) {
        $normAppForSevenZip = Get-NormalizedAppName -RawName $AppName
        if ($normAppForSevenZip -in @('7-zip','7zip')) {
            if ($Version -match '^(?<maj>\d+)\.(?<min>\d+)\.(?<patch>\d+)$') {
                $maj   = [int]$Matches['maj']
                $min   = [int]$Matches['min']
                $patch = [int]$Matches['patch']
                if ($patch -eq 0) {
                    $minPadded = '{0:D2}' -f $min
                    return "$maj.$minPadded"
                }
                return "$maj.$min.$patch"
            }
        }
    }

    # Para outras apps, se já está em x.y.z, manter como está
    if ($Version -match '^\d+\.\d+\.\d+$') {
        return $Version
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

    if (-not $Latest) { return 'Unknown' }
    if (-not $Installed) {
        $Installed = '0.0.0'
    }

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
        try {
            $cmp = Compare-Version -A $Installed -B $Latest
            if ($cmp -lt 0) { return 'UpdateAvailable' }
            return 'UpToDate'
        }
        catch {
            return 'Unknown'
        }
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
        $html = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop -Headers @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' }
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

    # Extrair TODAS as versões (não apenas a primeira)
    $allMatches = [regex]::Matches($content, $VersionPattern)
    
    if ($allMatches.Count -gt 0) {
        # Coletar todas as versões encontradas
        $versions = @()
        foreach ($match in $allMatches) {
            $versions += $match.Groups[1].Value
        }
        
        # Se múltiplas versões, pegar a máxima
        if ($versions.Count -gt 1) {
            try {
                $maxVersion = $versions | Sort-Object { [Version]$_ } -Descending | Select-Object -First 1
                Write-Host " [Web] ✓ Versão encontrada (máx de $($versions.Count)): $maxVersion"
            }
            catch {
                # Se falhar conversão para Version, usar ordem alfabética
                $maxVersion = $versions | Sort-Object -Descending | Select-Object -First 1
                Write-Host " [Web] ✓ Versão encontrada (máx string de $($versions.Count)): $maxVersion"
            }
        }
        else {
            $maxVersion = $versions[0]
            Write-Host " [Web] ✓ Versão encontrada: $maxVersion"
        }
        
        return [PSCustomObject]@{
            Version = $maxVersion
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
    $empty = [PSCustomObject]@{ Version=$null; Website=$null; IsDiscontinued=$false; SourceId=$null; IconUrl=$null }

    if (-not $normalized) { return $empty }

    # Função local para padronizar retorno
    function Standardize-Result($res) {
        if ($res) {
            if (-not $res.PSObject.Properties['SourceId']) {
                $res | Add-Member -NotePropertyName SourceId -NotePropertyValue $null -Force
            }
            if (-not $res.PSObject.Properties['IconUrl']) {
                $res | Add-Member -NotePropertyName IconUrl -NotePropertyValue $null -Force
            }
            return $res
        }
        return $null
    }

    # PRIORIDADE: Verificar appSources.json PRIMEIRO
    if ($AppSources.ContainsKey($normalized)) {
        Write-Host "  [*] A resolver app: '$RawName' (normalizado: '$normalized')"
        $src = $AppSources[$normalized]

        # 1) Chocolate ID
        if ($src.ChocolateyId) {
            Write-Host "   [Fallback 1] Tentando Chocolatey..."
            $result = Get-ChocolateyLatestVersion -PackageId $src.ChocolateyId -OutputUrl $src.OutputUrl
            if ($result.Version) { return (Standardize-Result $result) }
        }

        # 2) Type GitHub
        if ($src.Type -eq 'GitHub') {
            Write-Host "   [Fallback 2] Tentando GitHub..."
            
            if ($src.ApiUrl) {
                $result = Get-GitHubLatestVersionAPI -ApiUrl $src.ApiUrl -OutputUrl $src.OutputUrl
                if ($result.Version) { return (Standardize-Result $result) }
            }

            if ($src.RepoUrl) {
                $result = Get-GitHubLatestVersionHTML -RepoUrl $src.RepoUrl -OutputUrl $src.OutputUrl
                if ($result.Version) { return (Standardize-Result $result) }
            }
        }

        # 3) Type Website (scraping com regex)
        if ($src.Type -eq 'Website') {
            Write-Host "   [Fallback 3] Tentando Web scraping..."
            $result = Get-WebsiteLatestVersion `
                -Url $src.ScrapeUrl `
                -VersionPattern $src.VersionPattern `
                -OutputUrl $src.OutputUrl
            if ($result -and -not $result.Website -and $src.OutputUrl) { $result | Add-Member -NotePropertyName Website -NotePropertyValue $src.OutputUrl -Force }
            
            if ($result -and -not $result.Version -and $src.PSObject.Properties['AltScrapeUrl']) {
                Write-Host "   [Fallback 3b] Tentando fonte alternativa (docs/manual)..."
                $altPattern = $src.VersionPattern
                if ($src.PSObject.Properties['AltVersionPattern']) { $altPattern = $src.AltVersionPattern }
                $altOutput = $src.OutputUrl
                if ($src.PSObject.Properties['AltOutputUrl']) { $altOutput = $src.AltOutputUrl }
                $result2 = Get-WebsiteLatestVersion `
                    -Url $src.AltScrapeUrl `
                    -VersionPattern $altPattern `
                    -OutputUrl $altOutput
                if ($result2.Version) { return (Standardize-Result $result2) }
                if (-not $result2.Version -and $src.PSObject.Properties['AltVersionPattern2']) {
                    Write-Host "   [Fallback 3c] Tentando padrão alternativo de versão..."
                    $result3 = Get-WebsiteLatestVersion `
                        -Url $src.AltScrapeUrl `
                        -VersionPattern $src.AltVersionPattern2 `
                        -OutputUrl $altOutput
                    if ($result3.Version) { return (Standardize-Result $result3) }
                }
            }
            return (Standardize-Result $result)
        }

        # 4) Type Fixed
        if ($src.Type -eq 'Fixed') {
            Write-Host " [Fixed] Versão fixa: $($src.Version)"
            return (Standardize-Result @{ Version = $src.Version; Website = $src.OutputUrl; IsDiscontinued = $false })
        }

        # 5) Type RuckZuck
        if ($src.Type -eq 'RuckZuck') {
            Write-Host "   [RuckZuck] Procurando no catálogo..."
            $rz = Get-RuckZuckInfo -RawName $RawName
            if ($rz) { return $rz }
        }
    } else {
        Write-Host "  [*] A resolver app: '$RawName' (normalizado: '$normalized')"
        Write-Host "    - Não há configuração para '$normalized'."
    }

    # FALLBACK: Tentar RuckZuck como último recurso (se não encontrou em appSources.json)
    $rz = Get-RuckZuckInfo -RawName $RawName
    if ($rz) { return $rz }

    return $empty
}

function Get-NormalizedAppName {
    param([string]$RawName)

    if ([string]::IsNullOrWhiteSpace($RawName)) { return $null }

    $name = $RawName.ToLower().Trim()
    #$name = $name -replace '\s+v?\d+(\.\d+)*.*$',''  # Remove versões e sufixos

    
    # 1) remover padrão de data SCCM: "- MM-YYYY" ou "- DD-MM-YYYY"
    $name = $name -replace '\s*[-–—]\s*\d{1,2}[-/]\d{4}\s*$', ''

    # 2) remover versão (padrão semântico: 1.2.3 ou v1.2.3)
    $name = $name -replace '\s+v?\d+(\.\d+)*.*$',''

    # 3) remover separadores/resíduos no fim (hífen, en/em dash, dois-pontos, espaço)
    $name = $name -replace '\s*[-–—:]\s*$', ''

    # 4) trim final por garantia
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

    if ([string]::IsNullOrWhiteSpace($RawName)) { return 'Free' }

    $norm = Get-NormalizedAppName -RawName $RawName

    if ($existingLicenses -and $norm -and $existingLicenses.ContainsKey($norm)) {
        return $existingLicenses[$norm]
    }

    return 'Free'
}

# ---------------------- Carregar Observações e Versões Anteriores ----------------------
# Lê o arquivo de saída anterior para preservar observações e comparar versões
$outPath = $PSScriptRoot + "\data\apps_output.csv"
$existingObs = @{}
$previousVersions = @{}
$existingIcons = @{}
$existingSourceIds = @{}
$existingTipoApp = @{}
$existingLicenses = @{}
$existingDeleted = @{}

if (Test-Path $outPath) {
    Write-Host "[Info] Carregando dados existentes de apps_output.csv..." -ForegroundColor Cyan
    try {
        $oldCsv = Import-Csv -Path $outPath
        foreach ($item in $oldCsv) {
            # Usa nome normalizado como chave para garantir match robusto
            $normName = Get-NormalizedAppName -RawName $item.AppName
            
            if ($normName) {
                # Preservar Observação
                if ($item.Observacao) {
                    $existingObs[$normName] = $item.Observacao
                }
                
                # Preservar Última Versão conhecida (para comparação de "Nova Versão")
                if ($item.LatestVersion) {
                    $previousVersions[$normName] = $item.LatestVersion
                }
                # Preservar Ícone/SourceId anteriores (para fallback robusto)
                if ($item.IconUrl) {
                    $existingIcons[$normName] = $item.IconUrl
                }
                if ($item.SourceId) {
                    $existingSourceIds[$normName] = $item.SourceId
                }
                if ($item.TipoApp) {
                    $existingTipoApp[$normName] = $item.TipoApp
                }
                if ($item.License) {
                    $existingLicenses[$normName] = $item.License
                }
                if ($item.IsDeleted) {
                    $existingDeleted[$normName] = $item.IsDeleted
                }
            }
        }
    } catch {
        Write-Host "[Aviso] Não foi possível ler dados antigos: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# 2) Processar linhas do CSV em memória
$index = 0
$totalApps = @($data).Count
$processedApps = @{} # Hashtable para rastrear apps duplicados
$uniqueData = @()    # Lista para armazenar apenas linhas únicas

# Fallbacks de favicon por marca (nomes normalizados)
$brandFavicons = @{
    'google chrome'                 = 'https://www.google.com/favicon.ico'
    'android studio'                = 'https://developer.android.com/favicon.ico'
    'autenticação.gov'              = 'https://www.autenticacao.gov.pt/favicon.ico'
    'cisco jabber'                  = 'https://www.cisco.com/favicon.ico'
    'cisco secure client'           = 'https://www.cisco.com/favicon.ico'
    'citrix workspace app'          = 'https://www.citrix.com/favicon.ico'
    'dbeaver'                       = 'https://dbeaver.io/favicon.ico'
    'dbvisualizer'                  = 'https://www.dbvis.com/favicon.ico'
    'ffmpeg'                        = 'https://ffmpeg.org/favicon.ico'
    'eclipse ide'                   = 'https://www.eclipse.org/favicon.ico'
    'freeplane'                     = 'https://www.freeplane.org/favicon.ico'
    'gimp'                          = 'https://www.gimp.org/favicon.ico'
    'git'                           = 'https://git-scm.com/favicon.ico'
    'git extensions'                = 'https://gitextensions.github.io/favicon.ico'
    'github desktop'                = 'https://github.com/favicon.ico'
    'webex'                         = 'https://www.webex.com/favicon.ico'
    'virtualbox'                    = 'https://www.virtualbox.org/favicon.ico'
    'oracle sql developer'          = 'https://www.oracle.com/favicon.ico'
    'terraform'                     = 'https://www.terraform.io/favicon.ico'
    'helm'                          = 'https://helm.sh/favicon.ico'
    'autodesk'                      = 'https://www.autodesk.com/favicon.ico'
    'jetbrains'                     = 'https://www.jetbrains.com/favicon.ico'
    'visual studio buildtools'      = 'https://visualstudio.microsoft.com/favicon.ico'
    'vmware'                        = 'https://www.vmware.com/favicon.ico'
    'winmerge'                      = 'https://winmerge.org/favicon.ico'
    'vysor'                         = 'https://www.vysor.io/favicon.ico'
    'tesseract ocr'                 = 'https://github.com/favicon.ico'
    'visual vm'                     = 'https://visualvm.github.io/favicon.ico'
    'appium inspector'              = 'https://raw.githubusercontent.com/appium/appium-inspector/main/app/common/renderer/assets/images/icon.png'
    'apache cxf'                    = 'https://cxf.apache.org/favicon.ico'
    'bloomberg terminal'            = 'https://www.bloomberg.com/favicon.ico'
    'blue prism'                    = 'https://www.blueprism.com/favicon.ico'
    'bravo for power bi'            = 'https://www.sqlbi.com/favicon.ico'
}

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

    $normKey = $normalizedCheck

    $tipoApp = 'app comercial'
    if ($normKey -and $existingTipoApp.ContainsKey($normKey)) {
        $tipoApp = $existingTipoApp[$normKey]
    }
    $isDeleted = $false
    if ($normKey -and $existingDeleted.ContainsKey($normKey)) {
        $isDeleted = $existingDeleted[$normKey]
    }
    if ($tipoApp -eq 'app interno') {
        $isDeleted = $true
    }

    Write-Host "[$index/$totalApps] AppName: '$appName' (Tipo: $tipoApp)" -ForegroundColor Cyan

    if ($tipoApp -eq 'app interno') {
        Write-Host "    [Info] App marcado como interno – pulando scraping online." -ForegroundColor Yellow
        $info = [PSCustomObject]@{ Version=$null; Website=$null; IsDiscontinued=$false; SourceId=$null; IconUrl=$null }
    }
    else {
        try {
            $info = Resolve-AppInfoOnline -RawName $appName
        }
        catch {
            Write-Host "    ✗ ERRO CRÍTICO ao resolver '$appName': $($_.Exception.Message)" -ForegroundColor Red
            $info = [PSCustomObject]@{ Version=$null; Website=$null; IsDiscontinued=$false; SourceId=$null; IconUrl=$null }
        }
    }

    foreach ($col in 'LatestVersion','Website','InstalledVersion','Status','License','SourceKey','SearchUrl','Observacao','IsNewVersion','SourceId','IconUrl','TipoApp','IsDeleted') {
        if (-not ($row.PSObject.Properties.Name -contains $col)) {
            $row | Add-Member -NotePropertyName $col -NotePropertyValue $null
        }
    }

    # obter chave e url de busca do JSON

    # Tentar recuperar observação existente se não houver na linha atual (ou sobrescrever, dependendo da lógica desejada)
    # Aqui, assumimos que o CSV antigo é a fonte da verdade para Observacao
    if ($normKey -and $existingObs.ContainsKey($normKey)) {
        $row.Observacao = $existingObs[$normKey]
    }
    
    # Lógica de Detecção de NOVA Versão (Comparar com execução anterior)
    $row.IsNewVersion = $false
    if ($normKey -and $previousVersions.ContainsKey($normKey) -and $info.Version) {
        $prevVer = $previousVersions[$normKey]
        $currVer = $info.Version
        
        # Só marcar como novo se for diferente E se não for a primeira execução (prevVer existe)
        if ($prevVer -and $prevVer -ne $currVer) {
            Write-Host "    ★ NOVA VERSÃO DETECTADA! (Era: $prevVer, Agora: $currVer)" -ForegroundColor Magenta
            $row.IsNewVersion = $true
        }
    }

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
    if ($normKey -eq 'blue prism') {
        $normalizedLatestVersion = $info.Version
    } else {
        $normalizedLatestVersion = Normalize-Version $info.Version $row.AppName
    }

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
    $finalSourceId = $info.SourceId
    if (-not $finalSourceId -and $normKey -and $existingSourceIds.ContainsKey($normKey)) {
        $finalSourceId = $existingSourceIds[$normKey]
    }
    $finalIconUrl = $info.IconUrl
    if (-not $finalIconUrl -and $normKey -and $existingIcons.ContainsKey($normKey)) {
        $finalIconUrl = $existingIcons[$normKey]
    }
    if (-not $finalIconUrl -and $info.Website) {
        try {
            $host = ([uri]$info.Website).Host
            if ($host) { $finalIconUrl = "https://www.google.com/s2/favicons?domain=$host&sz=64" }
        } catch {}
    }
    if (-not $finalIconUrl -and $row.SearchUrl) {
        try {
            $host = ([uri]$row.SearchUrl).Host
            if ($host) { $finalIconUrl = "https://www.google.com/s2/favicons?domain=$host&sz=64" }
        } catch {}
    }
    if (-not $finalIconUrl -and $normKey -and $brandFavicons.ContainsKey($normKey)) {
        $finalIconUrl = $brandFavicons[$normKey]
    }
    if (-not $finalIconUrl -and $normKey -in @('adobe acrobat reader','adobe acrobat reader update')) {
        $finalIconUrl = 'https://www.adobe.com/favicon.ico'
    }
    $row.SourceId         = $finalSourceId
    $row.IconUrl          = $finalIconUrl
    $row.TipoApp          = $tipoApp
    $row.IsDeleted        = $isDeleted
    # IsNewVersion já foi definido acima

    # Adicionar à lista de dados únicos
    $uniqueData += $row
}

# 3) Gravar CSV de saída
$outPath =  $PSScriptRoot + "\data\apps_output.csv"
Write-Host "A gravar CSV em: $outPath"
$uniqueData | Export-Csv -Path $outPath -NoTypeInformation -Encoding UTF8

# 4) Gravar metadados (timestamp)
$metaPath = $PSScriptRoot + "\data\metadata.json"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$metaContent = @{
    lastRun = $timestamp
} | ConvertTo-Json
Set-Content -Path $metaPath -Value $metaContent
Write-Host "[Metadata] Atualizado em: $timestamp"

Write-Host "=== Fim. Abre $outPath no Excel. ==="

#Stop-Transcript
