#!/bin/bash
set -euo pipefail

pkgname=$1

useradd builder -m
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
chmod -R a+rw .

# Enable the cloudflare mirror
sed -i '1i Server = https://cloudflaremirrors.com/archlinux/$repo/os/$arch' /etc/pacman.d/mirrorlist

# Enable the multilib repository
cat << EOM >> /etc/pacman.conf
[multilib]
Include = /etc/pacman.d/mirrorlist
[archlinuxcn]
Server = https://repo.archlinuxcn.org/\$arch
EOM

pacman -Syu --noconfirm archlinuxcn-keyring
pacman -Syu --noconfirm archlinuxcn-mirrorlist-git paru
sed $d /etc/pacman.conf && 'Include = /etc/pacman.d/archlinuxcn-mirrorlist' >> /etc/pacman.conf
cat /etc/pacman.conf

if [ ! -z "$INPUT_PREINSTALLPKGS" ]; then
    pacman -Syu --noconfirm ${INPUT_PREINSTALLPKGS}
fi

sudo --set-home -u builder PATH="/usr/bin/vendor_perl:$PATH" paru -S --noconfirm --clonedir=./ "$pkgname"
cd "./$pkgname" || exit 1
python3 ../build-aur-action/encode_name.py
