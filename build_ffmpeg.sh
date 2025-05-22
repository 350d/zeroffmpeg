#!/usr/bin/env bash
set -euo pipefail
set -x

# Debug information
echo "=== ENVIRONMENT ==="
env
echo "=== PATH ==="
echo "$PATH"
echo "=== COMPILERS ==="
echo "CC=$CC"
echo "AS=$AS"
which "$CC" || echo "[$CC not found]"
which as   || echo "[as not found]"

# Force assembler through gcc
export AS="$CC"

# Default variables (override by exporting before execution)
: "${CROSS_TRIPLE:=armv6-unknown-linux-gnueabihf}"
# Use QEMU_LD_PREFIX if set for accurate sysroot
: "${SYSROOT:=${QEMU_LD_PREFIX:-/usr/${CROSS_TRIPLE}}}"
: "${X264_PREFIX:=/usr/local}"
: "${WORKDIR:=$(pwd)/build}"

# Export cross-toolchain binaries
export CC="${CROSS_TRIPLE}-gcc"
export CXX="${CROSS_TRIPLE}-g++"
export AR="${CROSS_TRIPLE}-ar"
export LD="${CROSS_TRIPLE}-ld"
export NM="${CROSS_TRIPLE}-nm"
export RANLIB="${CROSS_TRIPLE}-ranlib"
export STRIP="${CROSS_TRIPLE}-strip"

# Create build directory
mkdir -p "$WORKDIR"

# Build x264 dependency
pushd "$WORKDIR"
  if [ ! -d "x264" ]; then
    git clone --depth 1 https://code.videolan.org/videolan/x264.git
  fi
  cd x264
  PKG_CONFIG_PATH="${X264_PREFIX}/lib/pkgconfig"
  ./configure \
    --host="${CROSS_TRIPLE}" \
    --cross-prefix="${CROSS_TRIPLE}-" \
    --prefix="${X264_PREFIX}" \
    --sysroot="${SYSROOT}" \
    --enable-static \
    --disable-cli \
    --enable-pic \
    --disable-opencl \
    --extra-cflags="-I${SYSROOT}/usr/include" \
    --extra-ldflags="-L${SYSROOT}/usr/lib"
  make -j"$(nproc)"
  make install
popd

export PKG_CONFIG_PATH="${X264_PREFIX}/lib/pkgconfig"

# Configure FFmpeg for cross-compilation
./configure \
  --enable-cross-compile \
  --cross-prefix="${CROSS_TRIPLE}-" \
  --host="${CROSS_TRIPLE}" \
  --arch=arm \
  --cpu=arm1176jzf-s \
  --target-os=linux \
  --sysroot="${SYSROOT}" \
  --extra-cflags="-I${SYSROOT}/usr/include -I${X264_PREFIX}/include" \
  --extra-ldflags="-L${SYSROOT}/usr/lib -L${X264_PREFIX}/lib" \
  --enable-static \
  --disable-shared \
  --disable-everything \
  --enable-protocol=http,https,tls,tcp,udp,file,rtp \
  --enable-demuxer=rtp,rtsp,h264,mjpeg,image2,image2pipe \
  --enable-parser=h264,mjpeg \
  --enable-decoder=h264,mjpeg \
  --enable-encoder=mjpeg,libx264 \
  --enable-muxer=mjpeg,mp4,image2,null \
  --enable-bsf=mjpeg2jpeg \
  --enable-filter=showinfo,scale,format,colorspace \
  --enable-indev=lavfi \
  --enable-libx264 \
  --enable-openssl \
  --enable-version3 \
  --enable-libv4l2 \
  --enable-libdrm \
  --enable-zlib \
  --enable-gpl \
  --disable-doc \
  --disable-debug \
  --prefix="${X264_PREFIX}"

# Build and install FFmpeg
make -j"$(nproc)"
make install