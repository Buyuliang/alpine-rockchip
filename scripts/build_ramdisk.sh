#! /bin/bash

set -xeo pipefail

LINUX_SECURITYDM_TOOLS="${TOP_DIR}/tools/linux_securitydm.tar.gz"
LINUX_SECURITYDM_DIR="${TOP_DIR}/build/linux_securitydm"
DM_CONFIG="${TOP_DIR}/packages/configs/dm_config"

if [ ! -d "${LINUX_SECURITYDM_DIR}" ]; then
    mkdir -p ${LINUX_SECURITYDM_DIR}
    tar -xzvf ${LINUX_SECURITYDM_TOOLS} -C ${LINUX_SECURITYDM_DIR}
fi

pushd ${LINUX_SECURITYDM_DIR}
cp ${DM_CONFIG} ${LINUX_SECURITYDM_DIR}/config
bash build.sh

cp ${LINUX_SECURITYDM_DIR}/output/{ramdisk.img,encrypted.img} ${OUTPUT_DIR}

popd
