# Copyright (c) 2026 Chavatte Security
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.

# Security Revision: Auto-Elevation, SHA256 Integrity Check, Interactive Guide & i18n

param(
    [switch]$NoGUI,
    [switch]$Silent,
    [switch]$Uninstall,
    [string]$InstallPath,
    [switch]$InteractiveGuide
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$localeScript = Join-Path $scriptPath "Scripts\PowerShell\Get-Locale.ps1"
if (Test-Path $localeScript) {
    . $localeScript
    $L = Get-Locale
}
else {
    $L = @{ "Main_NoAdmin" = "⚠️ Admin priv. not detected."; "Main_ReqUAC" = "🔄 Requesting UAC..."; "Main_UACError" = "🛑 ERROR: UAC cancelled." }
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host $L["Main_NoAdmin"] -ForegroundColor Yellow
    Write-Host $L["Main_ReqUAC"] -ForegroundColor Cyan
    
    $psExe = if ($PSVersionTable.PSVersion.Major -ge 6) { "pwsh.exe" } else { "powershell.exe" }
    
    $myArgs = @()
    if ($NoGUI) { $myArgs += "-NoGUI" }
    if ($Silent) { $myArgs += "-Silent" }
    if ($Uninstall) { $myArgs += "-Uninstall" }
    if ($InteractiveGuide) { $myArgs += "-InteractiveGuide" }
    if (-not [string]::IsNullOrWhiteSpace($InstallPath)) { $myArgs += "-InstallPath", "`"$InstallPath`"" }

    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"") + $myArgs

    try { Start-Process $psExe -Verb RunAs -ArgumentList $argList; exit 0 }
    catch { Write-Host $L["Main_UACError"] -ForegroundColor Red; exit 1 }
}

$ErrorActionPreference = "Stop"
$functionsPath = Join-Path $scriptPath "Scripts" "PowerShell"
$rootFSPath = Join-Path $scriptPath "Data" "rootfs" "install.tar.gz"
$logoFilePath = Join-Path $scriptPath "Assets" "logo.txt"
$downloadUrl = "https://github.com/chavatte/ParrotOS-WSL-Installer/releases/download/v1.0.0/install.tar.gz" 
$expectedHash = "sha256:867b18097e00d0f015195fd34610d72bdfdd4cc6887dbf926a5d4f7c5cbb69b5"

function Show-InteractiveGuide {
    Write-Host $L["Main_WelcomeTitle"] -ForegroundColor Cyan
    Write-Host $L["Main_WelcomeDesc"] -ForegroundColor White
    Write-Host $L["Main_WelcomePhases"] -ForegroundColor DarkGray
    Write-Host $L["Main_Phase1"] -ForegroundColor White
    Write-Host $L["Main_Phase2"] -ForegroundColor White
    Write-Host $L["Main_Phase3"] -ForegroundColor White
    Write-Host $L["Main_Phase4"] -ForegroundColor White
    Write-Host $L["Main_PreReqWarn"] -ForegroundColor Yellow
    Pause
}

Get-ChildItem -Path $functionsPath -Filter "*.ps1" | Where-Object { $_.Name -ne "Get-Locale.ps1" } | ForEach-Object {
    try { . $_.FullName }
    catch { Write-Host "$($L["Main_ModLoadErr"]) $($_.Name): $_" -ForegroundColor Red; exit 1 }
}

Show-Logo -LogoFilePath $logoFilePath

if (-not $Silent -and -not $Uninstall) {
    $startGuide = Read-Host $L["Main_PromptGuide"]
    if ($startGuide -match '^[sSyY]') { Show-InteractiveGuide }
}

try {
    if ($Uninstall) {
        Write-Host $L["Main_UninstallMode"] -ForegroundColor Cyan
        $uninstallArgs = @("-DistroName", "ParrotOS")
        if (-not [string]::IsNullOrWhiteSpace($InstallPath)) { $uninstallArgs += @("-InstallPath", $InstallPath) }
        & "$PSScriptRoot\Uninstall.ps1" @uninstallArgs
        exit 0
    }

    Write-Host $L["Main_InstallStart"] -ForegroundColor Cyan
    
    $rootFSDir = Split-Path -Path $rootFSPath -Parent
    if (-not (Test-Path -Path $rootFSDir)) { New-Item -ItemType Directory -Path $rootFSDir -Force | Out-Null }

    if (-not (Test-Path -Path $rootFSPath -PathType Leaf)) {
        try {
            Write-Host $L["Main_RootfsNotFound"] -ForegroundColor Yellow
            Write-Host "$($L["Main_DownloadStart"]) '$downloadUrl'..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $downloadUrl -OutFile $rootFSPath -UseBasicParsing
            Write-Host $L["Main_DownloadSucc"] -ForegroundColor Green
        }
        catch { Write-Host $L["Main_DownloadFail"] -ForegroundColor Red; exit 1 }
    }

    Write-Host $L["Main_HashAudit"] -ForegroundColor Yellow
    
    if (-not [string]::IsNullOrWhiteSpace($expectedHash) -and $expectedHash -notmatch "INSERIR_O_HASH") {
        $cleanExpectedHash = $expectedHash -replace "(?i)^sha256:\s*", ""
        $cleanExpectedHash = $cleanExpectedHash.Trim().ToUpper()
        $fileHash = (Get-FileHash -Path $rootFSPath -Algorithm SHA256).Hash.ToUpper()
        
        if ($fileHash -ne $cleanExpectedHash) {
            Write-Host $L["Main_HashFail"] -ForegroundColor Red
            Write-Host "$($L["Main_HashExpected"]) $cleanExpectedHash" -ForegroundColor Red
            Write-Host "$($L["Main_HashObtained"]) $fileHash" -ForegroundColor Red
            Write-Host $L["Main_HashAbort"] -ForegroundColor Red
            Remove-Item -Path $rootFSPath -Force
            exit 1
        }
        Write-Host $L["Main_HashSuccess"] -ForegroundColor Green
    }
    else { Write-Host $L["Main_HashSkipped"] -ForegroundColor DarkGray }

    Enable-WSL2

    $chosenInstallPath = ""
    $defaultPath = "$env:SystemDrive\WSL_Distros\ParrotOS"

    if (-not [string]::IsNullOrWhiteSpace($InstallPath)) {
        $chosenInstallPath = $InstallPath
        Write-Host "$($L["Main_CustomPath"]) $chosenInstallPath" -ForegroundColor Cyan
    }
    elseif ($Silent) { $chosenInstallPath = $defaultPath }
    else {
        Write-Host $L["Main_LocTitle"] -ForegroundColor Cyan
        $promptStr = $L["Main_LocDefault"] -f $defaultPath
        $choice = Read-Host $promptStr
        if ($choice -match '^[nN]') {
            while ([string]::IsNullOrWhiteSpace($chosenInstallPath)) {
                $chosenInstallPath = Read-Host $L["Main_LocCustom"]
            }
        }
        else { $chosenInstallPath = $defaultPath }
    }
    
    Install-ParrotWSL -RootFSPath $rootFSPath -InstallPath $chosenInstallPath
    
    if ($Silent) { Install-ParrotTools }
    else {
        $installTools = Read-Host $L["Main_PromptTools"]
        if ($installTools -match '^[sSyY]') { Install-ParrotTools }
    }

    if (-not $NoGUI) {
        if ($Silent) { Set-ParrotGUI }
        else {
            $installGUI = Read-Host $L["Main_PromptGUI"]
            if ($installGUI -match '^[sSyY]') {
                Set-ParrotGUI
                $installConnectChoice = Read-Host $L["Main_PromptConnM"]
                if ($installConnectChoice -match '^[sSyY]') {
                    Install-PSModule -FunctionName "Connect-ParrotGUI" -SourceScriptPath (Join-Path $functionsPath "Connect-ParrotGUI.ps1")
                }
                $installUninstallChoice = Read-Host $L["Main_PromptUninM"]
                if ($installUninstallChoice -match '^[sSyY]') {
                    Install-PSModule -FunctionName "Uninstall-ParrotWSL" -SourceScriptPath (Join-Path $functionsPath "Uninstall-ParrotWSL.ps1")
                }
                $connectNow = Read-Host $L["Main_PromptConnN"]
                if ($connectNow -match '^[sSyY]') { Connect-ParrotGUI }
            }
        }
    }
    
    Write-Host $L["Main_DeploySucc"] -ForegroundColor Green
    Write-Host $L["Main_CliTerm"] -ForegroundColor White
    Write-Host "     wsl -d ParrotOS" -ForegroundColor Yellow
    Write-Host $L["Main_GuiEnv"] -ForegroundColor White
    Write-Host "     Connect-ParrotGUI" -ForegroundColor Yellow
}
catch {
    Write-Host "$($L["Main_CritExcept"]) $_" -ForegroundColor Red
    exit 1
}