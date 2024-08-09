#!/usr/bin/python3

import os
import subprocess
import sys
from glob import glob
from base64 import urlsafe_b64encode, urlsafe_b64decode

def run_command(command, check=True, env=None):
    result = subprocess.run(command, shell=True, check=check, env=env)
    if result.returncode != 0:
        sys.exit(result.returncode)

def append_to_file(filepath, content):
    with open(filepath, 'a') as file:
        file.write(content)

def set_path(*paths):
    for path in paths:
        if os.path.isdir(path) and path not in os.getenv('PATH', '').split(os.pathsep):
            os.environ['PATH'] = os.environ['PATH'] + os.pathsep + path

def encode_names():
    names = glob("./*.tar.zst")
    for name in names:
        new_name = name.removesuffix(".tar.zst").replace(":", "-colon-")
        os.rename(name, new_name + ".tar.zst")

def create_user(username):
    try:
        subprocess.run(['id', username], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except subprocess.CalledProcessError:
        run_command(f'useradd {username} -m')

def grant_sudo_privileges(username):
    append_to_file('/etc/sudoers', f'{username} ALL=(ALL) NOPASSWD: ALL\n')

def change_permissions_recursively(directory, mode):
    for root, dirs, files in os.walk(directory):
        for dir in dirs:
            os.chmod(os.path.join(root, dir), mode)
        for file in files:
            os.chmod(os.path.join(root, file), mode)

def enable_repositories():
    pacman_conf_content = """
[archlinuxcn]
Server = https://repo.archlinuxcn.org/$arch
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
[arch4edu]
Server = https://repository.arch4edu.org/$arch
"""
    append_to_file('/etc/pacman.conf', pacman_conf_content)

def install_required_packages(packages):
    for package in packages:
        run_command(f'pacman -Syu --noconfirm --needed {package}')

def install_preinstall_packages(preinstall_pkgs):
    if preinstall_pkgs:
        run_command(f'pacman -Syu --noconfirm --needed {preinstall_pkgs}')

def install_package_with_paru(pkgname, aur_only):
    aur_flag = '--aur' if aur_only else ''
    paru_command = f'paru -Syu --noconfirm --needed {aur_flag} --clonedir=./ {pkgname}'
    run_command(paru_command, env={'PATH': os.environ['PATH'], 'HOME': f'/home/builder'})

def main(pkgname, preinstall_pkgs=None, aur_only=False):
    create_user('builder')
    grant_sudo_privileges('builder')
    change_permissions_recursively('.', stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IWGRP | stat.S_IROTH | stat.S_IWOTH)

    enable_repositories()
    install_required_packages(['archlinuxcn-keyring', 'arch4edu-keyring', 'paru'])
    install_preinstall_packages(preinstall_pkgs)

    set_path('/usr/bin/site_perl', '/usr/bin/vendor_perl', '/usr/bin/core_perl')
    install_package_with_paru(pkgname, aur_only)

    os.chdir(f'./{pkgname}')
    encode_names()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: script.py <pkgname>")
        sys.exit(1)

    pkgname = sys.argv[1]
    preinstall_pkgs = os.getenv('INPUT_PREINSTALLPKGS', '')
    aur_only = os.getenv('INPUT_AURONLY', 'false').lower() == 'true'

    main(pkgname, preinstall_pkgs, aur_only)
