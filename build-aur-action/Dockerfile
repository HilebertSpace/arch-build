FROM archlinux:multilib-devel

RUN pacman-key --init && pacman-key --lsign-key "farseerfc@archlinux.org" && pacman-key --recv-key 3056513887B78AEB && pacman-key --lsign-key 3056513887B78AEB && pacman -U --noconfirm --needed 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'&& pacman -Syu --noconfirm --needed git python

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
