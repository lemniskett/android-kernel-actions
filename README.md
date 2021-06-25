# Android Kernel Actions

Builds Android kernel from the kernel repository.

## Action inputs

| Input | Description |
| --- | --- |
| `arch` | Specify what Architecture target to use, currently only supports `arm64` |
| `compiler` | Specify which compiler to use, currently only supports `gcc-*` from Ubuntu repository |
| `zipper` | Specify the git repository of the flashable zip template, using [osm0sis's AnyKernel3](https://github.com/osm0sis/AnyKernel3) as base is recommended |
| `defconfig` | Specify what defconfig command to generate `.config` file |
| `image` | Specify what is the final build file, usually it's `Image.gz-dtb` or '`Image-dtb`' |

## Getting the build

You can use other actions to grab the flashable zip file and releases it.

## Available toolchains

### ARM64

- `gcc-7`
- `gcc-8`
- `gcc-9`
- `gcc-10`
- `clang-6.0`
- `clang-7`
- `clang-8`
- `clang-9`
- `clang-10`
- `clang-11`

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
    - name: Checkout code
      uses: actions/checkout@v2
    
    - name: Android kernel build
      uses: lemniskett/android-kernel-actions@master
      id: build
      with:
        arch: 'arm64'
        compiler: 'gcc-9'
        zipper: 'github.com/lemniskett/AnyKernel3'
        defconfig: 'vince_defconfig'
        image: 'Image.gz-dtb'

    - uses: ncipollo/release-action@v1
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