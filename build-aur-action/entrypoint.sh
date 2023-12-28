#!/bin/bash

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
Server = https://repo.archlinuxcn.org/x86_64
Server = https://mirrors.xtom.us/archlinuxcn/x86_64
Server = https://mirrors.xtom.jp/archlinuxcn/x86_64
Server = https://mirrors.xtom.hk/archlinuxcn/x86_64
Server = https://mirrors.xtom.nl/archlinuxcn/x86_64
Server = https://mirrors.xtom.de/archlinuxcn/x86_64
Server = https://mirrors.xtom.ee/archlinuxcn/x86_64
Server = https://mirrors.xtom.au/archlinuxcn/x86_64
Server = https://mirrors.ocf.berkeley.edu/archlinuxcn/x86_64
Server = https://archlinux.ccns.ncku.edu.tw/archlinuxcn/x86_64
EOM

pacman-key --init
pacman -Sy --noconfirm && pacman -S --noconfirm archlinuxcn-keyring
pacman -Syu --noconfirm paru
if [ ! -z "$INPUT_PREINSTALLPKGS" ]; then
    pacman -Syu --noconfirm "$INPUT_PREINSTALLPKGS"
fi

sudo --set-home -u builder PATH="/usr/bin/vendor_perl:$PATH" paru -S --noconfirm --clonedir=./ "$pkgname"
cd "./$pkgname" || exit 1
python3 ../build-aur-action/encode_name.py
