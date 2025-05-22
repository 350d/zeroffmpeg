#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Paths
###############################################################################
PREFIX="/usr/local"             # where 'make install' will go inside the container
SYSROOT="${SYSROOT:-/work/sysroot}"

###############################################################################
# Ensure pkg-config will look in your ARMHF sysroot
###############################################################################
export PKG_CONFIG_PATH="$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig"

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
  --disable-debug

###############################################################################
# Build & Install
###############################################################################
make -j$(nproc)
make install

###############################################################################
# Package up the result
###############################################################################
cd "$PREFIX"
tar czf /work/ffmpeg-armv6.tar.gz .