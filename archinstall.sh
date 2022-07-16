#!/bin/sh


function connect_wifi ()
{
  ip a
  echo "--------------------------------"
  printf "connected wifi (n to skip)...... "
  read ans
  if ! [ "$ans" = n -o "$ans" = N ]; then
    rfkill unblock wifi
    printf "[General]\nEnableNetworkConfiguration=true" > /etc/iwd/main.conf
    systemctl restart iwd
    printf "wifi interface? "
    read ans
    ip link set $ans up
    echo "enter iwctl, manually connect:"
    echo "station wlan0 scan"
    echo "station wlan0 get-networks"
    echo "station wlan0 connect <SSID>"
    echo "station wlan0 show"
    iwctl
    systemctl restart systemd-networkd
    systemctl restart systemd-resolved
    ip a
  fi
  ping -c 4 archlinux.org
}

function mount_other_exec ()
{
  if ! [ "$*" ]; then 
    echo "--------------------------------"
    echo "mount other or exec......"
  fi
  echo "manual mkpart and format, and mount......(short command list:)"
  echo "help     show help info."
  echo "mkgpt    create a gpt partition label."
  echo "mkmbr    create a mbr partition label."
  echo "mkfat    format a fat32 filesystem."
  echo "mkext4    format a ext4 filesystem by lazy_init."
  if [ "$*" ]; then
    echo "mntroot    mount linux root to /mnt."
    echo "mntefi    mount efi partition to /mnt/boot/efi."
    echo "mnthome    mount linux home to /mnt/home."
    echo "mntboot    mount linux boot to /mnt/boot."
  fi
  printf "please input command to exec (cfdisk or parted...) (exit to quit): "
  while [ 1 ]
  do
    read ans
    if [ "$ans" = mkgpt ]; then
      printf "input device like sda (n to cancel): "
      read ans
      if ! [ "$ans" = n -o "$ans" = N ]; then parted -s /dev/$ans mklabel gpt;fi
    elif [ "$ans" = mkmbr ]; then
      printf "input device like sda (n to cancel): "
      read ans
      if ! [ "$ans" = n -o "$ans" = N ]; then parted -s /dev/$ans mklabel msdos;fi
    elif [ "$ans" = mkfat ]; then
      printf "device path (n to cancel)? "
      read ans
      if ! [ "$ans" = n -o "$ans" = N ]; then mkfs.fat -F32 $ans;fi
    elif [ "$ans" = mkext4 ]; then
      printf "device path (n to cancel)? "
      read ans
      if ! [ "$ans" = n -o "$ans" = N ]; then
        mkfs.ext4 -b 4096 -E lazy_itable_init=0,lazy_journal_init=0 $ans
      fi
    elif [ "$ans" = mntroot -a "$*" ]; then
      printf "device path (n to cancel)? "
      read ans
      if ! [ "$ans" = n -o "$ans" = N ]; then mount $ans /mnt;fi
    elif [ "$ans" = mntefi ]; then
      echo "please mount root first and this will mount on boot/efi."
      printf "device path (n to cancel)? "
      read ans
      if ! [ "$ans" = n -o "$ans" = N ]; then
        if ! [ "`ls /mnt | grep -w boot`" ]; then mkdir /mnt/boot;fi
        if ! [ "`ls /mnt/boot | grep -w efi`" ]; then mkdir /mnt/boot/efi;fi
        mount $ans /mnt/boot/efi
      fi
    elif [ "$ans" = mnthome ]; then
      printf "device path (n to cancel)? "
      read ans
      if ! [ "$ans" = n -o "$ans" = N ]; then
        if ! [ "`ls /mnt | grep -w home`" ]; then mkdir /mnt/home;fi
        mount $ans /mnt/home
      fi
    elif [ "$ans" = mntboot ]; then
      echo "note that mount_boot must before mount_efi!"
      printf "device path (n to cancel)? "
      read ans
      if ! [ "$ans" = n -o "$ans" = N ]; then
        if ! [ "`ls /mnt | grep -w boot`" ]; then mkdir /mnt/boot;fi
        mount $ans /mnt/boot
      fi
    elif [ "$ans" = help ]; then
      echo "manual mkpart and format, and mount......(short command list:)"
      echo "help     show help info."
      echo "mkgpt    create a gpt partition label."
      echo "mkmbr    create a mbr partition label."
      echo "mkfat    format a fat32 filesystem."
      echo "mkext4    format a ext4 filesystem by lazy_init."
      echo "mntroot    mount linux root to /mnt."
      echo "mntefi    mount efi partition to /mnt/boot/efi."
      echo "mnthome    mount linux home to /mnt/home."
      echo "mntboot    mount linux boot to /mnt/boot."
    elif [ "$ans" = exit ]; then
      break
    else
      eval $ans
    fi
    printf "archinstall (or input bash)? "
  done
}

function parted_and_mount ()
{
  echo "--------------------------------"
  echo "create partition......"
  printf "please input install device like sda (any for manual): "
  read ans
  nvme_part=
  if [ ${ans:0:2} != sd ]; then
    nvme_part=p
  fi
  if [ "$ans" != any ]; then
    parted -s /dev/$ans mklabel gpt
    parted -s /dev/$ans mkpart primary fat32 2048s 512m set 1 esp on
    parted -s /dev/$ans mkpart primary ext4 512m 100%
    mkfs.fat -F32 /dev/${ans}${nvme_part}1
    mkfs.ext4 -b 4096 -E lazy_itable_init=0,lazy_journal_init=0 /dev/${ans}${nvme_part}2
    echo "mount root and efi......"
    mount /dev/${ans}${nvme_part}2 /mnt
    mkdir /mnt/boot
    mount /dev/${ans}${nvme_part}1 /mnt/boot
  else
    mount_other_exec 1
  fi
}

function swapfile_mount ()
{
  echo "--------------------------------"
  echo "create swapfile and mount......"
  printf "please input swapfile size(M), or a swap partion device: "
  read ans
  if [ $ans -gt 0 ] 2> /dev/null; then
    if [ $ans != 0 ]; then
      dd if=/dev/zero of=/mnt/swapfile bs=1M count=$ans status=progress
      chmod 0600 /mnt/swapfile
      mkswap -U clear /mnt/swapfile
      swapon /mnt/swapfile
    fi
  else
    mkswap $ans
    swapon $ans
  fi
}

function modify_mirrorlist ()
{
  echo "--------------------------------"
  echo "modify mirrorlist......"
  echo "Server = $1" > /tmp/mirrorlist
  cat /etc/pacman.d/mirrorlist >> /tmp/mirrorlist
  rm /etc/pacman.d/mirrorlist
  mv /tmp/mirrorlist /etc/pacman.d/mirrorlist
  pacman -Syy
}

function install_base_system ()
{
  echo "--------------------------------"
  echo "install base system......"
  pacstrap /mnt base linux linux-firmware vim networkmanager os-prober iwd
  echo "note: mdadm is must for raid, lvm2 must for lvm, exit to quit!"
  while [ 1 ]
  do
    printf "install packages? name (exit to quit): "
    read ans
    if [ "$ans" = exit ]; then
      break
    fi
    pacstrap /mnt $ans
  done
}

function call_genfstab ()
{
  echo "--------------------------------"
  printf "genfstab......(n to skip): "
  read ans
  if ! [ "$ans" = n -o "$ans" = N ]; then
    genfstab -U /mnt >> /mnt/etc/fstab
  fi
  cat /mnt/etc/fstab
  printf "please input any keys to continue: "
  read ans
}

function main ()
{
  connect_wifi
  ls /sys/firmware/efi/efivars
  echo "you must install for a uefi system, please check!"
  printf "please input any keys to continue (n to skip to mount other): "
  read ans
  if ! [ "$ans" = n -o "$ans" = N ]; then
    lsblk
    printf "please input any keys to continue (n to skip to modify mirrorlist): "
    read ans
    if ! [ "$ans" = n -o "$ans" = N ]; then
      echo "--------------------------------"
      echo "sync time......"
      timedatectl set-ntp true
      parted_and_mount
    fi
    #modify_mirrorlist 'http://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch'
    reflector -c China -a 6 --sort rate --save /etc/pacman.d/mirrorlist
    pacman -Syy
    install_base_system
  fi
  lsblk
  mount_other_exec
  swapfile_mount
  call_genfstab
  cp ./archconf.sh /mnt/home/
  cp ./archappconf.sh /mnt/home/
  chmod +x /mnt/home/archconf.sh
  chmod +x /mnt/home/archappconf.sh
  bash archroot.sh
  printf "please input any keys to continue: "
  read ans
  umount -R /mnt
  echo "installed finish......"
}

main
