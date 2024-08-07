#!/bin/bash
set -euo pipefail

FILE="$(basename "$0")"

# Enable the cloudflare mirror
sed -i '1i Server = https://cloudflaremirrors.com/archlinux/$repo/os/$arch' /etc/pacman.d/mirrorlist

# Enable the multilib repository
cat << EOM >> /etc/pacman.conf
[archlinuxcn]
Server = https://repo.archlinuxcn.org/\$arch
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOM

pacman -Syu --noconfirm --needed archlinuxcn-keyring && pacman -Syu --noconfirm --needed paru

# Makepkg does not allow running as root
# Create a new user `builder`
# `builder` needs to have a home directory because some PKGBUILDs will try to
# write to it (e.g. for cache)
useradd builder -m
# When installing dependencies, makepkg will use sudo
# Give user `builder` passwordless sudo access
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Give all users (particularly builder) full access to these files
chmod -R a+rw .

BASEDIR="${PWD}"
echo "BASEDIR: ${BASEDIR}"
cd "${INPUT_PKGDIR:-.}"

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

# Just generate .SRCINFO
if ! [ -f .SRCINFO ]; then
    sudo -H -u builder env "PATH=${PATH}" makepkg --printsrcinfo > .SRCINFO
fi

function create_git_repository() {
    [ -d .git ] && return
    sudo -H -u builder env "PATH=${PATH}" git config --global init.defaultBranch main
    sudo -H -u builder env "PATH=${PATH}" git config --global user.email buildere@users.noreply.builder.com
    sudo -H -u builder env "PATH=${PATH}" git config --global user.name builder
    sudo -H -u builder env "PATH=${PATH}" git config --global --add safe.directory "${PWD}"
    sudo -H -u builder env "PATH=${PATH}" git init
    sudo -H -u builder env "PATH=${PATH}" git add .
    sudo -H -u builder env "PATH=${PATH}" git commit -m 'create git repository'
}

function recursive_build () {
    for d in *; do
        if [ -d "$d" ]; then
            (cd -- "$d" && recursive_build)
        fi
    done

    sudo -H -u builder env "PATH=${PATH}" makepkg --printsrcinfo > .SRCINFO
    mapfile -t OTHERPKGDEPS < \
        <(sed -n -e 's/^[[:space:]]*\(make\)\?depends\(_x86_64\)\? = \([[:alnum:][:punct:]]*\)[[:space:]]*$/\3/p' .SRCINFO)
    sudo -H -u builder env "PATH=${PATH}" paru -Syu --noconfirm --needed --clonedir="${BASEDIR}" "${OTHERPKGDEPS[@]}"
    create_git_repository
    sudo -H -u builder env "PATH=${PATH}" makepkg --install --noconfirm
    [ -d "${BASEDIR}/local/" ] || mkdir "${BASEDIR}/local/"
    cp ./*.pkg.tar.zst "${BASEDIR}/local/"
}

# Optionally install dependencies from AUR
if [ -n "${INPUT_AURDEPS:-}" ]; then
    # Extract dependencies from .SRCINFO (depends or depends_x86_64) and install
    mapfile -t PKGDEPS < \
        <(sed -n -e 's/^[[:space:]]*\(make\)\?depends\(_x86_64\)\? = \([[:alnum:][:punct:]]*\)[[:space:]]*$/\3/p' .SRCINFO)

    # If package have dependencies from AUR and we want to use our PKGBUILD of these dependencies
    CURDIR="${PWD}"
    for d in *; do
        if [ -d "$d" ]; then
            (cd -- "$d" && recursive_build)
        fi
    done
    cd "${CURDIR}"

    sudo -H -u builder env "PATH=${PATH}" paru -Syu --noconfirm --needed --clonedir="${BASEDIR}" "${PKGDEPS[@]}"
fi

# Build packages
# INPUT_MAKEPKGARGS is intentionally unquoted to allow arg splitting
# shellcheck disable=SC2086
create_git_repository
sudo -H -u builder makepkg --syncdeps --noconfirm ${INPUT_MAKEPKGARGS:-}

# Get array of packages to be built
mapfile -t PKGFILES < <( sudo -H -u builder env "PATH=${PATH}" makepkg --packagelist )
echo "Package(s): ${PKGFILES[*]}"

# Report built package archives
i=0
for PKGFILE in "${PKGFILES[@]}"; do
    # makepkg reports absolute paths, must be relative for use by other actions
    RELPKGFILE="$(realpath --relative-base="${BASEDIR}" "${PKGFILE}")"
    # Caller arguments to makepkg may mean the pacakge is not built
    if [ -f "${PKGFILE}" ]; then
        echo "pkgfile$i=${RELPKGFILE}" >> $GITHUB_OUTPUT
    else
        echo "Archive ${RELPKGFILE} not built"
    fi
    (( ++i ))
done

function prepend () {
    # Prepend the argument to each input line
    while read -r line; do
        echo "$1${line}"
    done
}

function namcap_check() {
    # Run namcap checks
    # Installing namcap after building so that makepkg happens on a minimal
    # install where any missing dependencies can be caught.
    pacman -Syu --noconfirm --needed namcap

    NAMCAP_ARGS=()
    if [ -n "${INPUT_NAMCAPRULES:-}" ]; then
        NAMCAP_ARGS+=( "-r" "${INPUT_NAMCAPRULES}" )
    fi
    if [ -n "${INPUT_NAMCAPEXCLUDERULES:-}" ]; then
        NAMCAP_ARGS+=( "-e" "${INPUT_NAMCAPEXCLUDERULES}" )
    fi

    # For reasons that I don't understand, sudo is not resetting '$PATH'
    # As a result, namcap finds program paths in /usr/sbin instead of /usr/bin
    # which makes namcap fail to identify the packages that provide the
    # program and so it emits spurious warnings.
    # More details: https://bugs.archlinux.org/task/66430
    #
    # Work around this issue by putting bin ahead of sbin in $PATH
    export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"

    namcap "${NAMCAP_ARGS[@]}" PKGBUILD \
        | prepend "::warning file=${FILE},line=${LINENO}::"
    for PKGFILE in "${PKGFILES[@]}"; do
        if [ -f "${PKGFILE}" ]; then
            RELPKGFILE="$(realpath --relative-base="${BASEDIR}" "${PKGFILE}")"
            namcap "${NAMCAP_ARGS[@]}" "${PKGFILE}" \
                | prepend "::warning file=${FILE},line=${LINENO}::${RELPKGFILE}:"
        fi
    done
}

if [ -z "${INPUT_NAMCAPDISABLE:-}" ]; then
    namcap_check
fi

python3 $BASEDIR/build-nonaur-action/encode_name.py
