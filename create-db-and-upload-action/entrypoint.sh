#!/bin/bash
set -e

# Enable the cloudflare mirror
sed -i '1i Server = https://cloudflaremirrors.com/archlinux/$repo/os/$arch' /etc/pacman.d/mirrorlist

# Enable the multilib, archlinuxcn and chaotic aur repository
cat << EOM >> /etc/pacman.conf
[archlinuxcn]
Server = https://repo.archlinuxcn.org/\$arch
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
[arch4edu]
Server = https://repository.arch4edu.org/\$arch
EOM

pacman -Syu --noconfirm --needed archlinuxcn-keyring && pacman -Syu --noconfirm --needed arch4edu-keyring

init_path="${PWD}"
mkdir upload_packages
cp ${local_path}/*/*/*.tar.zst ./upload_packages/

if [ ! -f ~/.config/rclone/rclone.conf ]; then
    mkdir --parents ~/.config/rclone
    echo "[onedrive]" >> ~/.config/rclone/rclone.conf
    echo "type = onedrive" >> ~/.config/rclone/rclone.conf
    echo "client_id=${RCLONE_ONEDRIVE_CLIENT_ID}" >> ~/.config/rclone/rclone.conf
    echo "client_secret=${RCLONE_ONEDRIVE_CLIENT_SECRET}" >> ~/.config/rclone/rclone.conf
    echo "auth_url=${RCLONE_ONEDRIVE_AUTH_URL}" >> ~/.config/rclone/rclone.conf
    echo "token_url=${RCLONE_ONEDRIVE_TOKEN_URL}" >> ~/.config/rclone/rclone.conf
    echo "region=${RCLONE_ONEDRIVE_REGION}" >> ~/.config/rclone/rclone.conf
    echo "drive_type=${RCLONE_ONEDRIVE_DRIVE_TYPE}" >> ~/.config/rclone/rclone.conf
    echo "token=${RCLONE_ONEDRIVE_TOKEN}" >> ~/.config/rclone/rclone.conf
    echo "drive_id=${RCLONE_ONEDRIVE_DRIVE_ID}" >> ~/.config/rclone/rclone.conf
fi

if [ ! -z "${gpg_key}" ]; then
    echo "${gpg_key}" | gpg --import
fi

cd upload_packages || exit 1

repo-add "./${repo_name:?}.db.tar.gz" ./*.tar.zst
python3 "${init_path}/create-db-and-upload-action/sync.py"
rm "./${repo_name:?}.db.tar.gz"
rm "./${repo_name:?}.files.tar.gz"

if [ ! -z "${gpg_key}" ]; then
    packages=( "*.tar.zst" )
    for name in ${packages}
    do
        gpg --detach-sig --yes "${name}"
    done
    repo-add --verify --sign "./${repo_name:?}.db.tar.gz" ./*.tar.zst
fi
rclone copy --copy-links ./ "onedrive:${dest_path:?}"
