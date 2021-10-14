#!/bin/bash
# this shell do not use as root
# only sudo for privilege

function install_packages ()
{
  printf "install application: $* (n to skip) "
  read ans
  if ! [ "$ans" = n -o "$ans" = N ]; then
    yay -S $@
  fi
}

function check_info ()
{
  printf "check $* (enter to continue): "
  $@
  read ans
}

old_ALL_PROXY=$ALL_PROXY

printf "install proxy tools for network......(n to skip) "
read ans
if ! [ "$ans" = n -o "$ans" = N ]; then
  install_packages v2ray qv2ray proxychains-ng
  echo "please configure qv2ray kernel settings and socks5 proxy at 1088 port."
  echo "v2ray core path is /usr/bin/v2ray."
  echo "v2ray assets directory is /usr/share/v2ray."
  read ans
  qv2ray
  printf "set proxychains.conf to use socks5 proxy at 1088 port. "
  read ans
  sudo vim /etc/proxychains.conf
  echo "install_packages qv2ray-plugin-ssr-git qv2ray-plugin-trojan-git qv2ray-plugin-trojan-go-git qv2ray-plugin-naiveproxy-git qv2ray-plugin-command cgproxy"
  echo "this packages recommend install from git compiler."
  read ans
  export ALL_PROXY=socks5://127.0.0.1:1088
fi

install_packages aurman

echo "set .bashrc alias......(n to skip) "
read ans
if ! [ "$ans" = n -o "$ans" = N ]; then
  if [ `tail -n 1 /home/${USER}/.bashrc | wc -l` == 0 ]; then
    echo >> /home/${USER}/.bashrc
  fi
  if [ `pacman -Q | grep -w optimus-manager` ]; then
    echo "alias gpuprime='optimus-manager --switch'" >> /home/${USER}/.bashrc
  fi
  if [ `pacman -Q | grep -w qv2ray` ]; then
    echo "alias envproxy='export ALL_PROXY=socks5://127.0.0.1:1088'" >> /home/${USER}/.bashrc
    echo "alias unproxy='unset ALL_PROXY'" >> /home/${USER}/.bashrc
  fi
  if [ `pacman -Q | grep -w proxychains-ng` ]; then
    echo "alias p='proxychains'" >> /home/${USER}/.bashrc
    echo "alias sp='sudo proxychains'" >> /home/${USER}/.bashrc
  fi
  cat /home/${USER}/.bashrc
  read ans
fi

echo "install application......"

echo "install wine......(n to skip)"
echo "note: may it bug that only intel gpu on wine but use hybrid or only nvidia can run it."
echo "some of fonts you should install to display chinese words."
echo "put fonts file to /usr/share/fonts and update by:"
printf "use 'fc-cache -vf' to update font cache. "
read ans
if ! [ "$ans" = n -o "$ans" = N ]; then
  sudo pacman -S --needed wine wine-gecko wine-mono winetricks zenity
  sudo pacman -S --needed lib32-alsa-lib lib32-alsa-plugins lib32-libpulse lib32-openal
  sudo pacman -S --needed lib32-mpg123 lib32-libpng lib32-giflib lib32-gnutls
  winecfg
  cat << EOF > /tmp/winefontsmoothing
REGEDIT4

[HKEY_CURRENT_USER\Control Panel\Desktop]
"FontSmoothing"="2"
"FontSmoothingOrientation"=dword:00000001
"FontSmoothingType"=dword:00000002
"FontSmoothingGamma"=dword:00000578
EOF
  wine regedit /tmp/winefontsmoothing 2> /dev/null
  sudo setcap cap_net_raw+epi /usr/bin/wine-preloader
fi

# input-method
if [ `pacman -Qq fcitx` ]; then
  install_packages fcitx-sogoupinyin
fi

# word processing
# [sloved] system DPI is asymmetric. WPS Office may have display issues by ttf-wps-fonts
install_packages wps-office ttf-wps-fonts

# picture processing
install_packages gimp

# codec
install_packages ffmpeg

# audio player
install_packages audacious
install_packages feeluown-full

# video player
install_packages mpv-git smplayer svp

# android adb transmission screen
install_packages qtscrcpy

# virtual machine
printf "install application: vmware-workstation (n to skip) "
read ans
if ! [ "$ans" = n -o "$ans" = N ]; then
  yay -S vmware-workstation
  modprobe -a vmw_vmci vmmon
  systemctl enable --now vmware-networks
  systemctl enable --now vmware-usbarbitrator
  # vmware-hostd is abandoned since version 16
  # systemctl enable vmware-hostd
  printf "you may need reboot to use vmware command. "
  read ans
fi

yay
export ALL_PROXY=$old_ALL_PROXY
