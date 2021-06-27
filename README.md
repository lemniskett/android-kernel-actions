# Android Kernel Actions

Builds Android kernel from the kernel repository.

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

### Outputs

| Output | Description |
| --- | --- |
| `elapsed_time` | Time elapsed from building the kernel in seconds, excluding zipping and downloading toolchains |
| `outfile` | Path to the final build file |
| `hash` | Kernel commit hash |
| `name` | Name of the build, specified from repo name or `NAME` environment variable |

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

### ARM64

#### Ubuntu's GCC

- `gcc/7`
- `gcc/8`
- `gcc/9`
- `gcc/10`

#### Ubuntu's Clang (using `binutils`)

- `clang/6.0`
- `clang/7`
- `clang/8`
- `clang/9`
- `clang/10`
- `clang/11`

#### [Proton Clang](https://github.com/kdrag0n/proton-clang) (using `binutils` from proton-clang repository)

- `proton-clang/master`
- `proton-clang/<commit hash or tag>`

## Example usage

### With [`ncipollo/release-action@v1`](https://github.com/ncipollo/release-action)
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
        NAME: Dark-Ages-Último-Tweaks
      with:
        arch: arm64
        compiler: clang-10
        defconfig: vince_defconfig
        image: Image.gz-dtb

    - name: Release build
      uses: ncipollo/release-action@v1
      with:
        artifacts: ${{ steps.build.outputs.outfile }}
        token: ${{ secrets.GITHUB_TOKEN }}
```

## Troubleshooting

### Error codes

- `1`: Packages fails to install
- `2`: .config fails to be generated
- `3`: Build fails
- `100`: Unsupported usage
- `127`: Unexpected error
