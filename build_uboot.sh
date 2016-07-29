#!/bin/bash

set -e
set -x

test -d $TARGET_DIR || mkdir -p $TARGET_DIR

pushd $UBOOT_DIR
make ARCH=arm distclean O=$UBOOT_DIR/output
make ARCH=arm $UBOOT_DEFCONFIG O=$UBOOT_DIR/output
make ARCH=arm EXTRAVERSION="-$BUILD_VERSION" -j$JOBS O=$UBOOT_DIR/output

pushd output
cp `find . -name "env_common.o"` copy_env_common.o
if [ "$BOOTLOADER_SINGLEIMAGE" == "1" ]; then
	${CROSS_COMPILE}objcopy -O binary --only-section=.rodata.default_environment `find . -name "copy_env_common.o"`
else
	${CROSS_COMPILE}objcopy -O binary --only-section=.rodata `find . -name "copy_env_common.o"`
fi
tr '\0' '\n' < copy_env_common.o | grep '=' > default_envs.txt
cp default_envs.txt default_envs.txt.orig
tools/mkenvimage -s 16384 -o params.bin default_envs.txt

# Generate recovery param
sed -i -e 's/rootdev=.*/rootdev=1/g' default_envs.txt
sed -i -e 's/bootcmd=run .*/bootcmd=run recoveryboot/g' default_envs.txt
tools/mkenvimage -s 16384 -o params_recovery.bin default_envs.txt

# Generate mmcboot param
cp default_envs.txt.orig default_envs.txt
sed -i -e 's/bootcmd=run .*/bootcmd=run mmcboot/g' default_envs.txt
tools/mkenvimage -s 16384 -o params_mmcboot.bin default_envs.txt

# Generate sd-boot param
cp default_envs.txt.orig default_envs.txt
sed -i -e 's/rootdev=.*/rootdev=1/g' default_envs.txt
tools/mkenvimage -s 16384 -o params_sdboot.bin default_envs.txt

# Generate sd-vboot param
sed -i -e 's/bootcmd=run .*/bootcmd=run vboot/g' default_envs.txt
tools/mkenvimage -s 16384 -o params_sdvboot.bin default_envs.txt

# Generate vboot param
cp default_envs.txt.orig default_envs.txt
sed -i -e 's/bootcmd=run .*/bootcmd=run vboot/g' default_envs.txt
tools/mkenvimage -s 16384 -o params_vboot.bin default_envs.txt

sed -i -e 's/bootcmd=run .*/bootcmd=run recoveryvboot/g' default_envs.txt
tools/mkenvimage -s 16384 -o params_recovery_vboot.bin default_envs.txt

rm copy_env_common.o default_envs.txt default_envs.txt.orig

cp u-boot.bin $TARGET_DIR
chmod 664 params.bin params_*.bin
cp params.bin params_* $TARGET_DIR
cp u-boot $TARGET_DIR
[ -e u-boot.dtb ] && cp u-boot.dtb $TARGET_DIR
if [ "$UBOOT_SPL" != "" ]; then
	cp spl/$UBOOT_SPL $TARGET_DIR
fi
cp tools/mkimage $TARGET_DIR

PLAIN_VERSION=`cat include/generated/version_autogenerated.h | grep "define PLAIN_VERSION" | awk -F \" '{print $2}'`
export UBOOT_VERSION="U-Boot $PLAIN_VERSION"

sed -i "s/BUILD_UBOOT=.*/BUILD_UBOOT=${UBOOT_VERSION}/" $TARGET_DIR/artik_release

popd
rm -rf output

popd
