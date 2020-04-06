#!/bin/bash

# Made by fernandomaroto for Portergos

# Adapted from AIS. An excellent bit of code!

chroot_path=$(cat /tmp/chrootpath.txt)
NEW_USER=$(cat /tmp/new_username.txt)    

# not copying any file for now
# Net-install creates the file /tmp/run_once in live environment (need to be transfered to installed system) so it can be used to detect install option

arch_chroot(){
# Use chroot not arch-chroot because of the way calamares mounts partitions
    chroot /tmp/$chroot_path /bin/bash -c "${1}"
}  

# Anything to be executed outside chroot need to be here.

# Copy any file from live environment to new system

_copy_files(){

    local _files_to_copy=(

    /etc/lightdm/*
    /etc/sddm.conf.d/kde_settings.conf
    /etc/pacman.d/hooks/lsb-release.hook
    /etc/pacman.d/hooks/os-release.hook
    /etc/default/grub

)

    local xx

# Uses the entire file path and copies directly to / mounted point
    for xx in ${_files_to_copy[*]}; do rsync -vaRI $xx /tmp/$chroot_path; done

}

_non_vanilla(){

cp -rf /etc/skel/.bashrc /tmp/$chroot_path/home/$NEW_USER/.bashrc
chown -R $NEW_USER:users /tmp/$chroot_path/home/$NEW_USER/.bashrc

}

# For chrooted commands edit the script bellow directly
arch_chroot "/usr/bin/chrooted_cleaner_script.sh"
