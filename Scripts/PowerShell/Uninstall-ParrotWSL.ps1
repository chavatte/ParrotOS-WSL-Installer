# Copyright (c) 2025 João Carlos Chavatte (DEV Chavatte)
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.

<#
.SYNOPSIS
    Desinstala de forma completa a distribuição ParrotOS do WSL, incluindo pastas e módulos.

.DESCRIPTION
    Este comando realiza uma desinstalação completa e segura. Ele primeiro encerra a distribuição,
    depois remove seu registro do WSL, apaga a pasta de instalação do disco e, finalmente,
    remove os módulos PowerShell 'Connect-ParrotGUI' e 'Uninstall-ParrotWSL' do perfil do usuário.

.PARAMETER DistroName
    O nome da distribuição WSL a ser removida. Padrão: "ParrotOS".

.PARAMETER InstallPath
    O caminho completo para a pasta de instalação da distribuição que será apagada.
    É crucial que este caminho corresponda ao usado durante a instalação.

.PARAMETER Force
    Se especificado, pula a etapa de confirmação e executa a desinstalação diretamente.

.EXAMPLE
    PS C:\> Uninstall-ParrotWSL

    Inicia o processo de desinstalação interativo, pedindo confirmação antes de apagar.

.EXAMPLE
    PS C:\> Uninstall-ParrotWSL -InstallPath "D:\MinhasDistros\ParrotOS" -Force

    Remove imediatamente a distribuição instalada em "D:\MinhasDistros\ParrotOS" sem pedir confirmação.
#>
function Uninstall-ParrotWSL {
  [CmdletBinding()]
  param(
    [string]$DistroName = "ParrotOS",
    [string]$InstallPath = "$env:SystemDrive\WSL_Distros\ParrotOS",
    [switch]$Force
  )

  Write-Host "`n=== 🗑️  DESINSTALADOR DO PARROT OS PARA WSL === " -ForegroundColor Cyan

  Write-Host "ℹ️  Verificando itens para remoção..." -ForegroundColor Yellow
    
  $distroExists = $false
  if ((wsl --list --quiet) -contains $DistroName) {
    $distroExists = $true
    Write-Host "   [✓] Distribuição WSL encontrada: $DistroName" -ForegroundColor Green
  }
  else {
    Write-Host "   [✗] Distribuição WSL não encontrada: $DistroName" -ForegroundColor DarkGray
  }

  $dirExists = $false
  if (Test-Path -Path $InstallPath -PathType Container) {
    $dirExists = $true
    Write-Host "   [✓] Diretório de instalação encontrado: $InstallPath" -ForegroundColor Green
  }
  else {
    Write-Host "   [✗] Diretório de instalação não encontrado: $InstallPath" -ForegroundColor DarkGray
  }

  $connectModuleDir = $null
  $connectModuleExists = $false
  $uninstallModuleDir = $null
  $uninstallModuleExists = $false

  $userModulePath = ($env:PSModulePath -split ';') | Where-Object { $_ -like "*$($env:USERPROFILE)*" } | Select-Object -First 1
  if ($userModulePath) {
    $connectModuleDir = Join-Path -Path $userModulePath -ChildPath "Connect-ParrotGUI"
    if (Test-Path -Path $connectModuleDir) {
      $connectModuleExists = $true
      Write-Host "   [✓] Módulo PowerShell 'Connect-ParrotGUI' encontrado." -ForegroundColor Green
    }
    else {
      Write-Host "   [✗] Módulo PowerShell 'Connect-ParrotGUI' não encontrado." -ForegroundColor DarkGray
    }

    $uninstallModuleDir = Join-Path -Path $userModulePath -ChildPath "Uninstall-ParrotWSL"
    if (Test-Path -Path $uninstallModuleDir) {
      $uninstallModuleExists = $true
      Write-Host "   [✓] Módulo PowerShell 'Uninstall-ParrotWSL' encontrado." -ForegroundColor Green
    }
    else {
      Write-Host "   [✗] Módulo PowerShell 'Uninstall-ParrotWSL' não encontrado." -ForegroundColor DarkGray
    }
  }

  if (-not ($distroExists -or $dirExists -or $connectModuleExists -or $uninstallModuleExists)) {
    Write-Host "`n✅ Nada a fazer. A instalação do ParrotOS não foi encontrada no sistema." -ForegroundColor Green
    return
  }

  if (-not $Force) {
    Write-Host "`n⚠️  AVISO! Esta ação é destrutiva e removerá permanentemente os itens marcados com [✓] acima." -ForegroundColor Yellow
    $confirmation = Read-Host "❓ Você tem certeza que deseja continuar? Digite 'S' para confirmar"
    if ($confirmation.ToUpper() -ne 'S') {
      Write-Host "ℹ️  Desinstalação cancelada pelo usuário." -ForegroundColor Cyan
      return
    }
  }

  Write-Host "`n⏳ Iniciando processo de remoção..." -ForegroundColor Yellow

  if ($distroExists) {
    try {
      Write-Host "   -> Terminando a distribuição '$DistroName' (se estiver em execução)..." -ForegroundColor DarkGray
      wsl --terminate $DistroName 2>$null
      Write-Host "   -> Removendo registro da distribuição '$DistroName'..." -ForegroundColor Yellow
      wsl --unregister $DistroName | Out-Null
      Write-Host "   ✅ Distribuição desregistrada com sucesso." -ForegroundColor Green
    }
    catch {
      Write-Host "   🛑 ERRO ao tentar remover a distribuição WSL: $($_.Exception.Message)" -ForegroundColor Red
    }
  }

  if ($dirExists) {
    try {
      Write-Host "   -> Removendo diretório de instalação: $InstallPath" -ForegroundColor Yellow
      Remove-Item -Path $InstallPath -Recurse -Force
      Write-Host "   ✅ Diretório de instalação removido com sucesso." -ForegroundColor Green
    }
    catch {
      Write-Host "   🛑 ERRO ao remover o diretório de instalação: $($_.Exception.Message)" -ForegroundColor Red
    }
  }

  if ($connectModuleExists) {
    try {
      Write-Host "   -> Removendo módulo PowerShell 'Connect-ParrotGUI'..." -ForegroundColor Yellow
      Remove-Item -Path $connectModuleDir -Recurse -Force
      Write-Host "   ✅ Módulo 'Connect-ParrotGUI' removido com sucesso." -ForegroundColor Green
    }
    catch {
      Write-Host "   🛑 ERRO ao remover o módulo 'Connect-ParrotGUI': $($_.Exception.Message)" -ForegroundColor Red
    }
  }

  if ($uninstallModuleExists) {
    try {
      Write-Host "   -> Removendo módulo PowerShell 'Uninstall-ParrotWSL'..." -ForegroundColor Yellow
      Remove-Item -Path $uninstallModuleDir -Recurse -Force
      Write-Host "   ✅ Módulo 'Uninstall-ParrotWSL' removido com sucesso." -ForegroundColor Green
    }
    catch {
      Write-Host "   🛑 ERRO ao remover o módulo 'Uninstall-ParrotWSL': $($_.Exception.Message)" -ForegroundColor Red
    }
  }

  Write-Host "`n🎉 Processo de desinstalação concluído." -ForegroundColor Green
  Write-Host "   Pode ser necessário reiniciar o terminal para que a remoção dos comandos tenha efeito completo." -ForegroundColor DarkGray
}