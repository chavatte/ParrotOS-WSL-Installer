# Copyright (c) 2025 João Carlos Chavatte (DEV Chavatte)
#
# This code is part of the ParrotOS-WSL Installer project.
# It is licensed under the MIT License.
# See LICENSE file for details.

#!/bin/bash
set -e
set -x

export DEBIAN_FRONTEND=noninteractive

if locale -a | grep -q '^C.UTF-8$'; then
    export LANG=C.UTF-8
    export LC_ALL=C.UTF-8
else
    export LANG=C
    export LC_ALL=C
fi

apt-get update -y || { echo "ERRO BASH: Falha no apt-get update inicial"; exit 1; }
apt-get install -y dialog locales sudo --reinstall || { echo "ERRO BASH: Falha ao instalar/reinstalar locales ou sudo"; exit 1; }

echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
dpkg-reconfigure --frontend=noninteractive locales || { echo "ERRO BASH: Falha ao executar dpkg-reconfigure locales"; exit 1; }

update-locale LANG=en_US.UTF-8 LANGUAGE="en_US:en" LC_MESSAGES=POSIX LC_ALL=en_US.UTF-8

export LANG=en_US.UTF-8
export LANGUAGE="en_US:en"
export LC_MESSAGES=POSIX
export LC_ALL=en_US.UTF-8

locale

if ! id -u "__USERNAME_PLACEHOLDER__" >/dev/null 2>&1; then
    useradd -m -G sudo,adm,cdrom,dip,plugdev -s /bin/bash "__USERNAME_PLACEHOLDER__" || \
        { echo "ERRO BASH: Falha ao executar useradd para '__USERNAME_PLACEHOLDER__'"; exit 1; }

    echo "__USERNAME_PLACEHOLDER__:__PASSWORD_PLACEHOLDER__" | chpasswd || \
        { echo "ERRO BASH: Falha ao executar chpasswd para '__USERNAME_PLACEHOLDER__'"; exit 1; }
fi

mkdir -p /etc
echo -e "[user]\ndefault = __USERNAME_PLACEHOLDER__" > /etc/wsl.conf || \
    { echo "ERRO BASH: Falha ao escrever em /etc/wsl.conf"; exit 1; }

apt-get upgrade -y || { echo "ERRO BASH: Falha durante apt-get upgrade"; exit 1; }

apt-get clean
rm -rf /var/lib/apt/lists/*