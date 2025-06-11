# Copyright (c) 2025 João Carlos Chavatte (DEV Chavatte)
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.

param(
    [switch]$NoGUI,
    [switch]$Silent,
    [switch]$Uninstall,
    [string]$InstallPath
)

$ErrorActionPreference = "Stop"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$functionsPath = Join-Path $scriptPath "Scripts" "PowerShell"
$rootFSPath = Join-Path $scriptPath "Data" "rootfs" "install.tar.gz"
$logoFilePath = Join-Path $scriptPath "Assets" "logo.txt"
$downloadUrl = "https://github.com/chavatte/ParrotOS-WSL-Installer/releases/download/v1.0.0/install.tar.gz" 

$rootFSDir = Split-Path -Path $rootFSPath -Parent
if (-not (Test-Path -Path $rootFSDir)) {
    New-Item -ItemType Directory -Path $rootFSDir -Force | Out-Null
}

if (-not (Test-Path -Path $rootFSPath -PathType Leaf)) {
    try {
        Write-Host "`n⏳ O arquivo 'rootfs' não foi encontrado." -ForegroundColor Yellow
        Write-Host "   Iniciando o download de '$downloadUrl'..." -ForegroundColor Yellow
        Write-Host "   (Isso pode levar alguns minutos dependendo da sua conexão)..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $downloadUrl -OutFile $rootFSPath -UseBasicParsing
        Write-Host "✅ Download do 'rootfs' concluído com sucesso." -ForegroundColor Green
    }
    catch {
        Write-Host "🛑 ERRO FATAL: Falha ao baixar o arquivo rootfs. Verifique sua conexão com a internet e a URL." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}

Get-ChildItem -Path $functionsPath -Filter "*.ps1" | ForEach-Object {
    try {
        . $_.FullName
        Write-Verbose "Carregada função: $($_.Name)"
    }
    catch {
        Write-Host "ERRO: Falha ao carregar $($_.Name): $_" -ForegroundColor Red
        exit 1
    }
}

Show-Logo -LogoFilePath $logoFilePath

try {
    if ($Uninstall) {
        Write-Host "`n=== MODO DE DESINSTALAÇÃO ===" -ForegroundColor Cyan
        $uninstallArgs = @("-DistroName", "ParrotOS")
        if (-not [string]::IsNullOrWhiteSpace($InstallPath)) {
            $uninstallArgs += @("-InstallPath", $InstallPath)
        }
        & "$PSScriptRoot\Uninstall.ps1" @uninstallArgs
        exit 0
    }

    Write-Host "`n=== INÍCIO DA INSTALAÇÃO ===" -ForegroundColor Cyan
    
    Enable-WSL2

    $chosenInstallPath = ""
    $defaultPath = "$env:SystemDrive\WSL_Distros\ParrotOS"

    if (-not [string]::IsNullOrWhiteSpace($InstallPath)) {
        $chosenInstallPath = $InstallPath
        Write-Host "ℹ️  Caminho de instalação personalizado fornecido via parâmetro: $chosenInstallPath" -ForegroundColor Cyan
    }
    elseif ($Silent) {
        $chosenInstallPath = $defaultPath
    }
    else {
        Write-Host "`n--- Local de Instalação ---" -ForegroundColor Cyan
        $choice = Read-Host "❓ O local de instalação padrão é '$defaultPath'. Deseja usar este local? [S/N]"
        if ($choice.ToUpper() -eq 'N') {
            while ([string]::IsNullOrWhiteSpace($chosenInstallPath)) {
                $chosenInstallPath = Read-Host "  -> Digite o caminho completo para a nova pasta de instalação"
                if ([string]::IsNullOrWhiteSpace($chosenInstallPath)) {
                    Write-Host "🛑 O caminho não pode ser vazio. Por favor, tente novamente." -ForegroundColor Red
                }
            }
        }
        else {
            $chosenInstallPath = $defaultPath
        }
    }
    Write-Host "✅ O Parrot OS será instalado em: '$chosenInstallPath'" -ForegroundColor Green

    Install-ParrotWSL -RootFSPath $rootFSPath -InstallPath $chosenInstallPath
    
    if (-not $NoGUI) {
        if ($Silent) {
            Set-ParrotGUI
        }
        else {
            $installGUI = Read-Host "Deseja instalar o ambiente gráfico (GUI)? [S/N]"
            if ($installGUI -match '^[sS]') {
                Set-ParrotGUI

                if (-not $Silent) {
                    $installConnectChoice = Read-Host "❓ Deseja instalar o comando 'Connect-ParrotGUI' para acesso rápido? [S/N]"
                    if ($installConnectChoice -match '^[sS]') {
                        Install-PSModule -FunctionName "Connect-ParrotGUI" -SourceScriptPath (Join-Path $functionsPath "Connect-ParrotGUI.ps1")
                    }

                    $installUninstallChoice = Read-Host "❓ Deseja instalar o comando 'Uninstall-ParrotWSL' para facilitar a remoção no futuro? [S/N]"
                    if ($installUninstallChoice -match '^[sS]') {
                        Install-PSModule -FunctionName "Uninstall-ParrotWSL" -SourceScriptPath (Join-Path $functionsPath "Uninstall-ParrotWSL.ps1")
                    }
                }
                
                if (-not $Silent) {
                    $connectNow = Read-Host "Deseja conectar agora ao ambiente gráfico? [S/N]"
                    if ($connectNow -match '^[sS]') {
                        Connect-ParrotGUI
                    }
                }
            }
        }
    }
    
    Write-Host "`n🎉 INSTALAÇÃO COMPLETADA COM SUCESSO! 🎉" -ForegroundColor Green
    Write-Host "   Os arquivos da sua distribuição foram instalados em: '$chosenInstallPath'" -ForegroundColor DarkGray
    Write-Host "`n--- Comandos Úteis ---" -ForegroundColor Cyan
    Write-Host "  -> Para iniciar o terminal padrão do Parrot OS:" -ForegroundColor White
    Write-Host "     wsl -d $DistroName" -ForegroundColor Yellow
    Write-Host "`n  -> Para entrar diretamente como o usuário 'root':" -ForegroundColor White
    Write-Host "     wsl -d $DistroName -u root" -ForegroundColor Yellow

    if ((-not $NoGUI) -and (Get-Command Connect-ParrotGUI -ErrorAction SilentlyContinue)) {
        Write-Host "`n  -> Para conectar ao Ambiente Gráfico (GUI):" -ForegroundColor White
        Write-Host "     Connect-ParrotGUI" -ForegroundColor Yellow
        Write-Host "     # Para ver todos os parâmetros e exemplos, use a ajuda:" -ForegroundColor DarkGray
        Write-Host "     Get-Help Connect-ParrotGUI -Full" -ForegroundColor DarkGray
    }

    Write-Host "`n  -> Para desinstalar:" -ForegroundColor White
    if (Get-Command Uninstall-ParrotWSL -ErrorAction SilentlyContinue) {
        Write-Host "     # Como o módulo foi instalado, você pode usar este comando de qualquer lugar:" -ForegroundColor DarkGray
        Write-Host "     Uninstall-ParrotWSL" -ForegroundColor Yellow
        Write-Host "     # Se usou um caminho personalizado, não se esqueça de especificá-lo:" -ForegroundColor DarkGray
        Write-Host "     Uninstall-ParrotWSL -InstallPath '$chosenInstallPath'" -ForegroundColor DarkGray
    }
    else {
        Write-Host "     # Como o módulo não foi instalado, execute o script a partir da raiz do projeto:" -ForegroundColor DarkGray
        Write-Host "     .\Main.ps1 -Uninstall" -ForegroundColor Yellow
        Write-Host "     # Se usou um caminho personalizado, adicione o parâmetro:" -ForegroundColor DarkGray
        Write-Host "     .\Main.ps1 -Uninstall -InstallPath '$chosenInstallPath'" -ForegroundColor DarkGray
    }
    
}
catch {
    Write-Host "`nERRO NA INSTALAÇÃO: $_" -ForegroundColor Red
    exit 1
}