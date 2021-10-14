#!/bin/sh


echo "set time zone......"
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
timedatectl set-ntp true
hwclock --systohc

echo "localization......"
printf "\nen_GB.UTF-8 UTF-8" >> /etc/locale.gen
printf "\nen_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
printf "LANG=en_GB.UTF-8" > /etc/locale.conf
printf "please input hostname: "
read ans
printf $ans > /etc/hostname
echo "127.0.0.1	localhost" >> /etc/hosts
echo "::1		localhost" >> /etc/hosts
echo "127.0.1.1	${ans}.localdomain	${ans}" >> /etc/hosts

passwd

printf "install microcode intel or amd (n to skip)? "
read ans
if [ "$ans" = intel ]; then
  pacman -S intel-ucode
elif [ "$ans" = amd ]; then
  pacman -S amd-ucode.
fi

echo "install grub bootloader......"
pacman -S grub efibootmgr
printf "please input efi-directory: "
read ans
printf "please input bootloader-id: "
read ans2
grub-install --target=x86_64-efi --efi-directory=$ans --bootloader-id=$ans2
printf "\nGRUB_DISABLE_OS_PROBER=false\n" >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
