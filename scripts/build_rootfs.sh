#!/bin/bash

set -xeo pipefail

source $TOP_DIR/scripts/tools.sh

# 输出镜像和挂载点
MOUNT_POINT=tmp

# 文件系统
ROOTFS_IMG="rootfs.img"
MODULE_DIR="$TOP_DIR/build/_module"
BLOCK_SIZE=512
PAD_SIZE=$((50 * 1024 * 2 * BLOCK_SIZE))
BOOT_PAD_SIZE=$((50 * 1024 * 2 * BLOCK_SIZE))
ROOTFS_PAD_SIZE=$((100 * 1024 * 2 * BLOCK_SIZE))

# 删除旧的镜像和挂载点
sudo umount ${MOUNT_POINT}/_rootfs || true
rm -rf $ROOTFS_IMG $MOUNT_POINT
mkdir -p ${MOUNT_POINT}/_rootfs

# 创建并格式化 rootfs 文件系统
mkdir -p rootfs_fs
sudo find rootfs_fs -type l -delete 2>/dev/null || true
sudo cp -a --no-dereference $TOP_DIR/build/alpine/* rootfs_fs

# 创建 rootfs 镜像
ROOTFS_IMG_SIZE=$(( $(sudo du -sb rootfs_fs | cut -f1) + ROOTFS_PAD_SIZE + PAD_SIZE))
fallocate -l $ROOTFS_IMG_SIZE $ROOTFS_IMG
mkfs.ext4 -L ROOTFS $ROOTFS_IMG
sudo mount -o loop $ROOTFS_IMG $MOUNT_POINT/_rootfs
sudo cp -a rootfs_fs/* $MOUNT_POINT/_rootfs
sudo umount $MOUNT_POINT/_rootfs

sudo rm -rf ${MOUNT_POINT}

ln -sf ../${ROOTFS_IMG} ${OUTPUT_DIR}/rootfs.img
# 显示镜像大小
ls -lh ${ROOTFS_IMG}
