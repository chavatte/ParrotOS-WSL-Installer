# Copyright (c) 2025 João Carlos Chavatte (DEV Chavatte)
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.

function Enable-WSL2 {
  [CmdletBinding()]
  param()

  Write-Host "`n=== ⚙️ VERIFICANDO PRÉ-REQUISITOS DO WSL2 === " -ForegroundColor Cyan

  $osInfo = Get-ComputerInfo | Select-Object OsName, OsVersion, OsArchitecture
  $buildNumber = [System.Environment]::OSVersion.Version.Build

  Write-Host "ℹ️ Verificando compatibilidade do sistema operacional..." -ForegroundColor Yellow
  if ($buildNumber -lt 19041) {
    Write-Host "🛑 ERRO: Seu Windows ($($osInfo.OsName) - Build $buildNumber) não suporta WSL2." -ForegroundColor Red
    Write-Host "ℹ️ É necessário Windows 10 versão 2004 (build 19041) ou superior, ou Windows 11." -ForegroundColor Yellow
    exit 1
  }
  Write-Host "✅ Sistema operacional compatível detectado: $($osInfo.OsName) (Build $buildNumber)" -ForegroundColor Green

  try {
    Write-Host "ℹ️ Verificando status dos recursos 'VirtualMachinePlatform' e 'Microsoft-Windows-Subsystem-Linux'..." -ForegroundColor Yellow
    $vmEnabled = (Get-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform").State -eq "Enabled"
    $wslEnabled = (Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux").State -eq "Enabled"
        
    if (-not $vmEnabled -or -not $wslEnabled) {
      Write-Host "🛠️ Habilitando recursos necessários do Windows ('VirtualMachinePlatform', 'Microsoft-Windows-Subsystem-Linux')..." -ForegroundColor Yellow
      Write-Host "⚠️ Isso pode exigir uma reinicialização do sistema." -ForegroundColor Yellow
      Write-Host "⏳ O processo pode demorar alguns minutos." -ForegroundColor Yellow
      
      if (-not $vmEnabled) {
        Write-Host "🛠️ Habilitando 'VirtualMachinePlatform'..." -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart -ErrorAction Stop | Out-Null
        Write-Host "✅ 'VirtualMachinePlatform' habilitado." -ForegroundColor Green
      }
      else {
        Write-Host "✅ 'VirtualMachinePlatform' já está habilitado." -ForegroundColor Green
      }

      if (-not $wslEnabled) {
        Write-Host "🛠️ Habilitando 'Microsoft-Windows-Subsystem-Linux'..." -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart -ErrorAction Stop | Out-Null
        Write-Host "✅ 'Microsoft-Windows-Subsystem-Linux' habilitado." -ForegroundColor Green
      }
      else {
        Write-Host "✅ 'Microsoft-Windows-Subsystem-Linux' já está habilitado." -ForegroundColor Green
      }
            
      Write-Host "✅ Recursos habilitados com sucesso. Uma reinicialização é necessária para aplicar todas as alterações." -ForegroundColor Green
      Write-Host "ℹ️ Você pode reiniciar agora ou mais tarde." -ForegroundColor Yellow
      
      $choice = $null
      while ($choice -notmatch '^[sSnN]$') {
        $choice = Read-Host "❓ Deseja reiniciar o computador agora? (S/N)"
        if ($choice -notmatch '^[sSnN]$') {
          Write-Host "⚠️ Opção inválida. Por favor, digite 'S' para Sim ou 'N' para Não." -ForegroundColor Yellow
        }
      }

      if ($choice -match '^[sS]') {
        Write-Host "⏳ Reiniciando o computador..." -ForegroundColor Yellow
        Restart-Computer -Force
      }
      else {
        Write-Host "ℹ️ Você precisará reiniciar manualmente para continuar a instalação e para que as alterações tenham efeito." -ForegroundColor Yellow
        exit 0
      }
    }
    else {
      Write-Host "✅ Recursos 'VirtualMachinePlatform' e 'Microsoft-Windows-Subsystem-Linux' já estão habilitados." -ForegroundColor Green
    }
  }
  catch {
    Write-Host "🛑 ERRO: Falha ao habilitar recursos do WSL: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
  }

  try {
    Write-Host "`n=== ⚙️ CONFIGURANDO WSL2 === " -ForegroundColor Cyan

    $wslInstalled = $false
    try {
      $null = wsl --status 2>$null
      $wslInstalled = $?
    }
    catch {
      $wslInstalled = $false
    }

    if (-not $wslInstalled) {
      Write-Host "ℹ️ Componentes principais do WSL não encontrados ou kernel ausente." -ForegroundColor Yellow
      Write-Host "🛠️ Instalando componentes e kernel do WSL2..." -ForegroundColor Yellow
      Write-Host "⏳ Isso pode demorar alguns minutos." -ForegroundColor Yellow
      Write-Host "ℹ️ Para mais informações, acesse: https://aka.ms/wsl2kernel" -ForegroundColor Yellow
      wsl --install --no-distribution | Out-Null
      if ($LASTEXITCODE -ne 0) {
        Write-Host "🛑 ERRO: Falha ao executar 'wsl --install --no-distribution'. Código: $LASTEXITCODE" -ForegroundColor Red
        Write-Host "ℹ️ Pode ser necessário reiniciar o computador se os recursos foram habilitados na etapa anterior." -ForegroundColor Yellow
        exit 1
      }
      Write-Host "✅ Componentes e kernel do WSL2 instalados." -ForegroundColor Green
    }
    else {
      Write-Host "ℹ️ WSL já detectado. Verificando atualizações do kernel..." -ForegroundColor Yellow
      Write-Host "🛠️ Atualizando componentes do WSL (incluindo o kernel, se necessário)..." -ForegroundColor Yellow
      Write-Host "⏳ Isso pode demorar alguns minutos." -ForegroundColor Yellow
      wsl --update | Out-Null
      if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️ AVISO: 'wsl --update' retornou o código $LASTEXITCODE. Tentando prosseguir." -ForegroundColor Yellow
      }
      else {
        Write-Host "✅ Componentes do WSL atualizados." -ForegroundColor Green
      }
    }

    Write-Host "🛠️ Definindo WSL2 como a versão padrão para novas distribuições..." -ForegroundColor Yellow
    wsl --set-default-version 2 | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Write-Host "🛑 ERRO: Falha ao definir WSL2 como versão padrão. Código: $LASTEXITCODE" -ForegroundColor Red
      Write-Host "ℹ️ Verifique se o WSL foi instalado corretamente e se a virtualização está habilitada na BIOS." -ForegroundColor Yellow
      exit 1
    }
    Write-Host "✅ WSL2 definido como a versão padrão." -ForegroundColor Green
        
  }
  catch {
    Write-Host "🛑 ERRO: Falha ao configurar o WSL2: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "ℹ️ Tente executar o script novamente ou consulte a documentação do WSL." -ForegroundColor Yellow
    Write-Host "ℹ️ Para mais informações, acesse: https://aka.ms/wsl2kernel" -ForegroundColor Yellow
    exit 1
  }
  
  Write-Host "`n=== 🔍 VERIFICANDO O STATUS DO WSL === " -ForegroundColor Cyan
  Write-Host "ℹ️ Verificando o status e a versão padrão do WSL..." -ForegroundColor Yellow
  try {
    $wslStatusOutput = wsl --status
    if ($LASTEXITCODE -ne 0) {
      Write-Host "⚠️ AVISO: Não foi possível obter o status detalhado do WSL via 'wsl --status'. Código: $LASTEXITCODE" -ForegroundColor Yellow
      Write-Host "   Isso pode ocorrer em algumas versões do Windows ou se o WSL não estiver totalmente funcional." -ForegroundColor Yellow
      Write-Host "   Tentando verificar a versão padrão de outra forma..." -ForegroundColor Yellow
      $defaultVersionCheck = (wsl --list --verbose) | Select-String "^\*\s"
      if ($defaultVersionCheck -match "VERSION\s+2") {
        Write-Host "✅ Versão padrão do WSL parece ser 2 (verificado via wsl --list --verbose)." -ForegroundColor Green
      }
      else {
        Write-Host "⚠️ Não foi possível confirmar se a versão padrão do WSL é 2." -ForegroundColor Yellow
      }
    }
    else {
      if ($wslStatusOutput -match "2") {
        Write-Host "✅ WSL2 está instalado e configurado corretamente como padrão." -ForegroundColor Green
      }
      else {
        Write-Host "⚠️ A versão padrão do WSL não parece ser 2 ou não pôde ser confirmada pelo 'wsl --status'." -ForegroundColor Yellow
        Write-Host "   Verifique a saída acima. Se o WSL foi instalado/atualizado agora, pode ser necessário reiniciar." -ForegroundColor Yellow
      }
    }
  }
  catch {
    Write-Host "🛑 ERRO: Não foi possível verificar o status do WSL: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
  }
  Write-Host "🎉 Verificação de pré-requisitos e configuração do WSL2 concluída." -ForegroundColor Green
}