#!/usr/bin/env bash

msg(){
    echo
    echo "==>"
    echo "==> $*"
    echo "==>"
    echo
}

err(){
    echo
    echo "==>"
    echo "==> $*" 1>&2
    echo "==>"
    echo
}

outfile(){
    echo "::set-output name=outfile::$*"
}

workdir="$GITHUB_WORKSPACE"
arch="$1"
compiler="$2"
defconfig="$3"
image="$4"
tag="${GITHUB_REF/refs\/tags\//}"
repo_name="${GITHUB_REPOSITORY/*\/}"
zipper_path="${ZIPPER_PATH:-zipper}"

msg "Updating container..."
apt update && apt upgrade -y
msg "Installing essential packages..."
apt install -y --no-install-recommends git make bc bison openssl \
    curl zip kmod cpio flex libelf-dev libssl-dev libtfm-dev wget
msg "Installing toolchain..."
if [[ $arch = "arm64" ]]; then
    if [[ $compiler = gcc/* ]]; then
        ver="${compiler/gcc\/}"
        if ! apt install -y --no-install-recommends gcc-"$ver" gcc-"$ver"-aarch64-linux-gnu gcc-"$ver"-arm-linux-gnueabi; then
            err "Compiler package not found, refer to the README for details"
            exit 1
        fi
        ln -sf /usr/bin/gcc-"$ver" /usr/bin/gcc
        ln -sf /usr/bin/aarch64-linux-gnu-gcc-"$ver" /usr/bin/aarch64-linux-gnu-gcc
        ln -sf /usr/bin/arm-linux-gnueabi-gcc-"$ver" /usr/bin/arm-linux-gnueabi-gcc
        export ARCH="$arch"
        export SUBARCH="$arch"
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
        make_opts="O=out ARCH=${arch} SUBARCH=${arch}"
    elif [[ $compiler = clang/* ]]; then
        ver="${compiler/clang\/}"
        if ! apt install -y --no-install-recommends clang-"$ver" llvm-"$ver" binutils binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi; then
            err "Compiler package not found, refer to the README for details"
            exit 1
        fi
        ln -sf /usr/bin/clang-"$ver" /usr/bin/clang
        export ARCH="$arch"
        export SUBARCH="$arch"
        export CLANG_TRIPLE="aarch64-linux-gnu-"
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
        make_opts="O=out ARCH=${arch} SUBARCH=${arch} CC=clang HOSTCC=clang HOSTCXX=clang++"
    else
        err "Unsupported toolchain string. refer to the README for more detail"
        exit 100
    fi
else
    err "Currently this action only supports arm64, refer to the README for more detail"
    exit 100
fi

echo "make options: " $make_opts
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
if [[ -e "$zipper_path" ]]; then
    cp out/arch/"$arch"/boot/"$image" "$zipper_path"/"$image"
    cd "$zipper_path" || exit 127
    rm -rf .git
    zip -r9 "$zip_filename" . || exit 127
    outfile "$zipper_path"/"$zip_filename"
    cd "$workdir" || exit 127
    exit 0
else
    msg "No zip template provided, releasing the kernel image instead"
    outfile out/arch/"$arch"/boot/"$image"
    exit 0
fi