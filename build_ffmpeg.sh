#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Paths & Toolchain
###############################################################################
PREFIX="/usr/local"
SYSROOT="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot"
TOOLCHAIN_PREFIX="armv6-unknown-linux-gnueabihf-"

###############################################################################
# Export cross compiler tools
###############################################################################
export CC="${TOOLCHAIN_PREFIX}gcc"
export CXX="${TOOLCHAIN_PREFIX}g++"
export AR="${TOOLCHAIN_PREFIX}ar"
export LD="${TOOLCHAIN_PREFIX}ld"
export NM="${TOOLCHAIN_PREFIX}nm"
export STRIP="${TOOLCHAIN_PREFIX}strip"
export RANLIB="${TOOLCHAIN_PREFIX}ranlib"

###############################################################################
# Ensure pkg-config will look in your ARMHF sysroot
###############################################################################
export PKG_CONFIG_PATH="${SYSROOT}/usr/lib/arm-linux-gnueabihf/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="${SYSROOT}"

###############################################################################
# Clone FFmpeg if needed
###############################################################################
if [ ! -d ffmpeg ]; then
  git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git ffmpeg
fi
cd ffmpeg

###############################################################################
# Configure for cross-build
###############################################################################
./configure \
  --enable-cross-compile \
  --cross-prefix="${TOOLCHAIN_PREFIX}" \
  --cc="$CC" \
  --arch=arm --cpu=arm1176jzf-s --target-os=linux \
  --sysroot="$SYSROOT" \
  --prefix="$PREFIX" \
  \
  --enable-protocol=http,https,tls,tcp,udp,file,rtp \
  --enable-demuxer=rtp,rtsp,h264,mjpeg,image2,image2pipe \
  --enable-parser=h264,mjpeg \
  --enable-decoder=h264,mjpeg \
  --enable-encoder=mjpeg,libx264 \
  --enable-muxer=mjpeg,mp4,image2,null \
  --enable-bsf=mjpeg2jpeg \
  --enable-filter=showinfo,scale,format,colorspace \
  --enable-indev=lavfi \
  \
  --enable-libx264 \
  --enable-libv4l2 \
  --enable-libdrm \
  --enable-openssl \
  --enable-zlib \
  --enable-gpl \
  --enable-version3 \
  \
  --disable-doc \
  --disable-debug \
  --disable-ffplay

###############################################################################
# Build & Install
###############################################################################
make -j"$(nproc)"
make install

# Package up the result
cd "$PREFIX"
tar czf "../ffmpeg-armv6.tar.gz" *
