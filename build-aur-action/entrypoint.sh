#!/bin/bash

pkgname=$1

FILE="$(basename "$0")"

useradd builder -m
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
chmod -R a+rw .

cat << EOM >> /etc/pacman.conf
[archlinuxcn]
Server = https://repo.archlinuxcn.org/x86_64
EOM

pacman-key --init
pacman -Sy --noconfirm && pacman -S --noconfirm archlinuxcn-keyring
pacman -Syu --noconfirm paru
if [ ! -z "$INPUT_PREINSTALLPKGS" ]; then
    pacman -Syu --noconfirm "$INPUT_PREINSTALLPKGS"
fi

sudo --set-home -u builder PATH="/usr/bin/vendor_perl:$PATH" paru -S --noconfirm --clonedir=./ "$pkgname"

pacman -S --noconfirm --needed namcap
namcap "./$pkgname/PKGBUILD" | echo "::warning file=$FILE::"

cd "./$pkgname" || exit 1
python3 ../build-aur-action/encode_name.py
