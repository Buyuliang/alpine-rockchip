#!/bin/sh

# 显示调试信息输出位置（可改为 /dev/console 看输出）
MSG_OUTPUT=/dev/console
#MSG_OUTPUT=/dev/null
DEBUG() {
    echo $1 > $MSG_OUTPUT
}

# 支持的块设备类型
BLOCK_TYPE_SUPPORTED="mmcblk flash"

# 检查设备类型是否受支持
check_device_is_supported() {
    for i in $BLOCK_TYPE_SUPPORTED; do
        if echo $(basename $1) | grep -q "$i"; then
            echo $1
            return 0
        fi
    done
}

# 查找指定名字的 raw 分区设备
find_raw_partition() {
    local target=$1
    local target_dev=
    local partname=

    while true; do
        for dev in /sys/class/block/*; do
            target_dev=$(check_device_is_supported $dev)
            if [ ! -z "$target_dev" ]; then
                partname=$(grep PARTNAME $target_dev/uevent | sed "s#.*PARTNAME=##")
                if [ "$partname" = "$target" ]; then
                    echo "$(basename $target_dev)"
                    return 0
                fi
            fi
        done
    done
}

DEBUG "BAD KEY FETCH -> try to find misc"
MISC_BLOCK=$(find_raw_partition "misc")
DEBUG "find misc -> $MISC_BLOCK"
ln -s /dev/$MISC_BLOCK /dev/block/by-name/misc