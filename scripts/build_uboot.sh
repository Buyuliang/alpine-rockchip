#! /bin/bash

set -euo pipefail

source $TOP_DIR/scripts/apply_patch.sh

RKBIN_DIR="$TOP_DIR/build/rkbin"
UBOOT_DIR="$TOP_DIR/build/uboot"
UBOOT_BUILD_DIR="$UBOOT_DIR/build"
UBOOT_PATCH_DIR="$TOP_DIR/patch/uboot/$BOARD"
RKBIN_COMMIT_ID="a2a0b89b6c8c612dca5ed9ed8a68db8a07f68bc0"
UBOOT_COMMIT_ID="63c55618fbdc36333db4cf12f7d6a28f0a178017"
KEY_DIR="$TOP_DIR/packages/keys"

if [ ! -d "$RKBIN_DIR" ]; then
    git clone --depth=1 https://github.com/mixtile-rockchip/rkbin.git -b master $RKBIN_DIR
    pushd $RKBIN_DIR
    git fetch --depth 1 origin $RKBIN_COMMIT_ID
    git checkout $RKBIN_COMMIT_ID
    popd
fi

if [ ! -d "$UBOOT_DIR" ]; then
    git clone --depth=1 https://github.com/mixtile-rockchip/u-boot.git -b next-dev $UBOOT_DIR
    pushd $UBOOT_DIR
    git fetch --depth 1 origin $UBOOT_COMMIT_ID
    git checkout $UBOOT_COMMIT_ID
    popd
fi

pushd $UBOOT_DIR

SERIES_FILE="$UBOOT_PATCH_DIR/series"
SERIES_FLAG=1

if [ -d $UBOOT_PATCH_DIR ] && [ "$(ls -A $UBOOT_PATCH_DIR)" ] && [ $SERIES_FLAG == 1 ]; then
    apply_patches "$SERIES_FILE" "$UBOOT_PATCH_DIR"
fi

# add key
cp -r ${KEY_DIR} ${UBOOT_DIR}

time bash make.sh blade3 "$@"

if [ -d $UBOOT_PATCH_DIR ] && [ "$(ls -A $UBOOT_PATCH_DIR)" ] && [ $SERIES_FLAG == 1 ]; then
    reverse_patches "$SERIES_FILE" "$UBOOT_PATCH_DIR"
fi

loader_file=$(ls *loader*.bin 2>/dev/null | head -n1)
if [ -z "${loader_file}" ]; then
    echo "error: no find  *loader* file" >&2
    exit 1
fi

ln -snf "../uboot/${loader_file}" "${OUTPUT_DIR}/MiniLoaderAll.bin" && \
echo "created: ${OUTPUT_DIR}/MiniLoaderAll.bin -> ../uboot/${loader_file}"

ln -snf ../uboot/uboot.img ${OUTPUT_DIR}/uboot.img
echo "created: ${OUTPUT_DIR}/uboot.img -> ../uboot/uboot.img"
popd
