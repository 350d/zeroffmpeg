#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Paths
###############################################################################
PREFIX="/usr/local"
SYSROOT="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot"

###############################################################################
# Ensure pkg-config will look in your ARMHF sysroot
###############################################################################
export PKG_CONFIG_PATH="$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"

###############################################################################
# Clone FFmpeg if needed
###############################################################################
if [ ! -d ffmpeg ]; then
  git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git ffmpeg
fi
cd ffmpeg

###############################################################################
# Configure
###############################################################################
./configure \
  --enable-cross-compile \
  --cross-prefix=armv6-unknown-linux-gnueabihf- \
  --cc=armv6-unknown-linux-gnueabihf-gcc \
  --arch=arm --cpu=arm1176jzf-s --target-os=linux \
  --sysroot="$SYSROOT" \
  \
  # tell configure where to find headers & libs inside sysroot
  --extra-cflags="-I$SYSROOT/usr/include -I$SYSROOT/include" \
  --extra-ldflags="-L$SYSROOT/usr/lib/arm-linux-gnueabihf -L$SYSROOT/lib/arm-linux-gnueabihf" \
  \
  --prefix="$PREFIX" \
  \
  # formats, protocols, filters...
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
  # external libs
  --enable-libx264 \
  --enable-libv4l2 \
  --enable-libdrm \
  --enable-openssl \
  --enable-zlib \
  \
  --enable-gpl \
  --enable-version3 \
  \
  --disable-doc \
  --disable-debug

###############################################################################
# Build & Install
###############################################################################
make -j"$(nproc)"
make install