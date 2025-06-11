# Copyright (c) 2025 João Carlos Chavatte (DEV Chavatte)
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.

function Install-ParrotWSL {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RootFSPath,

    [string]$DistroName = "ParrotOS",

    [string]$InstallPath = "$env:SystemDrive\WSL_Distros\ParrotOS"
  )

  Write-Host "`n=== ⚙️ INSTALANDO PARROT OS NO WSL2 === " -ForegroundColor Cyan

  Write-Host "ℹ️ Verificando arquivo rootfs..." -ForegroundColor Yellow
  if (-not (Test-Path $RootFSPath)) {
    Write-Host "🛑 ERRO: Arquivo rootfs não encontrado em: $RootFSPath" -ForegroundColor Red
    exit 1
  }
  Write-Host "✅ Arquivo rootfs encontrado: $(Split-Path $RootFSPath -Leaf)" -ForegroundColor Green

  Write-Host "ℹ️ Verificando diretório de instalação..." -ForegroundColor Yellow
  if (-not (Test-Path $InstallPath)) {
    try {
      Write-Host "🛠️ Criando diretório de instalação em: $InstallPath" -ForegroundColor Yellow
      New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
      Write-Host "✅ Diretório de instalação criado: $InstallPath" -ForegroundColor Green
    }
    catch {
      Write-Host "🛑 ERRO: Falha ao criar diretório de instalação: $($_.Exception.Message)" -ForegroundColor Red
      exit 1
    }
  }
  else {
    Write-Host "✅ Diretório de instalação já existe: $InstallPath" -ForegroundColor Green
  }

  Write-Host "ℹ️ Verificando se a distribuição '$DistroName' já existe..." -ForegroundColor Yellow
  $existingDistros = wsl --list --quiet
  if ($existingDistros -contains $DistroName) {
    Write-Host "⚠️ AVISO: A distribuição '$DistroName' já está instalada." -ForegroundColor Yellow
    
    $choiceUser = $null
    while ($choiceUser -notmatch '^[sSnN]$') {
      $choiceUser = Read-Host "❓ Deseja reinstalar? (Isso removerá a instalação existente) [S/N]"
      if ($choiceUser -notmatch '^[sSnN]$') {
        Write-Host "⚠️ Opção inválida. Por favor, digite 'S' para Sim ou 'N' para Não." -ForegroundColor Yellow
      }
    }

    if ($choiceUser -notmatch '^[sS]') {
      Write-Host "ℹ️ Instalação cancelada pelo usuário." -ForegroundColor Yellow
      exit 0
    }
    
    try {
      Write-Host "🛠️ Removendo instalação existente ($DistroName)..." -ForegroundColor Yellow
      wsl --unregister $DistroName
      if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️ AVISO PS: 'wsl --unregister $DistroName' retornou o código de saída: $LASTEXITCODE." -ForegroundColor Yellow
        Write-Host "   Isso pode ser normal se a distro não puder ser interrompida imediatamente ou já foi parcialmente removida." -ForegroundColor Yellow
        Write-Host "   Prosseguindo com a tentativa de importação..." -ForegroundColor Yellow
      }
      else {
        Write-Host "✅ Distribuição $DistroName desregistrada com sucesso (ou não estava totalmente registrada)." -ForegroundColor Green
      }
      Start-Sleep -Seconds 3 
    }
    catch {
      Write-Host "🛑 ERRO PS: Exceção ao tentar remover instalação existente: $($_.Exception.Message)" -ForegroundColor Red
      exit 1
    }
  }

  try {
    Write-Host "⏳ Importando Parrot OS (isso pode levar alguns minutos)..." -ForegroundColor Yellow
    wsl --import $DistroName $InstallPath $RootFSPath --version 2
    if ($LASTEXITCODE -ne 0) {
      Write-Host "🛑 ERRO PS: Falha ao executar 'wsl --import'. Código de saída: $LASTEXITCODE" -ForegroundColor Red
      exit 1
    }
    Write-Host "✅ Parrot OS importado com sucesso!" -ForegroundColor Green
  }
  catch {
    Write-Host "🛑 ERRO PS: Exceção durante a importação da distribuição: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
  }

  try {
    Write-Host "`n=== 👤 CONFIGURANDO USUÁRIO PADRÃO === " -ForegroundColor Cyan
    
    $defaultUserSuggestion = ($env:USERNAME -replace '[^a-zA-Z0-9]', '').ToLower()
    if ([string]::IsNullOrWhiteSpace($defaultUserSuggestion)) { $defaultUserSuggestion = "parrotuser" }
    
    $userName = ""
    while ([string]::IsNullOrWhiteSpace($userName) -or $userName -match '[^a-zA-Z0-9_]') {
      $userName = Read-Host "❓ Digite o nome de usuário para o Parrot OS (letras, números, underscore) [padrão: $defaultUserSuggestion]"
      if ([string]::IsNullOrWhiteSpace($userName)) { $userName = $defaultUserSuggestion }
      if ($userName -match '[^a-zA-Z0-9_]') {
        Write-Host "⚠️ Nome de usuário inválido. Use apenas letras, números e underscore (_)." -ForegroundColor Yellow
      }
    }
    
    $plainPassword = ""
    while ($true) {
      $passwordInput = Read-Host "❓ Digite a senha para o usuário '$userName'" -AsSecureString
      if ($passwordInput.Length -eq 0) {
        Write-Host "⚠️ A senha não pode estar vazia. Tente novamente." -ForegroundColor Yellow
        continue
      }
      $bstr = [System.IntPtr]::Zero
      try {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($passwordInput)
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
      }
      finally {
        if ($bstr -ne [System.IntPtr]::Zero) {
          [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
      }
      if ([string]::IsNullOrWhiteSpace($plainPassword)) {
        Write-Host "⚠️ A senha fornecida resultou em um valor vazio ou inválido após conversão. Tente novamente." -ForegroundColor Yellow
        $passwordInput.Dispose()
        continue
      }
      $passwordInput.Dispose()
      break 
    }
    
    Write-Host "⏳ Configurando usuário e ambiente (isso pode levar alguns minutos)..." -ForegroundColor Yellow
    
    $functionScriptPath = $MyInvocation.MyCommand.ScriptBlock.File

    if ([string]::IsNullOrWhiteSpace($functionScriptPath)) {
      Write-Host "🛑 ERRO PS: Não foi possível determinar o caminho do script da função via \$MyInvocation.MyCommand.ScriptBlock.File." -ForegroundColor Red
      exit 1
    }

    $ScriptDirectory = Split-Path $functionScriptPath -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($ScriptDirectory)) {
      Write-Host "🛑 ERRO PS: Não foi possível determinar o diretório do script da função (ScriptDirectory está vazio ou nulo)." -ForegroundColor Red
      exit 1
    }
    
    $bashScriptFileName = "configure_parrot_internal.sh"
    $bashScriptPath = Join-Path (Split-Path $ScriptDirectory -Parent) "Bash" $bashScriptFileName
    

    if ([string]::IsNullOrWhiteSpace($bashScriptPath)) {
      Write-Host "🛑 ERRO PS: Caminho para o script Bash interno (\$bashScriptPath) está vazio ou nulo APÓS Join-Path." -ForegroundColor Red
      exit 1
    }

    if (-not (Test-Path $bashScriptPath -PathType Leaf)) {
      Write-Host "🛑 ERRO PS: Script de configuração interna do Bash ('$bashScriptFileName') NÃO ENCONTRADO ou não é um arquivo em: '$bashScriptPath'" -ForegroundColor Red
      Write-Host "   Verifique se o arquivo '$bashScriptFileName' existe em '$(Split-Path $bashScriptPath -Parent)'." -ForegroundColor Yellow
      exit 1
    }

    try {
      $wslCommandsTemplate = Get-Content -Path $bashScriptPath -Raw -ErrorAction Stop
    }
    catch {
      Write-Host "🛑 ERRO PS: Falha ao ler o arquivo de script Bash '$bashScriptPath'. Exceção: $($_.Exception.Message)" -ForegroundColor Red
      exit 1
    }
    
    $wslCommands = $wslCommandsTemplate -replace '__USERNAME_PLACEHOLDER__', $userName -replace '__PASSWORD_PLACEHOLDER__', $plainPassword
                                     
    $unixWslCommands = $wslCommands -replace "`r`n", "`n" -replace "`r", "`n"
    
    if ($unixWslCommands.Length -gt 0 -and $unixWslCommands[0] -eq [char]0xFEFF) {
      $unixWslCommands = $unixWslCommands.Substring(1)
    } 

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "wsl.exe"
    $psi.Arguments = "-d $DistroName -- bash -s" 
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true 
    $psi.StandardInputEncoding = [System.Text.UTF8Encoding]::new($false)
    $psi.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $psi.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    
    try {
      if (-not ($process.Start())) {
        Write-Host "🛑 ERRO PS: Falha ao iniciar o processo wsl.exe (Start() retornou false)." -ForegroundColor Red
        exit 1
      }
    }
    catch {
      Write-Host "🛑 ERRO PS: Exceção ao tentar iniciar o processo wsl.exe. $($_.Exception.Message)" -ForegroundColor Red
      exit 1
    }

    $inputStream = $process.StandardInput
    $inputStream.Write($unixWslCommands)
    $inputStream.Close() 

    $wslExecutionOutput = $process.StandardOutput.ReadToEnd()
    $wslErrorOutput = $process.StandardError.ReadToEnd()
    
    $process.WaitForExit() 
    $wslExitCode = $process.ExitCode 
    $process.Close() 

    $bashScriptFailed = $false
    if ($wslExitCode -ne 0) {
      $bashScriptFailed = $true
      Write-Host "🛑 ERRO PS: O script de configuração dentro do WSL falhou com o código de saída: $wslExitCode." -ForegroundColor Red
    }
    if (($wslExecutionOutput -match "ERRO BASH:") -or ($wslErrorOutput -match "ERRO BASH:")) {
      $bashScriptFailed = $true
      Write-Host "⚠️ AVISO PS: Foram detectados 'ERRO BASH:' na saída do script de configuração do WSL." -ForegroundColor Yellow
    }

    if ($bashScriptFailed) {
      Write-Host "--- 📜 Saída da Execução do Script WSL (STDOUT) ---"
      if (-not [string]::IsNullOrWhiteSpace($wslExecutionOutput)) {
        $wslExecutionOutput.Split([Environment]::NewLine) | ForEach-Object { Write-Host $_ }
      }
      else {
        Write-Host "(Nenhuma saída padrão)"
      }
        
      if (-not [string]::IsNullOrWhiteSpace($wslErrorOutput)) {
        Write-Host "--- ⚠️ Saída de Erro da Execução do Script WSL (STDERR) ---" -ForegroundColor Yellow
        $wslErrorOutput.Split([Environment]::NewLine) | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
      }
      Write-Host "--- Fim da Saída da Execução ---"
    }
    
    Write-Host "✅ Configuração de usuário (etapa WSL) processada." -ForegroundColor Green
  }
  catch {
    Write-Host "🛑 ERRO FATAL PowerShell: Falha ao configurar usuário (exceção PowerShell): $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
    exit 1
  }

  try {
    Write-Host "`n⏳ Reiniciando a distribuição '$DistroName' para aplicar configurações de usuário..." -ForegroundColor Yellow
    wsl --terminate $DistroName
    Start-Sleep -Seconds 5 
    Write-Host "✅ Distribuição '$DistroName' reiniciada." -ForegroundColor Green
  }
  catch {
    Write-Host "⚠️ AVISO: Falha ao tentar reiniciar a distribuição '$DistroName': $($_.Exception.Message)" -ForegroundColor Yellow
  }

  try {
    Write-Host "`n=== 🔍 VERIFICAÇÃO FINAL === " -ForegroundColor Cyan
    
    $testUserOutput = wsl -d $DistroName -- whoami 2>&1 
    $wslExitCodeWhoami = $LASTEXITCODE

    if ($wslExitCodeWhoami -eq 0 -and ($testUserOutput.Trim() -eq $userName)) {
      Write-Host "🎉 Parrot OS instalado e configurado com sucesso!" -ForegroundColor Green
      Write-Host "✅ Nome da distribuição: $DistroName" -ForegroundColor Green
      Write-Host "✅ Diretório de instalação: $InstallPath" -ForegroundColor Green
      Write-Host "✅ Usuário padrão: $userName" -ForegroundColor Green
    }
    else {
      Write-Host "⚠️ AVISO: A verificação do usuário padrão falhou ou retornou um usuário inesperado." -ForegroundColor Yellow
      Write-Host "   Resultado esperado para 'whoami': '$userName'" -ForegroundColor Yellow
      Write-Host "   Resultado obtido: '$($testUserOutput.Trim())' (Código de saída de whoami: $wslExitCodeWhoami)" -ForegroundColor Yellow
      Write-Host "   Pode ser necessário iniciar a distribuição manualmente uma vez (`wsl -d $DistroName`) para que /etc/wsl.conf tenha efeito." -ForegroundColor Yellow
      if ($bashScriptFailed) {
        Write-Host "   Isso pode estar relacionado a erros durante a execução do script de configuração interna do WSL." -ForegroundColor Yellow
      }
    }
  }
  catch {
    Write-Host "⚠️ AVISO: Não foi possível completar a verificação final: $($_.Exception.Message)" -ForegroundColor Yellow
  }
}