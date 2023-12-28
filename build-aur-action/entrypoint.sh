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
Server = https://mirrors.xtom.us/archlinuxcn/\$arch
Server = https://mirrors.xtom.jp/archlinuxcn/\$arch
Server = https://mirrors.xtom.hk/archlinuxcn/\$arch
Server = https://mirrors.xtom.nl/archlinuxcn/\$arch
Server = https://mirrors.xtom.de/archlinuxcn/\$arch
Server = https://mirrors.xtom.ee/archlinuxcn/\$arch
Server = https://mirrors.xtom.au/archlinuxcn/\$arch
Server = https://mirrors.ocf.berkeley.edu/archlinuxcn/\$arch
Server = https://archlinux.ccns.ncku.edu.tw/archlinuxcn/\$arch
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

function prepend () {
    # Prepend the argument to each input line
    while read -r line; do
        echo "$1$line"
    done
}

pacman -S --noconfirm --needed namcap
# For reasons that I don't understand, sudo is not resetting '$PATH'
# As a result, namcap finds program paths in /usr/sbin instead of /usr/bin
# which makes namcap fail to identify the packages that provide the
# program and so it emits spurious warnings.
# More details: https://bugs.archlinux.org/task/66430
#
# Work around this issue by putting bin ahead of sbin in $PATH
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"
namcap PKGBUILD | prepend "::warning file=$pkgname PKGBUILD,line=$LINENO::"
