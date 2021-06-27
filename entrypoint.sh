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

set_output(){
    echo "::set-output name=$1::$2"
}

workdir="$GITHUB_WORKSPACE"
arch="$1"
compiler="$2"
defconfig="$3"
image="$4"
tag="${GITHUB_REF/refs\/*\//}"
repo_name="${GITHUB_REPOSITORY/*\/}"
zipper_path="${ZIPPER_PATH:-zipper}"
kernel_path="${KERNEL_PATH:-.}"
name="${NAME:-$repo_name}"
set_output hash "$(cd $kernel_path; git rev-parse HEAD)"
set_output name "$name"

msg "Updating container..."
apt update && apt upgrade -y
msg "Installing essential packages..."
apt install -y --no-install-recommends git make bc bison openssl \
    curl zip kmod cpio flex libelf-dev libssl-dev libtfm-dev wget
msg "Installing toolchain..."
if [[ $arch = "arm64" ]]; then
    arch_opts="ARCH=${arch} SUBARCH=${arch}"
    if [[ $compiler = gcc/* ]]; then
        ver="${compiler/gcc\/}"
        if ! apt install -y --no-install-recommends gcc-"$ver" g++-"$ver" gcc-"$ver"-aarch64-linux-gnu gcc-"$ver"-arm-linux-gnueabi; then
            err "Compiler package not found, refer to the README for details"
            exit 1
        fi
        ln -sf /usr/bin/gcc-"$ver" /usr/bin/gcc
        ln -sf /usr/bin/g++-"$ver" /usr/bin/g++
        ln -sf /usr/bin/aarch64-linux-gnu-gcc-"$ver" /usr/bin/aarch64-linux-gnu-gcc
        ln -sf /usr/bin/arm-linux-gnueabi-gcc-"$ver" /usr/bin/arm-linux-gnueabi-gcc
        export ARCH="$arch"
        export SUBARCH="$arch"
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
        make_opts=""
        host_make_opts=""
    elif [[ $compiler = clang/* ]]; then
        ver="${compiler/clang\/}"
        if ! apt install -y --no-install-recommends clang-"$ver" llvm-"$ver" binutils binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi; then
            err "Compiler package not found, refer to the README for details"
            exit 1
        fi
        ln -sf /usr/bin/clang-"$ver" /usr/bin/clang
        ln -sf /usr/bin/clang-"$ver" /usr/bin/clang++
        export ARCH="$arch"
        export SUBARCH="$arch"
        export CLANG_TRIPLE="aarch64-linux-gnu-"
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
        make_opts="CC=clang"
        host_make_opts="HOSTCC=clang HOSTCXX=clang++"
    elif [[ $compiler = proton-clang/* ]]; then
        ver="${compiler/proton-clang\/}"
        url="https://github.com/kdrag0n/proton-clang/archive/${ver}.tar.gz"
        if ! wget --no-check-certificate "$url" -O /tmp/proton-clang-"${ver}".tar.gz &>/dev/null; then
            err "Failed downloading toolchain, refer to the README for details"
            exit 1
        fi
        apt install -y --no-install-recommends libgcc-10-dev || exit 127
        tar xfv /tmp/proton-clang-"${ver}".tar.gz -C /
        cd /proton-clang-"${ver}"* || exit 127
        proton_path="$(pwd)"
        export PATH="$proton_path/bin:${PATH}"
        cd "$workdir"/"$kernel_path" || exit 127
        export ARCH="$arch"
        export SUBARCH="$arch"
        export CLANG_TRIPLE="aarch64-linux-gnu-"
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
        make_opts="CC=clang"
        host_make_opts="HOSTCC=clang HOSTCXX=clang++"
    else
        err "Unsupported toolchain string. refer to the README for more detail"
        exit 100
    fi
else
    err "Currently this action only supports arm64, refer to the README for more detail"
    exit 100
fi

start_time="$(date +%s)"
date="$(date +%d%m%Y-%I%M)"
cd "$workdir"/"$kernel_path" || exit 127
echo "make options:" $make_opts $host_make_opts
msg "Generating defconfig from \`make $defconfig\`..."
if ! make O=out $arch_opts $make_opts $host_make_opts "$defconfig"; then
    err "Failed generating .config, make sure it is actually available in arch/${arch}/configs/ and is a valid defconfig file"
    exit 2
fi
msg "Begin building kernel..."
if ! make O=out $arch_opts $make_opts $host_make_opts -j"$(nproc --all)"; then
    err "Failed building kernel, is the toolchain compatible with the kernel?"
    exit 3
fi
set_output elapsed_time "$(echo $(date +%s)-$start_time | bc)"
msg "Packaging the kernel..."
zip_filename="${name}-${tag}-${date}.zip"
if [[ -e "$workdir"/"$zipper_path" ]]; then
    cp out/arch/"$arch"/boot/"$image" "$workdir"/"$zipper_path"/"$image"
    cd "$workdir"/"$zipper_path" || exit 127
    rm -rf .git
    zip -r9 "$zip_filename" . || exit 127
    set_output outfile "$workdir"/"$zipper_path"/"$zip_filename"
    cd "$workdir" || exit 127
    exit 0
else
    msg "No zip template provided, releasing the kernel image instead"
    set_output outfile out/arch/"$arch"/boot/"$image"
    exit 0
fi
