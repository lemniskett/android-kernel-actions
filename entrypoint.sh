#!/usr/bin/env bash

msg(){
    echo "==> $*"
}

err(){
    echo "==> $*" 1>&2
}

outfile(){
    echo "::set-output name=outfile::$*"
}

workdir="$GITHUB_WORKSPACE"
arch="$1"
compiler="$2"
zipper="$3"
defconfig="$4"
image="$5"
tag="${GITHUB_REF/refs\/tags\//}"
repo_name="${GITHUB_REPOSITORY/*\/}"
zipper_path="zipper"

msg "Updating container..."
apt update && apt upgrade -y
msg "Installing essential packages..."
apt install -y git make bc bison curl zip kmod cpio flex libelf-dev libssl-dev libtfm-dev
msg "Installing toolchain..."
if [[ $arch = "arm64" ]]; then
    if [[ $compiler = gcc-* ]]; then
        if ! apt install -y "$compiler" "$compiler"-aarch64-linux-gnu "$compiler"-arm-linux-gnueabi; then
            err "Compiler package not found, refer to the README for details"
            exit 1
        fi
        ln -sf /usr/bin/"$compiler" /usr/bin/gcc
        ln -sf /usr/bin/aarch64-linux-gnu-"$compiler" /usr/bin/aarch64-linux-gnu-gcc
        ln -sf /usr/bin/arm-linux-gnueabi-"$compiler" /usr/bin/arm-linux-gnueabi-gcc
        export ARCH="$arch"
        export SUBARCH="$arch"
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
        make_opts="O=out"
    elif [[ $compiler = clang-* ]]; then
        compiler_version="${compiler/*-}"
        if ! apt install -y "$compiler" lld-"$compiler_version" gcc gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi; then
            err "Compiler package not found, refer to the README for details"
            exit 1
        fi
        ln -sf /usr/bin/"$compiler" /usr/bin/clang
        ln -sf /usr/bin/ld.lld-"$compiler_version" /usr/bin/ld.lld
        ln -sf /usr/bin/llvm-ar-"$compiler_version" /usr/bin/llvm-ar
        ln -sf /usr/bin/llvm-nm-"$compiler_version" /usr/bin/llvm-nm
        ln -sf /usr/bin/llvm-strip-"$compiler_version" /usr/bin/llvm-strip
        ln -sf /usr/bin/llvm-objcopy-"$compiler_version" /usr/bin/llvm-objcopy
        ln -sf /usr/bin/llvm-objdump-"$compiler_version" /usr/bin/llvm-objdump
        ln -sf /usr/bin/llvm-readelf-"$compiler_version" /usr/bin/llvm-readelf
        export ARCH="$arch"
        export SUBARCH="$arch"
        export CLANG_TRIPLE="aarch64-linux-gnu-"
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
        make_opts="O=out CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm STRIP=llvm-strip OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf"
    else 
        err "Currently this action only supports gcc-* and clang-*, refer to the README for more detail"
        exit 100
    fi
else
    err "Currently this action only supports arm64, refer to the README for more detail"
    exit 100
fi

msg "Generating defconfig from \`make $defconfig\`..."
if ! make "$make_opts" "$defconfig"; then
    err "Failed generating .config, make sure it is actually available in arch/${arch}/configs/ and is a valid defconfig file"
    exit 2
fi
msg "Begin building kernel..."
if ! make "$make_opts" -j"$(nproc --all)"; then
    err "Failed building kernel, is the toolchain compatible with the kernel?"
    exit 3
fi
msg "Packaging the kernel..."
zip_filename="${repo_name}-${tag}.zip"
git clone https://"$zipper".git $zipper_path || exit 127
cp out/arch/"$arch"/boot/"$image" "$zipper_path"/"$image"
cd $zipper_path || exit 127
zip -r9 "$zip_filename" . -x '*.git' || exit 127
outfile "$zipper_path"/"$zip_filename"
cd "$workdir" || exit 127