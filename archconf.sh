#!/bin/bash


function check_info ()
{
  echo "check $* (enter to continue):"
  eval $@
  read ans
}

echo "[note] you linux kernel must be official from archlinux repositories."
check_info pacman -Q linux

echo "--------------------------------"
printf "configure network......(n to skip) "
read ans
if ! [ "$ans" = n -o "$ans" = N ]; then
  systemctl enable --now NetworkManager
  nmtui
fi

username=${username:-root}
echo "--------------------------------"
printf "create username......(n to skip) "
read ans
if ! [ "$ans" = n -o "$ans" = N ]; then
  printf "please input your username? "
  read ans
  useradd -m -G wheel $ans
  passwd $ans
  printf 'please uncomment "# %%wheel" to sudo (enter to continue). '
  read ans
  pacman -S sudo
  EDITOR=vim visudo
  username=$ans
fi

echo "--------------------------------"
printf "modify mirrorlist and install yay base-devel......(n to skip) "
read ans
if ! [ "$ans" = n -o "$ans" = N ]; then
  printf "To enable multilib repository, uncomment the [multilib],  enter to continue."
  read ans
  vim /etc/pacman.conf
  printf "\n[archlinuxcn]\n" >> /etc/pacman.conf
  echo 'Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch' >> /etc/pacman.conf
  echo 'Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch' >> /etc/pacman.conf
  pacman -Syy && pacman -S archlinuxcn-keyring archlinux-keyring
  printf "pacman-key reinit (if keyring errors, this fix it, or input n to skip): "
  read ans
  if ! [ "$ans" = n -o "$ans" = N ]; then
    pacman -Syu haveged
    systemctl enable --now haveged
    rm -rf /etc/pacman.d/gnupg
    pacman-key --init
    pacman-key --populate archlinux
    pacman-key --populate archlinuxcn
    pacman -S archlinuxcn-keyring archlinux-keyring
  fi
  pacman -S yay base-devel linux-headers
fi

echo "--------------------------------"
printf "pacman hook configure autoremove tips......(n to skip) "
read ans
if ! [ "$ans" = n -o "$ans" = N ]; then
  if ! [ "`ls /etc/pacman.d | grep -w hooks`" ]; then mkdir /etc/pacman.d/hooks;fi
  cat << "EOF" > /etc/pacman.d/hooks/20-autoremove-tips.hook
# autoremove tips when pacman post transaction

[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Depends = bash
When = PostTransaction
Exec = /usr/bin/bash -c "/usr/bin/pacman -Qtd && /usr/bin/echo '=> sudo pacman -Rns `pacman -Qdtq` to autoremove.' || :"

EOF
  cat /etc/pacman.d/hooks/20-autoremove-tips.hook
  printf "please check /etc/pacman.d/hooks/20-autoremove-tips.hook:(n to del) "
  read ans
  if [ "$ans" = n -o "$ans" = N ]; then rm /etc/pacman.d/hooks/20-autoremove-tips.hook;fi
fi

echo "--------------------------------"
echo "install bbswitch or acpi_call (choice one, bbswitch recommend)......"
printf "install bbswitch(only official linux kernel support, n to skip) "
read ans
if ! [ "$ans" = n -o "$ans" = N ]; then
  pacman -S bbswitch
  echo "# load bbswitch at boot" > /etc/modules-load.d/bbswitch.conf
  printf "bbswitch" >> /etc/modules-load.d/bbswitch.conf
fi
printf "install acpi_call(only official linux kernel support, n to skip) "
read ans
if ! [ "$ans" = n -o "$ans" = N ]; then
  pacman -S acpi_call
  echo "# load acpi_call at boot" > /etc/modules-load.d/acpi_call.conf
  printf "acpi_call" >> /etc/modules-load.d/acpi_call.conf
fi

echo "--------------------------------"
printf "hibernate configure with swap partion......(n to skip) "
read ans
if ! [ "$ans" = n -o "$ans" = N ]; then
  pacman -S --needed util-linux e2fsprogs
  if [ "`ls / | grep -w swapfile`" ]; then
    resume=`findmnt -no UUID -T /swapfile`
    resume_offset=`filefrag -v /swapfile | awk '{ if($1=="0:"){print substr($4, 1, length($4)-2)} }'`
  else
    resume=(`cat /etc/fstab | grep -w swap | grep -w defaults`)
    resume=${resume[0]:5}
    resume_offset=0
  fi
  cp /etc/default/grub /etc/default/grub.bak
  sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"resume=UUID=$resume resume_offset=$resume_offset /" /etc/default/grub
  cat /etc/default/grub | grep GRUB_CMDLINE_LINUX_DEFAULT
  printf "check GRUB_CMDLINE_LINUX_DEFAULT of grub (y to continue) "
  read ans
  if [ "$ans" = y -o "$ans" = Y ]; then
    grub-mkconfig -o /boot/grub/grub.cfg
    rm /etc/default/grub.bak
    cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak
    sed -i 's/^HOOKS=(\(base udev .* filesystems\)/HOOKS=(\1 resume/' /etc/mkinitcpio.conf
    cat /etc/mkinitcpio.conf | grep HOOKS
    printf "check HOOKS of mkinitcpio.conf (y to continue) "
    read ans
    if [ "$ans" = y -o "$ans" = Y ]; then
      mkinitcpio -P
      rm /etc/mkinitcpio.conf.bak
    else
      rm /etc/mkinitcpio.conf
      mv /etc/mkinitcpio.conf.bak /etc/mkinitcpio.conf
    fi
  else
    rm /etc/default/grub
    mv /etc/default/grub.bak /etc/default/grub
  fi
fi

echo "--------------------------------"
printf "install cpupower and input driver......(n to skip) "
read ans
if ! [ "$ans" = n -o "$ans" = N ]; then
  pacman -S --needed cpupower libinput xf86-input-libinput
  systemctl enable cpupower
  echo "you can watch cpufreq by: watch grep \\\"cpu MHz\\\" /proc/cpuinfo"
  echo "or real freq by: watch cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq"
  ls /usr/lib/modules/`uname -r`/kernel/drivers/cpufreq/
  printf "input module you select(without suffix) (enter or inut 'intel_pstate' to skip): "
  read cpufreq_module
  if [ "$cpufreq_module" -a "$cpufreq_module" != "acpi-cpufreq" ]; then
    cp /etc/default/grub /etc/default/grub.bak
    sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"module_blacklist=acpi-cpufreq /" /etc/default/grub
    cat /etc/default/grub | grep GRUB_CMDLINE_LINUX_DEFAULT
    printf "check GRUB_CMDLINE_LINUX_DEFAULT of grub (y to continue) "
    read ans
    if [ "$ans" = y -o "$ans" = Y ]; then
      grub-mkconfig -o /boot/grub/grub.cfg
      rm /etc/default/grub.bak
    else
      rm /etc/default/grub
      mv /etc/default/grub.bak /etc/default/grub
    fi
  fi
  if [ "$cpufreq_module" -a "$cpufreq_module" != "intel_pstate" ]; then
    cp /etc/default/grub /etc/default/grub.bak
    sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"intel_pstate=disable /" /etc/default/grub
    cat /etc/default/grub | grep GRUB_CMDLINE_LINUX_DEFAULT
    printf "check GRUB_CMDLINE_LINUX_DEFAULT of grub (y to continue) "
    read ans
    if [ "$ans" = y -o "$ans" = Y ]; then
      grub-mkconfig -o /boot/grub/grub.cfg
      rm /etc/default/grub.bak
    else
      rm /etc/default/grub
      mv /etc/default/grub.bak /etc/default/grub
    fi
  fi
  if [ "$cpufreq_module" ]; then
    echo "# load $cpufreq_module at boot" > /etc/modules-load.d/cpufreq-${cpufreq_module}.conf
    printf "$cpufreq_module" >> /etc/modules-load.d/cpufreq-${cpufreq_module}.conf
  fi
fi

echo "--------------------------------"
echo "install lspci lsusb utils......"
pacman -S --needed pciutils usbutils
echo "install p7zip for archiver utils......"
pacman -S --needed p7zip
echo "install basic filesystem tools......"
echo "using file manager with support gvfs, auto mount mtp devices."
pacman -S --needed e2fsprogs ntfs-3g dosfstools exfatprogs fuse2 fuse3 mtpfs gvfs-mtp

gpu_count=0
echo "--------------------------------"
printf "install GPU drivers......(n to skip) "
read ans
if ! [ "$ans" = n -o "$ans" = N ]; then
  lspci | grep -iE "3d|vga|nvidia"
  printf "Intel GPU driver with VA (y to install, n to skip): "
  read ans
  if [ "$ans" = y -o "$ans" = Y ]; then
    gpu_count=`expr $gpu_count + 1`
    pacman -S --needed mesa xf86-video-intel vulkan-intel libva-intel-driver libvdpau-va-gl intel-compute-runtime lib32-vulkan-intel lib32-mesa intel-gpu-tools
  fi
  printf "NVIDIA GPU driver with VA (y to install, p to nouveau, n to skip): "
  read ans
  if [ "$ans" = y -o "$ans" = Y ]; then
    gpu_count=`expr $gpu_count + 1`
    pacman -S --needed nvidia nvidia-prime nvidia-settings nvidia-utils opencl-nvidia lib32-nvidia-utils lib32-opencl-nvidia libva-vdpau-driver
  elif [ "$ans" = p -o "$ans" = P ]; then
    gpu_count=`expr $gpu_count + 1`
    yay -S nouveau-fw
    pacman -S --needed mesa xf86-video-nouveau lib32-mesa libva-mesa-driver mesa-vdpau
  fi
  printf "AMD GPU driver with VA (y to install, n to skip): "
  read ans
  if [ "$ans" = y -o "$ans" = Y ]; then
    gpu_count=`expr $gpu_count + 1`
    pacman -S --needed mesa xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau opencl-mesa lib32-vulkan-radeon lib32-mesa lib32-opencl-mesa
  fi
  printf "Virtualbox GPU driver (y to install, n to skip): "
  read ans
  if [ "$ans" = y -o "$ans" = Y ]; then
    gpu_count=`expr $gpu_count + 1`
    pacman -S --needed virtualbox-guest-utils mesa lib32-mesa
    systemctl enable --now vboxservice
  fi
  printf "Vmware GPU driver (y to install, n to skip): "
  read ans
  if [ "$ans" = y -o "$ans" = Y ]; then
    gpu_count=`expr $gpu_count + 1`
    pacman -S --needed mesa xf86-video-vmware xf86-input-vmmouse open-vm-tools lib32-mesa gtkmm3
    systemctl enable --now vmtoolsd
    systemctl neable --now vmware-vmblock-fuse
  fi
  printf "you want install pocl(hardware independent opencl, y to install)? "
  read ans
  if [ "$ans" = y -o "$ans" = Y ]; then
    pacman -S pocl
  fi
  pacman -S --needed vulkan-tools libva-utils vdpauinfo mesa-demos lib32-mesa-demos mesa-utils lib32-mesa-utils
  mkinitcpio -P
  check_info glxinfo -B
  check_info glxinfo32 -B
  check_info vulkaninfo --summary
  check_info vainfo
  check_info vdpauinfo
  if [ $gpu_count -ge 2 ]; then
    printf "install optimus-manager and configure......(n to skip) "
    read ans
    if ! [ "$ans" = n -o "$ans" = N ]; then
      yay -S optimus-manager
      cp /usr/share/optimus-manager.conf /etc/optimus-manager/
      printf "have intel and nvidia gpu shall optimus hybrid to use intel vaapi. "
      read ans
      vim /etc/optimus-manager/optimus-manager.conf
      systemctl enable optimus-manager
    fi
  fi
fi

echo "--------------------------------"
printf "install desktop environment......(n to skip) "
read ans
if ! [ "$ans" = n -o "$ans" = N ]; then
  pacman -S xorg-server
  printf "select desktop (LXDE,Xfce,MATE,LXQt,GNOME,KDE): "
  read ans
  if [ `expr match "$ans" "[L|l][X|x][D|d][E|e]"` -eq 4 ]; then
    pacman -S --needed lxde network-manager-applet leafpad xscreensaver
    systemctl enable lxdm
  elif [ `expr match "$ans" "[X|x][F|f][C|c][E|e]"` -eq 4 ]; then
    pacman -S --needed xfce4 xfce4-goodies lightdm network-manager-applet
    systemctl enable lightdm
  elif [ `expr match "$ans" "[M|m][A|a][T|t][E|e]"` -eq 4 ]; then
    pacman -S --needed mate mate-extra lightdm network-manager-applet
    systemctl enable lightdm
  elif [ `expr match "$ans" "[L|l][X|x][Q|q][T|t]"` -eq 4 ]; then
    pacman -S --needed sddm lxqt oxygen-icons network-manager-applet leafpad xscreensaver gvfs # openbox breeze-icons
    systemctl enable sddm
  elif [ `expr match "$ans" "[G|g][N|n][O|o][M|m][E|e]"` -eq 5 ]; then
    pacman -S --needed gnome gnome-extra
    systemctl enable gdm
  elif [ `expr match "$ans" "[K|k][D|d][E|e]"` -eq 3 ]; then
    pacman -S --needed sddm plasma plasma-nm kde-applications
    systemctl enable sddm
  fi
fi
pacman -S --needed alsa-utils pulseaudio pulseaudio-alsa
pacman -S --needed bluez-utils blueman pulseaudio-bluetooth
pacman -S --needed ttf-dejavu ttf-liberation noto-fonts-cjk

echo "--------------------------------"
echo "install input-method engine (fcitx5 recommend)......"
printf "fcitx5 install for input-method (n to skip) "
read ans
if ! [ "$ans" = n -o "$ans" = N ]; then
  pacman -S fcitx5-im
  printf "you need logout and login to fcitx5-configtool enable it. "
  read ans
  if ! [ "`ls -a /home/$username | grep -w .pam_environment`" ]; then 
    echo "GTK_IM_MODULE DEFAULT=fcitx" > /home/${username}/.pam_environment
    echo "QT_IM_MODULE  DEFAULT=fcitx" >> /home/${username}/.pam_environment
    echo "XMODIFIERS    DEFAULT=@im=fcitx" >> /home/${username}/.pam_environment
    echo "INPUT_METHOD  DEFAULT=fcitx" >> /home/${username}/.pam_environment
    echo "SDL_IM_MODULE DEFAULT=fcitx" >> /home/${username}/.pam_environment
  fi
fi
printf "fcitx install for input-method (n to skip) "
read ans
if ! [ "$ans" = n -o "$ans" = N ]; then
  pacman -S fcitx-im fcitx-configtool
  printf "you need logout and login to fcitx-configtool enable it. "
  read ans
  if ! [ "`ls -a /home/$username | grep -w .pam_environment`" ]; then 
    echo "GTK_IM_MODULE DEFAULT=fcitx" > /home/${username}/.pam_environment
    echo "QT_IM_MODULE  DEFAULT=fcitx" >> /home/${username}/.pam_environment
    echo "XMODIFIERS    DEFAULT=@im=fcitx" >> /home/${username}/.pam_environment
  fi
fi
printf "ibus install for input-method (n to skip) "
read ans
if ! [ "$ans" = n -o "$ans" = N ]; then
  pacman -S ibus
  read ans
  if ! [ "`ls -a /home/$username | grep -w .pam_environment`" ]; then 
    echo "GTK_IM_MODULE DEFAULT=ibus" > /home/${username}/.pam_environment
    echo "QT_IM_MODULE  DEFAULT=ibus" >> /home/${username}/.pam_environment
    echo "XMODIFIERS    DEFAULT=@im=ibus" >> /home/${username}/.pam_environment
  fi
fi

echo "--------------------------------"
echo "update system and packages......"
pacman -Syyu
echo "configure finish......"
