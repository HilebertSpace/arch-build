FROM archlinux:base-devel

RUN pacman-key --init && pacman -Syu --noconfirm --needed git python rclone pyalpm && sed -i '/E_ROOT/d' /usr/bin/makepkg

COPY gitconfig /etc/gitconfig
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
