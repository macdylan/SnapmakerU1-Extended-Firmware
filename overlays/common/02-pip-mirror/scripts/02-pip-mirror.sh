#!/bin/bash

if [[ -z "$CREATE_FIRMWARE" ]]; then
  echo "Error: This script should be run within the create_firmware.sh environment."
  exit 1
fi

set -eo pipefail

echo ">> Set Pypi mirror"
chroot_firmware.sh "$ROOTFS_DIR" /usr/bin/pip3 config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple
