# Copyright (c) 2026 Chavatte Security
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.

# Security Revision: Data-Driven Modular i18n Engine

function Get-Locale {
  $culture = (Get-Culture).Name
  $localesPath = Join-Path $PSScriptRoot "Locales"
  $langFile = if (Test-Path "$localesPath\$culture.psd1") { "$culture.psd1" } else { "en-US.psd1" }
  $fullPath = Join-Path $localesPath $langFile
    
  if (Test-Path $fullPath) {
    return Import-PowerShellDataFile -Path $fullPath
  }
  return @{}
}