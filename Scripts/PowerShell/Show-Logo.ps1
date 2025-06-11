# Copyright (c) 2025 João Carlos Chavatte (DEV Chavatte)
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.

function Show-Logo {
  [CmdletBinding()]
  param (
    [string]$LogoFilePath
  )

  if (-not (Test-Path -Path $LogoFilePath -PathType Leaf)) {
    return
  }

  try {
    Clear-Host
    $terminalWidth = $Host.UI.RawUI.WindowSize.Width
    if ($terminalWidth -lt 80) {
      Write-Warning "A largura do terminal é muito pequena para exibir o logo."
    }
    else {
      $mensagem = Get-Content -Path $LogoFilePath -Raw
      $logoWidth = ($mensagem -split "`n" | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
      $logoSpacingValue = ($terminalWidth - $logoWidth) / 2
      if ($logoSpacingValue -lt 0) { $logoSpacingValue = 0 }
      $espacamento = " " * $logoSpacingValue

            ($mensagem -split "`r`n") | ForEach-Object { Write-Host ($espacamento + $_) -ForegroundColor DarkGreen }
    }
    $title = "=== INSTALAÇÃO DO PARROT OS NO WSL2 ==="
    $titleSpacingValue = ($terminalWidth - $title.Length) / 2
    if ($titleSpacingValue -lt 0) { $titleSpacingValue = 0 }
    $titleSpacing = " " * $titleSpacingValue
    Write-Host ($titleSpacing + $title) -ForegroundColor Cyan

    $infoLines = @(
      "Este script automatiza a instalação completa do Parrot OS no WSL2.",
      "Ele configura o sistema, um usuário e o ambiente gráfico opcional.",
      "Ao final, oferece a instalação de comandos facilitadores como:",
      "'Connect-ParrotGUI' e 'Uninstall-ParrotWSL' para simplificar o gerenciamento futuro."
    )

    Write-Host
    foreach ($line in $infoLines) {
      $lineSpacingValue = ($terminalWidth - $line.Length) / 2
      if ($lineSpacingValue -lt 0) { $lineSpacingValue = 0 }
      $spacing = " " * $lineSpacingValue
      Write-Host ($spacing + $line) -ForegroundColor White
    }
    Write-Host

    Read-Host -Prompt "Pressione Enter para iniciar o processo"
  }
  catch {
    Write-Warning "Não foi possível exibir a tela de boas-vindas: $($_.Exception.Message)"
  }
}