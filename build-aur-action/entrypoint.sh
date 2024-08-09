#!/bin/bash
set -euo pipefail

pkgname=$1

useradd builder -m
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
chmod -R a+rw .

# Enable the cloudflare mirror
sed -i '1i Server = https://cloudflaremirrors.com/archlinux/$repo/os/$arch' /etc/pacman.d/mirrorlist

# Enable the multilib, archlinuxcn and chaotic aur repository
cat << EOM >> /etc/pacman.conf
[archlinuxcn]
Server = https://repo.archlinuxcn.org/\$arch
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOM

pacman -Syu --noconfirm --needed archlinuxcn-keyring && pacman -Syu --noconfirm --needed paru
sudo -H -u builder env "PATH=${PATH}" gpg --batch --recv-keys A53563BC888E6CE5215535992523842AF9681DDF && sudo -H -u builder env "PATH=${PATH}" gpg --batch --lsign A53563BC888E6CE5215535992523842AF9681DDF

if [ ! -z "$INPUT_PREINSTALLPKGS" ]; then
    pacman -Syu --noconfirm --needed ${INPUT_PREINSTALLPKGS}
fi

function set_path(){
    for i in "$@";
    do
        # Check if the directory exists
        [ -d "$i" ] || continue

        # Check if it is not already in your $PATH.
        echo "${PATH}" | grep -Eq "(^|:)$i(:|$)" && continue

        # Then append it to $PATH and export it
        export PATH="${PATH}:$i"
    done
}

set_path /usr/bin/site_perl /usr/bin/vendor_perl /usr/bin/core_perl
sudo -H -u builder env "PATH=${PATH}" paru -Syu --noconfirm --needed $([[ "${INPUT_AURONLY}" == "true" ]] && echo --aur) --clonedir=./ "${pkgname}"
cd "./${pkgname}" || exit 1
python3 ../build-aur-action/encode_name.py
