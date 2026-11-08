# scripts/update-apps.ps1
[CmdletBinding()]
param (
    [ValidateSet('Download', 'Install', 'Check')]
    [string]$Mode = 'Download',

    [string]$AppId = 'All',

    [switch]$Force = $false,

    [string]$ApkDir = '',

    [switch]$SkipAdbPrompt = $false
)

Set-StrictMode -Off
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
if ([System.Enum]::IsDefined([System.Net.SecurityProtocolType], 'Tls13')) {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls13
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WorkspaceRoot = Split-Path -Parent $ScriptDir
$TargetApkDir = if ($ApkDir) { $ApkDir } else { Join-Path $WorkspaceRoot 'apk' }
$ManifestPath = Join-Path $TargetApkDir '.manifest.cache.json'
$RegistryPath = Join-Path $ScriptDir 'modules\AppRegistry.psd1'

if (-not (Test-Path -Path $TargetApkDir)) {
    New-Item -ItemType Directory -Path $TargetApkDir -Force | Out-Null
}

function Get-RegistryConfig {
    if (Test-Path -Path $RegistryPath) {
        return Import-PowerShellDataFile -Path $RegistryPath
    }

    return @{
        Apps = @(
            @{
                Id          = 'BBLL'
                Name        = 'BlBl (BBLL)'
                Type        = 'github'
                Repo        = 'xiaye13579/BBLL'
                AssetFilter = '.*release.*\.apk$'
                Exclude     = '.*debug.*'
                TargetFile  = 'BBLL-latest.apk'
                Description = '哔哩哔哩 TV/Pad 开源第三方客户端'
            },
            @{
                Id          = 'TizenTube'
                Name        = 'TizenTube / SmartTube'
                Type        = 'github'
                Repo        = 'yuliskov/SmartTube'
                FallbackRepo= 'reisxd/TizenTubeCobalt'
                AssetFilter = '.*(arm|release|Cobalt|stable).*\.apk$'
                Exclude     = '.*(x86|beta).*'
                TargetFile  = 'TizenTube-latest.apk'
                Description = 'YouTube TV 核心去广告客户端'
            },
            @{
                Id          = 'TVBox'
                Name        = 'TVBox (FongMi)'
                Type        = 'github'
                Repo        = 'FongMi/Release'
                FallbackRepo= 'q215613905/TVBoxOS'
                AssetFilter = '.*(leanback|java).*\.apk$'
                Exclude     = '.*mobile.*'
                TargetFile  = 'TVBox-latest.apk'
                Description = '开源聚合点播/直播播放器'
            },
            @{
                Id          = 'mytv'
                Name        = 'mytv-android'
                Type        = 'github'
                Repo        = 'mytv-android/mytv-android'
                AssetFilter = '.*release.*\.apk$'
                Exclude     = '.*debug.*'
                TargetFile  = 'mytv-latest.apk'
                Description = '极简电视直播 IPTV 客户端'
            },
            @{
                Id          = 'EmotnLauncher'
                Name        = 'Emotn Launcher'
                Type        = 'direct'
                Url         = 'https://app.emotn.com/download/app'
                FallbackUrls= @(
                    'https://cdn.emotn.com/apk/EmotnUI.apk'
                )
                TargetFile  = 'EmotnLauncher-latest.apk'
                Description = '长辈友好型纯净电视桌面'
            }
        )
        Mirrors = @(
            'https://ghproxy.net/',
            'https://mirror.ghproxy.com/',
            'https://kkgithub.com/'
        )
        MinApkSizeBytes = 5242880
    }
}

function Get-LocalManifest {
    if (Test-Path -Path $ManifestPath) {
        try {
            $raw = Get-Content -Path $ManifestPath -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                return ($raw | ConvertFrom-Json)
            }
        }
        catch {
            Write-Warning "读取本地缓存清单失败，将初始化新清单: $_"
        }
    }
    return [PSCustomObject]@{}
}

function Save-LocalManifest {
    param ([PSCustomObject]$Manifest)
    try {
        $json = $Manifest | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($ManifestPath, $json, [System.Text.Encoding]::UTF8)
    }
    catch {
        Write-Warning "持久化清单失败: $_"
    }
}

function Get-RemoteReleaseInfo {
    param (
        [hashtable]$App,
        [string[]]$Mirrors
    )

    $headers = @{
        'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AndroidTV-Updater'
        'Accept'     = 'application/vnd.github.v3+json'
    }

    if ($App.Type -eq 'direct') {
        return @{
            Tag         = 'static-latest'
            DownloadUrl = $App.Url
            FallbackUrls= $App.FallbackUrls
            FileName    = $App.TargetFile
            Direct      = $true
        }
    }

    $reposToTry = @($App.Repo)
    if ($App.FallbackRepo) {
        $reposToTry += $App.FallbackRepo
    }

    foreach ($repo in $reposToTry) {
        $apiUrls = @("https://api.github.com/repos/$repo/releases/latest")
        foreach ($mirror in $Mirrors) {
            if ($mirror -match 'ghproxy') {
                $apiUrls += "$($mirror)https://api.github.com/repos/$repo/releases/latest"
            }
        }

        foreach ($apiUrl in $apiUrls) {
            try {
                Write-Host "  [-] 正在探测版本: $apiUrl" -ForegroundColor Gray
                $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10 -ErrorAction Stop
                if ($response -and $response.tag_name -and $response.assets) {
                    $matchedAsset = $null

                    $apkAssets = @($response.assets) | Where-Object { $_.name -match '\.apk$' }

                    if ($App.AssetFilter) {
                        $filtered = $apkAssets | Where-Object { $_.name -match $App.AssetFilter }
                        if ($filtered) { $apkAssets = $filtered }
                    }

                    if ($App.Exclude) {
                        $apkAssets = @($apkAssets) | Where-Object { $_.name -notmatch $App.Exclude }
                    }

                    $matchedAsset = $apkAssets | Select-Object -First 1

                    if ($matchedAsset) {
                        return @{
                            Tag         = [string]$response.tag_name
                            DownloadUrl = [string]$matchedAsset.browser_download_url
                            FileName    = [string]$matchedAsset.name
                            Size        = [long]$matchedAsset.size
                            Direct      = $false
                        }
                    }
                }
            }
            catch {
                continue
            }
        }
    }

    return $null
}

function Build-DownloadUrlChain {
    param (
        [string]$PrimaryUrl,
        [string[]]$FallbackUrls,
        [string[]]$Mirrors
    )

    $urls = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($PrimaryUrl)) {
        $urls.Add($PrimaryUrl)
    }

    if ($PrimaryUrl -match 'github\.com') {
        foreach ($mirror in $Mirrors) {
            $trimmed = $mirror.TrimEnd('/')
            if ($mirror -match 'ghproxy') {
                $urls.Add("$trimmed/$PrimaryUrl")
            }
            elseif ($mirror -match 'kkgithub') {
                $urls.Add(($PrimaryUrl -replace 'https?://github\.com', 'https://kkgithub.com'))
            }
        }
    }

    if ($FallbackUrls) {
        foreach ($fb in $FallbackUrls) {
            if (-not [string]::IsNullOrWhiteSpace($fb)) {
                $urls.Add($fb)
            }
        }
    }

    return $urls.ToArray()
}

function Download-BinaryWithValidation {
    param (
        [string[]]$CandidateUrls,
        [string]$TempFilePath,
        [long]$MinSizeBytes = 5242880,
        [int]$MaxRetries = 3
    )

    $headers = @{
        'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AndroidTV-Updater'
    }

    foreach ($url in $CandidateUrls) {
        for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
            Write-Host "  [*] 尝试下载 (节点: $url, 重试: $attempt/$MaxRetries) ..." -ForegroundColor Cyan
            try {
                if (Test-Path -Path $TempFilePath) {
                    Remove-Item -Path $TempFilePath -Force -ErrorAction SilentlyContinue
                }

                Invoke-WebRequest -Uri $url -OutFile $TempFilePath -Headers $headers -TimeoutSec 35 -UseBasicParsing -ErrorAction Stop

                if (Test-Path -Path $TempFilePath) {
                    $item = Get-Item -Path $TempFilePath
                    if ($item.Length -ge $MinSizeBytes) {
                        Write-Host "  [+] 下载成功且通过体积门禁: $([math]::Round($item.Length / 1MB, 2)) MB" -ForegroundColor Green
                        return $true
                    }
                    else {
                        Write-Warning "  [!] 下载文件仅 $([math]::Round($item.Length / 1KB, 2)) KB，未达 5MB 门禁，判定为无效包。"
                        Remove-Item -Path $TempFilePath -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            catch {
                Write-Host "  [-] 节点连接异常: $($_.Exception.Message)" -ForegroundColor DarkGray
            }
        }
    }

    return $false
}

function Test-AdbDeviceReady {
    $adbCmd = Get-Command adb -ErrorAction SilentlyContinue
    if (-not $adbCmd) {
        Write-Warning "未检测到 adb 命令行工具，跳过推送安装。"
        return $false
    }

    try {
        $devicesOutput = & adb devices 2>&1
        $onlineDevices = @($devicesOutput) | Where-Object { $_ -match '\tdevice$' }
        if ($onlineDevices.Count -gt 0) {
            Write-Host "[ADB] 发现已连接并授权的电视设备: $($onlineDevices[0].Split("`t")[0])" -ForegroundColor Green
            return $true
        }
        else {
            Write-Warning "[ADB] 当前无已授权设备连接。请运行 scripts/tv-connect.bat 先行建立配对。"
            return $false
        }
    }
    catch {
        Write-Warning "[ADB] 探测执行失败: $_"
        return $false
    }
}

function Install-ApkToDevice {
    param (
        [string]$ApkFilePath
    )

    Write-Host "[ADB] 正在推送到电视并执行覆盖安装: $ApkFilePath" -ForegroundColor Yellow
    $installOutput = & adb install -r -d -g $ApkFilePath 2>&1
    $outputStr = ($installOutput -join "`n")
    if ($outputStr -match 'Success') {
        Write-Host "[ADB] 安装成功 (Success)！" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "[ADB] 安装返回: $outputStr" -ForegroundColor Red
        return $false
    }
}

$Registry = Get-RegistryConfig
$Manifest = Get-LocalManifest
$MinSize = if ($Registry.MinApkSizeBytes) { $Registry.MinApkSizeBytes } else { 5242880 }
$Mirrors = $Registry.Mirrors

$TargetApps = $Registry.Apps
if ($AppId -and $AppId -ne 'All') {
    $TargetApps = @($Registry.Apps) | Where-Object { $_.Id -eq $AppId }
    if ($TargetApps.Count -eq 0) {
        Write-Error "未找到指定 AppId: $AppId"
        exit 1
    }
}

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "        Android TV 核心应用更新与版本比对引擎" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "运行模式: $Mode | 强制重查: $Force | 纳管应用数: $($TargetApps.Count)"
Write-Host "落盘目录: $TargetApkDir"
Write-Host ""

$SummaryReport = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($app in $TargetApps) {
    Write-Host ">>> 正在处理应用: $($app.Name) [$($app.Id)]" -ForegroundColor White
    $appId = $app.Id
    $cached = $null
    if ($Manifest.PSObject.Properties[$appId]) {
        $cached = $Manifest.$appId
    }

    $finalLatestPath = Join-Path $TargetApkDir $app.TargetFile
    $remoteInfo = Get-RemoteReleaseInfo -App $app -Mirrors $Mirrors

    if (-not $remoteInfo) {
        Write-Host "  [!] 无法获取远程版本元数据 (网络受限或镜像均无响应)。" -ForegroundColor Red
        $localExists = (Test-Path -Path $finalLatestPath)
        $SummaryReport.Add([PSCustomObject]@{
            AppId   = $app.Id
            Name    = $app.Name
            Version = if ($cached -and $cached.Tag) { $cached.Tag } else { "未知" }
            Status  = if ($localExists) { "远程离线(保留本地)" } else { "探测失败" }
            File    = if ($localExists) { $app.TargetFile } else { "无" }
            SizeMB  = if ($localExists) { [math]::Round((Get-Item $finalLatestPath).Length / 1MB, 2) } else { 0 }
        })
        continue
    }

    $remoteTag = $remoteInfo.Tag
    Write-Host "  [*] 探测到最新版本: $remoteTag" -ForegroundColor Gray

    $isLocalUpToDate = $false
    if (-not $Force -and $cached -and $cached.Tag -eq $remoteTag -and (Test-Path -Path $finalLatestPath)) {
        $fileSize = (Get-Item $finalLatestPath).Length
        if ($fileSize -ge $MinSize) {
            $isLocalUpToDate = $true
        }
    }

    if ($Mode -eq 'Check') {
        $statusText = if ($isLocalUpToDate) { "已是最新" } else { "发现新版本 ($remoteTag)" }
        $SummaryReport.Add([PSCustomObject]@{
            AppId   = $app.Id
            Name    = $app.Name
            Version = $remoteTag
            Status  = $statusText
            File    = $app.TargetFile
            SizeMB  = if (Test-Path -Path $finalLatestPath) { [math]::Round((Get-Item $finalLatestPath).Length / 1MB, 2) } else { 0 }
        })
        continue
    }

    $downloadSuccess = $false
    if ($isLocalUpToDate) {
        Write-Host "  [=] 本地已为最新版本 ($remoteTag)，跳过下载。" -ForegroundColor Green
        $downloadSuccess = $true
    }
    else {
        $tempPath = Join-Path $TargetApkDir ".tmp_$($app.Id).apk"
        $urlChain = Build-DownloadUrlChain -PrimaryUrl $remoteInfo.DownloadUrl -FallbackUrls $remoteInfo.FallbackUrls -Mirrors $Mirrors

        $downloadSuccess = Download-BinaryWithValidation -CandidateUrls $urlChain -TempFilePath $tempPath -MinSizeBytes $MinSize

        if ($downloadSuccess) {
            $versionedFileName = "$($app.Id)-$remoteTag.apk" -replace '[:/\\]', '_'
            $versionedPath = Join-Path $TargetApkDir $versionedFileName

            Move-Item -Path $tempPath -Destination $versionedPath -Force
            Copy-Item -Path $versionedPath -Destination $finalLatestPath -Force

            $sha256 = (Get-FileHash -Path $finalLatestPath -Algorithm SHA256).Hash
            $fileLength = (Get-Item $finalLatestPath).Length

            $entry = [PSCustomObject]@{
                Id          = $app.Id
                Tag         = $remoteTag
                FileName    = $app.TargetFile
                VersionFile = $versionedFileName
                Size        = $fileLength
                Sha256      = $sha256
                UpdatedAt   = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            }

            if ($Manifest.PSObject.Properties[$appId]) {
                $Manifest.$appId = $entry
            }
            else {
                $Manifest | Add-Member -MemberType NoteProperty -Name $appId -Value $entry
            }
            Save-LocalManifest -Manifest $Manifest
        }
    }

    $installedStatus = "未部署"
    if ($Mode -eq 'Install' -and $downloadSuccess) {
        if (Test-Path -Path $finalLatestPath) {
            $adbReady = Test-AdbDeviceReady
            if ($adbReady) {
                $installOk = Install-ApkToDevice -ApkFilePath $finalLatestPath
                $installedStatus = if ($installOk) { "已覆盖安装" } else { "ADB安装失败" }
            }
            else {
                $installedStatus = "无就绪ADB"
            }
        }
    }

    $finalStatus = if (-not $downloadSuccess) {
        "下载失败"
    } elseif ($Mode -eq 'Install') {
        $installedStatus
    } elseif ($isLocalUpToDate) {
        "已是最新"
    } else {
        "更新完成"
    }

    $finalSizeMB = if (Test-Path -Path $finalLatestPath) {
        [math]::Round((Get-Item $finalLatestPath).Length / 1MB, 2)
    } else {
        0
    }

    $SummaryReport.Add([PSCustomObject]@{
        AppId   = $app.Id
        Name    = $app.Name
        Version = $remoteTag
        Status  = $finalStatus
        File    = $app.TargetFile
        SizeMB  = $finalSizeMB
    })

    Write-Host ""
}

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "                     更新执行汇总看板" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
$SummaryReport | Format-Table -AutoSize -Property Name, Version, Status, SizeMB, File

