#!/bin/sh

echo "--------------------------------"
echo "set time zone......"
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
arch-chroot /mnt timedatectl set-ntp true
arch-chroot /mnt hwclock --systohc

echo "--------------------------------"
echo "localization......"
if [ `tail -n 1 /mnt/etc/locale.gen | wc -l` == 0 ]; then
  echo >> /mnt/etc/locale.gen
fi
if ! [ "`cat /mnt/etc/locale.gen | grep -v '#' | grep 'en_GB.UTF-8 UTF-8'`" ]; then
  echo "en_GB.UTF-8 UTF-8" >> /mnt/etc/locale.gen
fi
if ! [ "`cat /mnt/etc/locale.gen | grep -v '#' | grep 'en_US.UTF-8 UTF-8'`" ]; then
  echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
fi
arch-chroot /mnt locale-gen
printf "LANG=en_GB.UTF-8" > /mnt/etc/locale.conf
printf "please input hostname: "
read ans
printf $ans > /mnt/etc/hostname
echo "127.0.0.1	localhost" >> /mnt/etc/hosts
echo "::1		localhost" >> /mnt/etc/hosts
echo "127.0.1.1	${ans}.localdomain	${ans}" >> /mnt/etc/hosts

arch-chroot /mnt passwd

printf "install microcode (input intel or amd, n to skip)? "
read ans
if [ "$ans" = intel ]; then
  arch-chroot /mnt pacman -S intel-ucode
elif [ "$ans" = amd ]; then
  arch-chroot /mnt pacman -S amd-ucode.
fi

echo "--------------------------------"
echo "mkinitcpio hooks......"
if [ "`arch-chroot /mnt pacman -Q | grep -w lvm2`" ]; then
  cp /mnt/etc/mkinitcpio.conf /mnt/etc/mkinitcpio.conf.bak
  sed -i 's/^HOOKS=(\(base udev .* block\)/HOOKS=(\1 lvm2/' /mnt/etc/mkinitcpio.conf
  cat /mnt/etc/mkinitcpio.conf | grep HOOKS
  printf "check HOOKS of mkinitcpio.conf (y to continue) "
  read ans
  if [ "$ans" = y -o "$ans" = Y ]; then
    arch-chroot /mnt mkinitcpio -p linux
    rm /mnt/etc/mkinitcpio.conf.bak
  else
    rm /mnt/etc/mkinitcpio.conf
    mv /mnt/etc/mkinitcpio.conf.bak /mnt/etc/mkinitcpio.conf
  fi
fi
if [ "`arch-chroot /mnt pacman -Q | grep -w mdadm`" ]; then
  cp /mnt/etc/mkinitcpio.conf /mnt/etc/mkinitcpio.conf.bak
  sed -i 's/^HOOKS=(\(base udev .* block\)/HOOKS=(\1 mdadm_udev/' /mnt/etc/mkinitcpio.conf
  cat /mnt/etc/mkinitcpio.conf | grep HOOKS
  printf "check HOOKS of mkinitcpio.conf (y to continue) "
  read ans
  if [ "$ans" = y -o "$ans" = Y ]; then
    arch-chroot /mnt mkinitcpio -p linux
    rm /mnt/etc/mkinitcpio.conf.bak
  else
    rm /mnt/etc/mkinitcpio.conf
    mv /mnt/etc/mkinitcpio.conf.bak /mnt/etc/mkinitcpio.conf
  fi
fi

echo "--------------------------------"
echo "install grub bootloader......"
arch-chroot /mnt pacman -S grub efibootmgr
printf "please input efi-directory: "
read ans
printf "please input bootloader-id: "
read ans2
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=$ans --bootloader-id=$ans2
printf "\nGRUB_DISABLE_OS_PROBER=false\n" >> /mnt/etc/default/grub
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
