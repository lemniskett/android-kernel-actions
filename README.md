# Android Kernel Actions
[![Shell check](https://github.com/lemniskett/android-kernel-actions/actions/workflows/check.yml/badge.svg)](https://github.com/lemniskett/android-kernel-actions/actions/workflows/check.yml)

Builds Android kernel from the kernel repository.
> Note: You don't have to fork this repository, see the [examples](#example-usage).

## Action Vars

### Inputs

| Input | Description |
| --- | --- |
| `arch` | Specify what Architecture target to use, currently only supports `arm64` |
| `compiler` | Specify which toochain to use |
| `defconfig` | Specify what defconfig command used to generate `.config` file |
| `image` | Specify what is the final build file, usually it's `Image.gz-dtb` or `Image-dtb` |

### Environment Variables

| Variable | Description |
| --- | --- |
| `NAME` | Specify the name of the release file, defaults to the name of the repository |
| `KERNEL_PATH` | Specify the path of the kernel source, defaults to `.` |
| `ZIPPER_PATH` | Specify the path of the zip template, defaults to `zipper` |
| `PYTHON_VERSION` | Specify the version of Python to use, either `3`, or `2`. defaults to `3` |

### Outputs

| Output | Description |
| --- | --- |
| `elapsed_time` | Time elapsed from building the kernel in seconds, excluding zipping and downloading toolchains |
| `outfile` | Path to the final build file |
| `hash` | Kernel commit hash |

## AnyKernel3

Put the AnyKernel3 template to `zipper`. Providing AnyKernel3 template is optional, the `outfile` output varies based on this. If AnyKernel3 template is provided, this Action will create a flashable zip file based on the AnyKernel3 template and the `outfile` output will be the path to the zipfile. if not the `outfile` will be the path to the kernel image. See the [examples](#example-usage).

## Getting the build

Use other action to actually get the file, for example, with [`ncipollo/release-action`](https://github.com/ncipollo/release-action):

```yml
- name: Release build
  uses: ncipollo/release-action@v1
  with:
    artifacts: ${{ steps.<step id>.outputs.outfile }}
    token: ${{ secrets.GITHUB_TOKEN }}
```

Or with [`appleboy/telegram-action`](https://github.com/appleboy/telegram-action):

```yml
- name: Release build
  uses: appleboy/telegram-action@master
  with:
    to: ${{ secrets.CHANNEL_ID }}
    token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    message: ${{ github.repository }} on ${{ github.sha }} is built!
    document: ${{ steps.<step id>.outputs.outfile }}
```

## Available toolchains

If you want to compile with Clang and LLVM without any of GNU's binutils, make sure your kernel source already supports LLVM options, otherwise compilation may fails. In that case, use clang toolchain with `/binutils`.

### ARM64

#### Ubuntu's GCC

For older GCC use v0.4.0 action version

- `gcc/9`
- `gcc/10`
- `gcc/11`
- `gcc/12`

#### Ubuntu's Clang

For older Clang use v0.4.0 action version

- `clang/11`, `clang/11/binutils`
- `clang/12`, `clang/12/binutils`
- `clang/13`, `clang/13/binutils`
- `clang/14`, `clang/14/binutils`
- `clang/15`, `clang/15/binutils`

#### [Proton Clang](https://github.com/kdrag0n/proton-clang)

- `proton-clang/<branch, commit hash or tag>`, `proton-clang/<branch, commit hash or tag>/binutils`
> Example : `proton-clang/master`, `proton-clang/09fb113/binutils`

#### [AOSP's Clang](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/)

- `aosp-clang/<branch>/<clang version>`, `aosp-clang/<branch>/<clang version>/binutils`
> Example : `aosp-clang/master/clang-r416183b`, `aosp-clang/android11-release/clang-r365631c/binutils`

## Example usage

### With [`ncipollo/release-action`](https://github.com/ncipollo/release-action)
```yml
name: Build on Tag

on:
  push:
    tags: '*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout kernel source
      uses: actions/checkout@v2

    - name: Checkout zipper
      uses: actions/checkout@v2
      with:
        repository: lemniskett/AnyKernel3
        path: zipper

    - name: Android kernel build
      uses: lemniskett/android-kernel-actions@master
      id: build
      env:
        NAME: Dark-Ages-Último
      with:
        arch: arm64
        compiler: gcc/10
        defconfig: vince_defconfig
        image: Image.gz-dtb

    - name: Release build
      uses: ncipollo/release-action@v1
      with:
        artifacts: ${{ steps.build.outputs.outfile }}
        token: ${{ secrets.GITHUB_TOKEN }}
```

### With [`appleboy/telegram-action`](https://github.com/appleboy/telegram-action)
```yml
name: Build on push master

on:
  push:
    branches: [ master ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout kernel source
      uses: actions/checkout@v2

    - name: Checkout zipper
      uses: actions/checkout@v2
      with:
        repository: lemniskett/AnyKernel3
        path: zipper

    - name: Android kernel build
      uses: lemniskett/android-kernel-actions@master
      id: build
      env:
        NAME: Dark-Ages-Último
      with:
        arch: arm64
        compiler: gcc/10
        defconfig: vince_defconfig
        image: Image.gz-dtb

    - name: Release build
      uses: appleboy/telegram-action@master
      with:
        to: ${{ secrets.CHANNEL_ID }}
        token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
        message: Kernel is built!, took ${{ steps.build.outputs.elapsed_time }} seconds.
        document: ${{ steps.build.outputs.outfile }}
```

## Troubleshooting

### Script `InvalidSyntax` exceptions

Your kernel source scripts might not support Python 3 yet, set `PYTHON_VERSION` environment variable to "2".

### Error codes

- `1`: Packages fails to install
- `2`: .config fails to be generated
- `3`: Build fails
- `100`: Unsupported usage
- `127`: Unexpected error
