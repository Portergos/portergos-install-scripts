#!/bin/bash

# Made by @fernandomaroto for Portergos
# Any failed command will just be skiped, error message may pop up but won't crash the install process

chroot_path=$(cat /tmp/chrootpath.txt)
NEW_USER=$(cat /tmp/new_username.txt)    

_vbox(){

    # Detects if running in vbox
    # packages must be in this order otherwise guest-utils pulls dkms, which takes longer to be installed
    local _vbox_guest_packages=(virtualbox-guest-modules-arch virtualbox-guest-utils)   
    local xx

    lspci | grep -i "virtualbox" >/dev/null
    if [[ $? == 0 ]]
    then
        # If using net-install detect VBox and install the packages
        if [ -f /tmp/run_once ]                  
        then
            for xx in ${_vbox_guest_packages[*]}
            do pacman -S $xx --noconfirm
            done
        fi   
        : 
    else
        for xx in ${_vbox_guest_packages[*]} ; do
            test -n "$(pacman -Q $xx 2>/dev/null)" && pacman -Rnsdd $xx --noconfirm
        done
        rm -f /usr/lib/modules-load.d/virtualbox-guest-dkms.conf
    fi
}

_common_systemd(){
    local _systemd_enable=(NetworkManager vboxservice org.cups.cupsd avahi-daemon systemd-networkd-wait-online systemd-timesyncd tlp gdm lightdm sddm)   
    local _systemd_disable=(multi-user.target pacman-init)           

    local xx
    for xx in ${_systemd_enable[*]}; do systemctl enable -f $xx; done

    local yy
    for yy in ${_systemd_disable[*]}; do systemctl disable -f $yy; done
}

_sed_stuff(){

    # Journal for offline. Turn volatile (for iso) into a real system.
    sed -i 's/volatile/auto/g' /etc/systemd/journald.conf 2>>/tmp/.errlog
    sed -i 's/.*pam_wheel\.so/#&/' /etc/pam.d/su
}

_clean_archiso(){

    local _files_to_remove=(                               
        /etc/sudoers.d/g_wheel
        /var/lib/NetworkManager/NetworkManager.state
        /etc/systemd/system/{choose-mirror.service,pacman-init.service,etc-pacman.d-gnupg.mount,getty@tty1.service.d}
        /etc/systemd/scripts/choose-mirror
        /etc/systemd/system/getty@tty1.service.d/autologin.conf
        /root/{.automated_script.sh,.zlogin}
        /etc/mkinitcpio-archiso.conf
        /etc/initcpio
        /etc/udev/rules.d/81-dhcpcd.rules
        /usr/bin/{calamares_switcher,cleaner_script.sh}
        /home/$NEW_USER/.config/qt5ct

    )
        # maybe inject the config instead of copying it? Sddm can work with .xinitrc file, slim requires it
        # /home/$NEW_USER/{.xinitrc,.xsession,.xprofile}
        # /root/{.xinitrc,.xsession,.xprofile}
        # /etc/skel/{.xinitrc,.xsession,.xprofile}

    local xx

    for xx in ${_files_to_remove[*]}; do rm -rf $xx; done

    find /usr/lib/initcpio -name archiso* -type f -exec rm '{}' \;

}

_clean_offline_packages(){

    local _packages_to_remove=( 
    calamares_current
    calamares_test
)
    local xx
    # @ does one by one to avoid errors in the entire process
    # * can be used to treat all packages in one command
    for xx in ${_packages_to_remove[@]}; do pacman -Rnscv $xx --noconfirm; done

}


_portergos(){

_clean_offline_packages

export DISPLAY=:0.0
dbus-launch dconf load / < /etc/skel/dconf.conf
sudo -H -u $NEW_USER bash -c 'dbus-launch dconf load / < /etc/skel/dconf.conf'
rm /home/$NEW_USER/dconf.conf
rm /etc/skel/dconf.conf

#conky and installer icons
sed -i "/\${font sans:bold:size=8}INSTALLERS \${hr 2}/d" /home/$NEW_USER/.conky/i3_shortcuts/Gotham
sed -i "/mod+i\${goto 120}= Portergos installer/d" /home/$NEW_USER/.conky/i3_shortcuts/Gotham
sed -i "/\${font sans:bold:size=8}INSTALLERS \${hr 2}/d" /home/$NEW_USER/.conky/xfce_shortcuts/Gotham
sed -i "/mod+i\${goto 120}= Portergos installer/d" /home/$NEW_USER/.conky/xfce_shortcuts/Gotham
sed -i "/<Filename>offline_installer.desktop<\/Filename>/d" /home/$NEW_USER/.config/menus/xfce-applications.menu

sed -i "/\${font sans:bold:size=8}INSTALLERS \${hr 2}/d" /root/.conky/i3_shortcuts/Gotham
sed -i "/mod+i\${goto 120}= Portergos installer/d" /root/.conky/xfce_shortcuts/Gotham
sed -i "/\${font sans:bold:size=8}INSTALLERS \${hr 2}/d" /root/.conky/i3_shortcuts/Gotham
sed -i "/mod+i\${goto 120}= Portergos installer/d" /root/.conky/xfce_shortcuts/Gotham
sed -i "/<Filename>offline_installer.desktop<\/Filename>/d" /root/.config/menus/xfce-applications.menu

#.config/sxhkd
sed -i "/super + i/,/installer/"'d' /home/$NEW_USER/.config/sxhkd/sxhkdrc
sed -i "/super + i/,/installer/"'d' /root/.config/sxhkd/sxhkdrc

# Clean specific installer stuff
rm -rf /offline_installer
rm -rf /etc/skel/.local/share/applications/offline_installer.desktop
rm -rf /home/$NEW_USER/.local/share/applications/offline_installer.desktop

rm -rf /home/$NEW_USER/{.xinitrc,.xsession} 2>>/tmp/.errlog
rm -rf /home/$NEW_USER/.portergos_configs/{.xinitrc_i3,.xinitrc_xfce4,.xinitrc_openbox,.welcome_screen} 2>>/tmp/.errlog
rm -rf /root/{.xinitrc,.xsession} 2>>/tmp/.errlog
rm -rf /root/.portergos_configs/{.xinitrc_i3,.xinitrc_xfce4,.xinitrc_openbox,.welcome_screen} 2>>/tmp/.errlog
rm -rf /etc/skel/{.xinitrc,.xsession} 2>>/tmp/.errlog
rm -rf /etc/skel/.portergos_configs/{.xinitrc_i3,.xinitrc_xfce4,.xinitrc_openbox,.welcome_screen} 2>>/tmp/.errlog

sed -i "/if/,/fi/"'s/^/#/' /home/$NEW_USER/.bash_profile
sed -i "/if/,/fi/"'s/^/#/' /home/$NEW_USER/.zprofile
sed -i "/if/,/fi/"'s/^/#/' /root/.bash_profile
sed -i "/if/,/fi/"'s/^/#/' /root/.zprofile


# Grub still needs polishing. Looking for a solution when using calamares for multiple distros
sed -i "s/menuentry 'Arch Linux' - /menuentry 'Arch Linux' - LTS/"g /boot/grub/grub.cfg 2>/dev/null

# Split advanced options at grub menu
echo "GRUB_DISABLE_SUBMENU=y" >> /etc/default/grub >/dev/null

}

_check_install_mode(){

    if [ -f /tmp/run_once ] ; then
        local INSTALL_OPTION="ONLINE_MODE"
    else
        local INSTALL_OPTION="OFFLINE_MODE"
    fi

    case "$INSTALL_OPTION" in
        OFFLINE_MODE)
                _clean_archiso
                _sed_stuff
                _clean_offline_packages
            ;;

        ONLINE_MODE)
                # not implemented yet. For now run functions at "SCRIPT STARTS HERE"
                :
                # all systemd are enabled - can be specific offline/online in the future
            ;;
        *)
            ;;
    esac
}

_remove_ucode(){
    local ucode="$1"
    pacman -Q $ucode >& /dev/null && {
        pacman -Rsn $ucode --noconfirm >/dev/null
    }
}

_clean_up(){
    if [ -x /usr/bin/device-info ] ; then
        case "$(/usr/bin/device-info --cpu)" in
            GenuineIntel) _remove_ucode amd-ucode ;;
            *)            _remove_ucode intel-ucode ;;
        esac
    fi
}

########################################
########## SCRIPT STARTS HERE ##########
########################################

#_check_install_mode
_clean_archiso
_sed_stuff
_clean_offline_packages
_common_systemd
_portergos
_vbox
_clean_up

rm -rf /usr/bin/{calamares_switcher,cleaner_script.sh,chrooted_cleaner_script.sh,calamares_for_testers}
