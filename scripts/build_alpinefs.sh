#! /bin/bash

set -euo pipefail

ROOTFS_PAK="alpine.tar.gz"
ROOTFS_DIR="$TOP_DIR/build/alpine"
MODULE_DIR="$TOP_DIR/build/_module"
PACKAGES_DIR="$TOP_DIR/packages/alpine"
PACKAGES_CONFIG_DIR="$TOP_DIR/packages/configs"

if [ ! -f "$ROOTFS_PAK" ]; then
    wget -O $ROOTFS_PAK https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/aarch64/alpine-minirootfs-3.22.0-aarch64.tar.gz
    mkdir -p $ROOTFS_DIR
    tar -xvf $ROOTFS_PAK -C $ROOTFS_DIR
fi

sudo mkdir -p "$ROOTFS_DIR/etc"
echo "nameserver 8.8.8.8 " | sudo tee $ROOTFS_DIR/etc/resolv.conf > /dev/null
echo "" > $ROOTFS_DIR/etc/apk/repositories
# sudo  echo "https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.22/main/" >> $ROOTFS_DIR/etc/apk/repositories
# sudo  echo "https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.22/community/" >> $ROOTFS_DIR/etc/apk/repositories
# sudo  echo "http://mirrors.tuna.tsinghua.edu.cn/alpine/edge/testing" >> $ROOTFS_DIR/etc/apk/repositories

sudo  echo "https://dl-cdn.alpinelinux.org/alpine/v3.22/main/" >> $ROOTFS_DIR/etc/apk/repositories
sudo  echo "https://dl-cdn.alpinelinux.org/alpine/v3.22/community" >> $ROOTFS_DIR/etc/apk/repositories
sudo  echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> $ROOTFS_DIR/etc/apk/repositories


export NEW_HOSTNAME="$BOARD_HOSTNAME"

sudo cp $PACKAGES_DIR/* $ROOTFS_DIR -a

### prompt message ###
# gcompat 提供了 glibc 兼容层

sudo chroot $ROOTFS_DIR /bin/sh -c "apk update && \
			apk add alpine-base openssh-server openssh-client-common mkinitfs parted e2fsprogs-extra chrony bash gptfdisk \
			acpid-openrc dhcpcd lsblk pciutils networkmanager networkmanager-cli ethtool \
			hdparm gcompat fio i2c-tools eudev usbutils libdrm-dev libpng-dev sudo stress-ng openvpn openvpn-openrc wireguard-tools \
			util-linux openssh tcpdump iperf3 docker docker-cli docker-compose iptables ip6tables bzip2-dev avahi avahi-tools dbus && \
			rc-update add sshd default && \
			rc-update add networking default && \
			rc-update add sysctl boot && \
			rc-update add hostname boot && \
			rc-update add chronyd boot && \
			rc-update add acpid default && \
			rc-update add dhcpcd default && \
			rc-update add docker default && \
			rc-update add dbus default && \
			rc-update add avahi-daemon default && \
			rc-update add networkmanager boot && \
			rc-update add syslog boot && \
			rc-update add modules boot"

sudo cp $MODULE_DIR/* $ROOTFS_DIR -a
sudo mkdir -p $ROOTFS_DIR/boot
sudo sed -i 's|#ttyS0::respawn:/sbin/getty -L 115200 ttyS0 vt100|console::respawn:-/bin/sh|' $ROOTFS_DIR/etc/inittab
sudo sed -i 's|^console::respawn:.*|console::respawn:/sbin/getty -n -l /bin/login 1500000 /dev/ttyFIQ0 vt100|' "$ROOTFS_DIR/etc/inittab"
sudo sed -i '/^tty[1-6]::respawn:\/sbin\/getty 38400 tty[1-6]$/d' "$ROOTFS_DIR/etc/inittab"
echo ttyFIQ0 >> $ROOTFS_DIR/etc/securetty

cat << EOF | sudo chroot $ROOTFS_DIR /bin/sh
chmod a+x /etc/init.d/first-boot /usr/bin/first-boot
chown root:root /var/empty
rc-update add first-boot sysinit

chmod a+x /usr/bin/usb_ncm.sh /etc/init.d/usb_ncm
rc-update add usb_ncm default

chmod a+x /usr/bin/misc_part.sh /etc/init.d/misc_block
rc-update add misc_block default

chmod a+x /usr/bin/updateEngine /etc/init.d/updateAB
rc-update add updateAB default

# bee
chmod a+x /usr/bin/bee-extra /usr/bin/mount_usb.sh /usr/bin/umount_usb.sh

# mount userdata
chmod +x /etc/local.d/mount_userdata.start
rc-update add local default

# 去掉 /etc/sudoers 文件中 'sudo' 组的注释
sed -i 's/^# %sudo ALL=(ALL:ALL) ALL/%sudo ALL=(ALL:ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# add user
export NEW_USER=mixtile
export NEW_PWD=mixtile
adduser -D -s /bin/sh \$NEW_USER
echo "\$NEW_USER:\$NEW_PWD" | chpasswd

# set root passwd
echo "root:root" | chpasswd

# 获取所有组
GROUPS=\$(cut -d: -f1 /etc/group)

# 将用户添加到每个组
for GROUP in \$GROUPS; do
    addgroup \$GROUP \$NEW_USER
done

# 添加用户到 sudo 组
addgroup \$NEW_USER wheel

# hostname
echo $NEW_HOSTNAME > /etc/hostname
sed -i 's/^\(127\.0\.0\.1\|\:\:1\)[[:space:]]\+localhost[[:space:]]\+.*$/\1\tlocalhost blade3/' /etc/hosts
sed -i 's/^::1\t/::1\t\t/' /etc/hosts

mkdir -p /userdata && chmod 777 /userdata

# /etc/fstab
sed -i '/[[:space:]]\/tmp[[:space:]]/d' /etc/fstab
echo 'tmpfs   /tmp    tmpfs   defaults,size=100%  0  0' | sudo tee -a /etc/fstab

sed -i '/[[:space:]]\/userdata[[:space:]]/d' /etc/fstab
echo '/dev/mmcblk0p7    /userdata    ext4    defaults    0  2' | sudo tee -a /etc/fstab

# ssh
mkdir -p /home/mixtile/.ssh
touch /home/mixtile/.ssh/authorized_keys
chmod 700 /home/mixtile/.ssh
chmod 600 /home/mixtile/.ssh/authorized_keys
chown -R mixtile:mixtile /home/mixtile/.ssh
chown root:root /var/empty
chmod 711 /var/empty

EOF
