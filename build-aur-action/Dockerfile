FROM archlinux:multilib-devel

RUN pacman-key --init && pacman-key --lsign-key "farseerfc@archlinux.org" && pacman-key --recv-key 3056513887B78AEB && pacman-key --lsign-key 3056513887B78AEB && pacman -U --noconfirm --needed 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' && pacman-key --recv-keys 7931B6D628C8D3BA && pacman-key --lsign-key 7931B6D628C8D3BA && pacman -Syu --noconfirm --needed git python && sed -i '1i Server = https://cloudflaremirrors.com/archlinux/$repo/os/$arch' /etc/pacman.d/mirrorlist && cat << EOM >> /etc/pacman.conf
[archlinuxcn]
Server = https://repo.archlinuxcn.org/\$arch
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
[arch4edu]
Server = https://repository.arch4edu.org/\$arch
EOM

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
