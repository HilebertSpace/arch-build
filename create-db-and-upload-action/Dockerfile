FROM archlinux:multilib-devel

RUN pacman-key --init && sed -i '1i Server = https://cloudflaremirrors.com/archlinux/$repo/os/$arch' /etc/pacman.d/mirrorlist && pacman -Syu --noconfirm --needed git python rclone pyalpm && sed -i '/E_ROOT/d' /usr/bin/makepkg

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
