#!/usr/bin/env bash

msg(){
    echo "==>"
    echo "==> $*"
    echo "==>"
}

err(){
    echo "==>"
    echo "==> $*" 1>&2
    echo "==>"
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
apt install -y --no-install-recommends git make bc bison openssl \
    curl zip kmod cpio flex libelf-dev libssl-dev libtfm-dev
msg "Installing toolchain..."
if [[ $arch = "arm64" ]]; then
    if [[ $compiler = gcc-* ]]; then
        if ! apt install -y --no-install-recommends "$compiler" "$compiler"-aarch64-linux-gnu "$compiler"-arm-linux-gnueabi; then
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
        make_opts="O=out ARCH=$arch SUBARCH=$arch"
    elif [[ $compiler = clang-* ]]; then
        compiler_version="${compiler/*-}"
        if ! apt install -y --no-install-recommends "$compiler" binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi llvm-"$compiler_version"; then
            err "Compiler package not found, refer to the README for details"
            exit 1
        fi
        ln -sf /usr/bin/"$compiler" /usr/bin/clang
        export ARCH="$arch"
        export SUBARCH="$arch"
        export CLANG_TRIPLE="aarch64-linux-gnu-"
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
        make_opts="O=out ARCH=$arch SUBARCH=$arch CC=clang HOSTCC=clang HOSTCXX=clang++"
    else 
        err "Currently this action only supports gcc-* and clang-*, refer to the README for more detail"
        exit 100
    fi
else
    err "Currently this action only supports arm64, refer to the README for more detail"
    exit 100
fi

echo "make options: " $make_opts
msg "Cleaning from the previous run..."
make $make_opts mrproper
msg "Generating defconfig from \`make $defconfig\`..."
if ! make $make_opts "$defconfig"; then
    err "Failed generating .config, make sure it is actually available in arch/${arch}/configs/ and is a valid defconfig file"
    exit 2
fi
date="$(date +%d%m%Y-%I%M)"
msg "Begin building kernel..."
if ! make $make_opts -j"$(nproc --all)"; then
    err "Failed building kernel, is the toolchain compatible with the kernel?"
    exit 3
fi
msg "Packaging the kernel..."
zip_filename="${NAME:-$repo_name}-${tag}-${date}.zip"
git clone --depth 1 https://"$zipper".git $zipper_path || exit 127
cp out/arch/"$arch"/boot/"$image" "$zipper_path"/"$image"
cd $zipper_path || exit 127
rm -rf .git
zip -r9 "$zip_filename" . || exit 127
outfile "$zipper_path"/"$zip_filename"
cd "$workdir" || exit 127