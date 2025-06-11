# Copyright (c) 2025 João Carlos Chavatte (DEV Chavatte)
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.

function Install-PSModule {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$FunctionName,

    [Parameter(Mandatory = $true)]
    [string]$SourceScriptPath
  )

  Write-Host "`n=== ⚙️  Instalando o comando PowerShell '$FunctionName' === " -ForegroundColor Cyan

  try {
    if (-not (Test-Path -Path $SourceScriptPath -PathType Leaf)) {
      Write-Host "🛑 ERRO: Arquivo de origem não encontrado em '$SourceScriptPath'." -ForegroundColor Red; return
    }

    $userModulePath = ($env:PSModulePath -split ';') | Where-Object { $_ -like "*$($env:USERPROFILE)*" } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($userModulePath)) {
      Write-Host "🛑 ERRO: Não foi possível determinar o caminho dos módulos do PowerShell." -ForegroundColor Red; return
    }

    $targetModuleDir = Join-Path -Path $userModulePath -ChildPath $FunctionName
    if (-not (Test-Path -Path $targetModuleDir)) {
      New-Item -ItemType Directory -Path $targetModuleDir -Force | Out-Null
    }

    $targetModuleFile = Join-Path -Path $targetModuleDir -ChildPath "$FunctionName.psm1"
    Get-Content -Path $SourceScriptPath -Raw | Set-Content -Path $targetModuleFile -Encoding UTF8
        
    Write-Host "✅ SUCESSO! O comando '$FunctionName' foi instalado." -ForegroundColor Green
    Write-Host "   Para usar, abra um NOVO terminal PowerShell." -ForegroundColor Green
  }
  catch {
    Write-Host "🛑 ERRO FATAL ao tentar instalar o módulo: $($_.Exception.Message)" -ForegroundColor Red
  }
}