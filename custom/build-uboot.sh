#!/bin/bash

set -e

# === Configuration ===
SDK_ENV="/home/anpa8480/frdm-ubuntu/sdk/environment-setup-armv8a-poky-linux"
UBOOT_REPO="https://github.com/nxp-imx/uboot-imx.git"
UBOOT_HASH="de16f4f1722"
UBOOT_DIR="uboot-imx"
PATCHES_DIR="/home/anpa8480/frdm-ubuntu/custom/patch"

ATF_REPO="https://github.com/nxp-imx/imx-atf.git"
ATF_COMMIT="28affcae957cb8194917b5246276630f9e6343e1"
ATF_DIR="imx-atf"

OPTEE_REPO="https://github.com/nxp-imx/imx-optee-os.git"
OPTEE_COMMIT="612bc5a642a4608d282abeee2349d86de996d7ee"
OPTEE_DIR="optee_os"
OPTEE_BUILD_DIR="out/arm-plat-imx"

MKIMG_REPO="https://github.com/nxp-imx/imx-mkimage.git"
MKIMG_COMMIT="4c2e5b25232f5aa003976ddca9d1d2fb9667beb1"
MKIMG_DIR="imx-mkimage"

# === Step 0: Source the SDK environment ===
if [ ! -f "$SDK_ENV" ]; then
    echo "❌ SDK environment file not found at: $SDK_ENV"
    exit 1
fi

echo "✅ Sourcing SDK environment: $SDK_ENV"
source "$SDK_ENV"

# Resolve SDK sysroot path
SDKPATH=$(dirname "$(dirname "$SDKTARGETSYSROOT")")

# === Step 1: Clone and patch U-Boot ===
if [ ! -d "$UBOOT_DIR" ]; then
    echo "📦 Cloning U-Boot from NXP..."
    git clone "$UBOOT_REPO" "$UBOOT_DIR"
    cd "$UBOOT_DIR"
    echo "🔀 Checking out U-Boot commit: $UBOOT_HASH"
    git fetch --all
    git checkout "$UBOOT_HASH" -b "$UBOOT_HASH" || git checkout "$UBOOT_HASH"
    echo "📌 Applying U-Boot FRDM patches..."
    git am "$PATCHES_DIR"/0002-*.patch
    git am "$PATCHES_DIR"/0003-*.patch || echo "✅ 0003 skipped (optional)"
    git am "$PATCHES_DIR"/0004-*.patch || echo "✅ 0004 skipped (partial patch for i.MX91)"
    cd ..
fi

# === Step 2: Build TF-A ===
if [ ! -d "$ATF_DIR" ]; then
    echo "🛠️ Cloning TF-A..."
    git clone "$ATF_REPO" "$ATF_DIR"
fi

cd "$ATF_DIR"
git fetch --all
git checkout "$ATF_COMMIT"

echo "🔨 Building TF-A (bl31)..."
make PLAT=imx93 \
     CROSS_COMPILE="${CROSS_COMPILE}" \
     LD="${CROSS_COMPILE}gcc" \
     LDFLAGS="-Wl,--no-warn-rwx-segment" \
     bl31 -j$(nproc)

cp build/imx93/release/bl31.bin ../$UBOOT_DIR/
cd ..

# === Step 3: Build OP-TEE ===
if [ ! -d "$OPTEE_DIR" ]; then
    echo "🔧 Cloning OP-TEE..."
    git clone "$OPTEE_REPO" "$OPTEE_DIR"
fi

cd "$OPTEE_DIR"
git fetch --all
git checkout "$OPTEE_COMMIT"

echo "🔨 Building OP-TEE (tee.bin)..."
python3 -m venv venv
source venv/bin/activate
pip install cryptography pyelftools

echo "export CROSS_COMPILE=$CROSS_COMPILE && export SDKPATH=$SDKPATH && export OPTEE_BUILD_DIR=$OPTEE_BUILD_DIR"
SYSROOT=/home/anpa8480/frdm-ubuntu/sdk/sysroots/armv8a-poky-linux
LIBGCC_DIR="$SYSROOT/lib/aarch64-poky-linux/13.3.0"
PATH="$(pwd)/venv/bin:$PATH" \
LIBGCC_LOCATE_CFLAGS="-L${SDKPATH}/sysroots/armv8a-poky-linux/usr/lib/aarch64-poky-linux/13.3.0" \
LDFLAGS="-L${SDKPATH}/sysroots/armv8a-poky-linux/usr/lib/aarch64-poky-linux/13.3.0" \
make -j$(nproc) \
  V=1 \
  COMPILER=gcc \
  PLATFORM=imx-mx93evk \
  CFG_ARM64_core=y \
  CROSS_COMPILE64="${CROSS_COMPILE}" \
  CROSS_COMPILE_core="${CROSS_COMPILE}" \
  CROSS_COMPILE_ta_arm64="${CROSS_COMPILE}" \
  OPTEE_CLIENT_EXPORT="${SYSROOT}/usr" \
  TEEC_EXPORT="${SYSROOT}/usr" \
  NOWERROR=1 \
  ta-targets=ta_arm64 \
  O="${OPTEE_BUILD_DIR}" \
  ARCH=arm \
  LIBGCC_LOCATE_CFLAGS="-L${LIBGCC_DIR}" \
  LDFLAGS="--sysroot=${SYSROOT} -L${LIBGCC_DIR}" \
  CFLAGS="--sysroot=${SYSROOT}" \
  -C .

cp "${OPTEE_BUILD_DIR}/core/tee.bin" ../$UBOOT_DIR/
cd ..

# === Step 4: Build U-Boot ===
cd "$UBOOT_DIR"
echo "⚙️  Configuring U-Boot with patched FRDM defconfig..."
make distclean
make imx93_11x11_frdm_defconfig

echo "🏗️  Building U-Boot..."
make -j$(nproc)

echo "✅ U-Boot build (with bl31.bin and tee.bin) complete."
cd ..

if [ ! -d "$MKIMG_DIR" ]; then
    echo "🔧 Cloning mkimage..."
    git clone "$MKIMG_REPO" "$MKIMG_DIR"
    cd "$MKIMG_DIR"
    git fetch --all
    echo "🔀 Checking out mkimage commit: $MKIMG_COMMIT"
    git checkout "$MKIMG_COMMIT"
    cp ../patch/lpddr* iMX93
    cp ../uboot-imx/spl/u-boot-spl.bin iMX93
    cp ../uboot-imx/u-boot.bin iMX93
    cp ../uboot-imx/bl31.bin iMX93
    make SOC=iMX93 flash_singleboot_no_ahabfw
    dd if=iMX93/flash.bin of=bootable.img bs=1K seek=32 conv=fsync
else
    echo "$MKIMG_DIR present"
fi
