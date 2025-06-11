# Copyright (c) 2025 João Carlos Chavatte (DEV Chavatte)
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.

param(
    [string]$DistroName = "ParrotOS",
    [string]$InstallPath = "$env:SystemDrive\WSL_Distros\ParrotOS",
    [switch]$Force
)

. (Join-Path $PSScriptRoot "Scripts" "PowerShell\Uninstall-ParrotWSL.ps1")

Uninstall-ParrotWSL -DistroName $DistroName -InstallPath $InstallPath -Force:$Force