#!/bin/bash

set -xeo pipefail

source $TOP_DIR/scripts/tools.sh

# 输出镜像和挂载点
OUTPUT_IMG=image-${BOARD}-raw-$(date +%y%m%d).img
MOUNT_POINT=tmp

# 文件系统
BOOT_IMG="boot.img"
ROOTFS_IMG="rootfs.img"
START_DEV="/dev/mmcblk0"
MODULE_DIR="$TOP_DIR/build/_module"
BLOCK_SIZE=512
PAD_SIZE=$((50 * 1024 * 2 * BLOCK_SIZE))
BOOT_PAD_SIZE=$((50 * 1024 * 2 * BLOCK_SIZE))
ROOTFS_PAD_SIZE=$((100 * 1024 * 2 * BLOCK_SIZE))

# 删除旧的镜像和挂载点
sudo umount ${MOUNT_POINT}/_boot || true
sudo umount ${MOUNT_POINT}/_rootfs || true
rm -rf image-${BOARD}*.img* $BOOT_IMG $ROOTFS_IMG $MOUNT_POINT
mkdir -p ${MOUNT_POINT}/{_boot,_rootfs} 

# 创建并格式化 boot 文件系统
mkdir -p boot_fs

# 填充 boot 文件系统
sudo cp $TOP_DIR/build/kernel/build/arch/arm64/boot/Image \
    $TOP_DIR/build/kernel/build/arch/arm64/boot/dts/$BOARD_DTS_FILE \
    boot_fs
sudo mv boot_fs/$(basename $TOP_DIR/build/kernel/build/arch/arm64/boot/dts/$BOARD_DTS_FILE)  boot_fs/${BOARD}.dtb
sudo mkdir -p boot_fs/extlinux
sudo bash -c 'cat > boot_fs/extlinux/extlinux.conf' << EOF 
label rockchip-kernel6.1
        kernel /Image
        fdt /${BOARD}.dtb
        append console=ttyS2,1500000 root=${START_DEV}p2 rw rootfstype=ext4 rootwait firmware_class.path=/vendor/etc/firmware/
EOF
cat boot_fs/extlinux/extlinux.conf
# 创建 boot 镜像
BOOT_IMG_SIZE=$(( $(sudo du -sb boot_fs | cut -f1) + PAD_SIZE))
# 判断 BOOT_IMG_SIZE 是否小于 100M
MAX_BOOT_SIZE=$((100 * 1024 * 1024)) # 100M
if [ "$BOOT_IMG_SIZE" -ge "$MAX_BOOT_SIZE" ]; then
    echo "Error: BOOT_IMG_SIZE exceeds 100M limit."
    exit 1
fi

fallocate -l $BOOT_IMG_SIZE $BOOT_IMG
mkfs.vfat -F 32 -n BOOT $BOOT_IMG
sudo mount -o loop $BOOT_IMG $MOUNT_POINT/_boot
sudo cp -a --no-dereference boot_fs/* $MOUNT_POINT/_boot
sudo umount $MOUNT_POINT/_boot

# 创建并格式化 rootfs 文件系统
mkdir -p rootfs_fs
sudo cp -a --no-dereference $TOP_DIR/build/alpine/* rootfs_fs

# 创建 rootfs 镜像
ROOTFS_IMG_SIZE=$(( $(sudo du -sb rootfs_fs | cut -f1) + ROOTFS_PAD_SIZE + PAD_SIZE))
fallocate -l $ROOTFS_IMG_SIZE $ROOTFS_IMG
mkfs.ext4 -L ROOTFS $ROOTFS_IMG
sudo mount -o loop $ROOTFS_IMG $MOUNT_POINT/_rootfs
sudo cp -a rootfs_fs/* $MOUNT_POINT/_rootfs
sudo sed -i '/boot/d' $MOUNT_POINT/_rootfs/etc/fstab
sudo echo "${START_DEV}p1  /boot  vfat  defaults  0  2" | sudo tee -a $MOUNT_POINT/_rootfs/etc/fstab
sudo umount $MOUNT_POINT/_rootfs

sudo rm -rf ${MOUNT_POINT}

# 创建固件镜像
FIRMWARE_SIZE=$((262144 * 512 + $ROOTFS_IMG_SIZE + $PAD_SIZE))
FIRMWARE_SIZE=$(( ($FIRMWARE_SIZE + 511) / 512 * 512 ))
fallocate -l $FIRMWARE_SIZE $OUTPUT_IMG

# 创建 GPT 分区表
sudo parted "$OUTPUT_IMG" mklabel gpt \
mkpart primary fat32 32768s 262143s \
mkpart primary ext4 262144s 100%

# 设置环回设备
LOOP_DEV=$(sudo losetup -f --show "$OUTPUT_IMG")
sudo partprobe "$LOOP_DEV"
du -sh $OUTPUT_IMG
# 将 boot 和 rootfs 镜像复制到固件镜像中
du -sh $BOOT_IMG
ls -l ${LOOP_DEV}
du -sh ${LOOP_DEV}p1
sudo dd if=$BOOT_IMG of="${LOOP_DEV}p1" conv=notrunc
sudo dd if=$ROOTFS_IMG of="${LOOP_DEV}p2" conv=notrunc

sudo losetup -d "$LOOP_DEV"

# 写入 uboot 和 idbloader
sudo dd if=$TOP_DIR/build/uboot/build/idbloader.img of="$OUTPUT_IMG" seek=64 conv=notrunc
sudo dd if=$TOP_DIR/build/uboot/build/uboot.itb of="$OUTPUT_IMG" seek=16384 conv=notrunc

# 显示镜像大小
ls -lh "$OUTPUT_IMG"

# 清理
sudo rm -rf boot_fs rootfs_fs
xz -6 -e -v -k -T 0 $OUTPUT_IMG

cp $OUTPUT_IMG $OUTPUT_DIR