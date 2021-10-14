# archlinux-install-shell
Archlinux installation script written according to archlinux wiki.

first get the archiso from official website.

second boot for the archiso and mount storage medium with the scripts.

third cd the workspace to directory of scripts and run "sh ./archinstall.sh"
any operation will ask you for confirm.
and it will install base system and chroot it to set bootloader.
so the mini system installed finish!

forth reboot and login root, you shuold cd workspace and run "./archconf.sh" to install system with graphics.

fifth if you want to install some packages, you can run archappconf.sh to improve you experience.
present the applications within is:
proxy tools
wine and configure
fcitx-sogoupinyin for chinese
wps-office for word processing
gimp for picture processing
ffmpeg for codec
audacious and feeluown-full for audio player
mpv smplayer svp with frame insertion for video player
qtscrcpy for android adb transmission screen
vmware-workstation for virtual machine
more applications need to be added in it.

make sure of you use archlinux kernel is linux.
and you time zone is China otherwise you need to change it for first reboot.
