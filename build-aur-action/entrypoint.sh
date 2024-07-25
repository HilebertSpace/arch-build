#!/bin/bash
set -euo pipefail

pkgname=$1

source /etc/profile.d/perlbin.sh

useradd builder -m
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
chmod -R a+rw .

# Enable the cloudflare mirror
sed -i '1i Server = https://cloudflaremirrors.com/archlinux/$repo/os/$arch' /etc/pacman.d/mirrorlist

# Enable the multilib, archlinuxcn and chaotic aur repository
cat << EOM >> /etc/pacman.conf
[multilib]
Include = /etc/pacman.d/mirrorlist
[archlinuxcn]
Server = https://repo.archlinuxcn.org/\$arch
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOM

pacman -Syu --noconfirm --needed archlinuxcn-keyring && pacman -Syu --noconfirm --needed archlinuxcn-mirrorlist-git paru
sed -i '1i Server = https://repo.archlinuxcn.org/\$arch' /etc/pacman.d/archlinuxcn-mirrorlist
sed -i "s|^Server = https://repo.archlinuxcn.org/\$arch|Include = /etc/pacman.d/archlinuxcn-mirrorlist|g" /etc/pacman.conf

if [ ! -z "$INPUT_PREINSTALLPKGS" ]; then
    pacman -Syu --noconfirm --needed ${INPUT_PREINSTALLPKGS}
fi

echo $PATH
sudo -H -u builder paru -Syu --noconfirm --needed --clonedir=./ "${pkgname}"
cd "./${pkgname}" || exit 1
python3 ../build-aur-action/encode_name.py
