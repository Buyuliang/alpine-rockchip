#!/bin/bash

set -euo pipefail

# 检查至少有一个参数
if [ $# -lt 1 ]; then
    echo "Usage: $0 {uboot|kernel|ramdisk|alpine|rootfs|update|all} [board]"
    exit 1
fi

export TOP_DIR=$(dirname $(realpath $0))
echo "TOP_DIR: $TOP_DIR"
BUILD_DIR="$TOP_DIR/build"
export OUTPUT_DIR=$BUILD_DIR/output
mkdir -p $BUILD_DIR $OUTPUT_DIR > /dev/null 2>&1

# 设置 BOARD 作为全局环境变量
export BOARD=${2:-blade3}
source $TOP_DIR/packages/board/$BOARD
echo "Building for board: $BOARD"

function build_uboot() {
    echo "Building U-Boot for $BOARD..."
    pushd $BUILD_DIR
    bash $TOP_DIR/scripts/build_uboot.sh "$@"
    popd
}

function build_fit_boot() {
    echo "Building Fit Boot for $BOARD..."
    BOOT_ITS="$TOP_DIR/packages/configs/boot.its"
    pushd $BUILD_DIR/kernel
    cp ${BOOT_ITS} build/boot.its
    ../rkbin/tools/mkimage -f build/boot.its -E -p 0x800 build/boot.img
    cp build/boot.img ${OUTPUT_DIR}
    popd
}

function build_sign_boot() {
    echo "Building Sign Boot for $BOARD..."
    cp ${OUTPUT_DIR}/boot.img ${BUILD_DIR}/uboot
    pushd ${BUILD_DIR}/uboot
    build_uboot --spl-new --boot_img boot.img
    cp ${BUILD_DIR}/uboot/boot.img ${OUTPUT_DIR}/boot.img
    popd
}

function build_kernel() {
    echo "Building Kernel for $BOARD..."
    pushd $BUILD_DIR
    bash $TOP_DIR/scripts/build_kernel.sh
    popd
}

function build_alpine() {
    echo "Building Alpine Linux for $BOARD..."
    pushd $BUILD_DIR
    bash $TOP_DIR/scripts/build_alpinefs.sh
    popd
}

function build_rootfs() {
    echo "Building rootfs for $BOARD..."
    pushd $BUILD_DIR
    bash $TOP_DIR/scripts/build_rootfs.sh
    popd
}

function build_ramdisk() {
    echo "Building Ramdisk for $BOARD..."
    pushd $BUILD_DIR
    bash $TOP_DIR/scripts/build_ramdisk.sh
    popd
}

function build_update_image() {
    echo "Building Image for $BOARD..."
    pushd $BUILD_DIR
    bash $TOP_DIR/scripts/build_update.sh
    popd
}

function build_all() {
    echo "Building All for $BOARD..."
    # build_kernel
    build_alpine && build_rootfs && build_ramdisk
    build_uboot --spl-new
    build_fit_boot && build_sign_boot
    build_update_image
}

ARG=${1:-all}

case "$ARG" in
    uboot)
        time build_uboot --spl-new
        ;;
    kernel)
        time build_kernel
        ;;
    fit-boot)
        time build_fit_boot
        ;;
    sign-boot)
        time build_sign_boot
        ;;
    ramdisk)
        time build_ramdisk
        ;;
    alpine)
        time build_alpine
        ;;
    rootfs)
        time build_rootfs
        ;;
    update)
        time build_update_image
        ;;
    all)
        time build_all
        ;;
    *)
        echo "Invalid argument: $ARG"
        echo "Usage: $0 {uboot|kernel|fit-boot|sign-boot|ramdisk|alpine|rootfs|update|all} [board]"
        exit 1
        ;;
esac

unset BOARD