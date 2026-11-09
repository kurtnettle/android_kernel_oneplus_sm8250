#!/bin/sh
set -Eeuo pipefail

KERNEL_DIR=$(pwd)

DEVICE="kona-perf"

mkdir -vp out

IAMATHOME="${IAMATHOME:-false}"

if [[ "$IAMATHOME" == "true" ]]; then
    mkdir -vp ".ccache"
    chmod 700 ".ccache"

    export USE_CCACHE=1
    export CCACHE_EXEC="$(which ccache)"
    export CCACHE_DIR=".ccache"

    ccache -M 50G
    ccache -o compression=true

    export KBUILD_BUILD_USER="kurtnettle"
    export KBUILD_BUILD_HOST="home"
fi

export ARCH=arm64
export PATH=$(pwd)/llvm-21/bin:$PATH

build_kernel() {
    echo "-----------------------------------------------"
    echo "Beginning kernel compilation for $DEVICE..."
    echo "-----------------------------------------------"

    BUILD_VAR="-j$(nproc) -C $(pwd) O=$(pwd)/out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1"

    cat "arch/arm64/configs/vendor/oplus.config" "arch/arm64/configs/vendor/ksu.config" "arch/arm64/configs/vendor/${DEVICE}_defconfig" > arch/arm64/configs/temp_defconfig

    sed -i 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"-Axon\"/' arch/arm64/configs/temp_defconfig

    echo "
CONFIG_THINLTO=y
# CONFIG_LTO_NONE is not set
CONFIG_LTO_CLANG=y
    " >> arch/arm64/configs/temp_defconfig
        
    make $BUILD_VAR temp_defconfig
    rm arch/arm64/configs/temp_defconfig

    make $BUILD_VAR
}

prepare_ak3() {
    cd AnyKernel3/

    cat <<'EOF'> anykernel.sh
properties() { '
kernel.string=AxonKernel by kurtnettle @ xda-developers
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=OnePlus8
device.name2=instantnoodle
'; } # end properties

boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

BLOCK=boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

. tools/ak3-core.sh;

dump_boot;
write_boot;
EOF

    mv -v "$KERNEL_DIR/out/arch/arm64/boot/Image" Image
}

package() {
    cd AnyKernel3/
    zip -r ../AxonKernel_op8_$(date +"%Y%m%d-%H%M%S").zip .
}

build_kernel
prepare_ak3

if [[ "$IAMATHOME" == "true" ]]; then
    package
fi