#!/usr/bin/env bash
set -euxo pipefail

apt-get update
apt-get install -y --no-install-recommends \
  build-essential \
  git \
  pkg-config \
  yasm \
  libssl-dev         \
  zlib1g-dev         \
  libv4l-dev         \
  libdrm-dev         \
  libjpeg-dev        \
  libpng-dev         \
  libx264-dev        \
  libavcodec-dev     \
  libavformat-dev    \
  libavfilter-dev    \
  libavutil-dev      \
  libswscale-dev     \
  libswresample-dev

rm -rf /var/lib/apt/lists/*

# Paths and toolchain settings
SYSROOT=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot
export PKG_CONFIG_PATH="$SYSROOT/usr/lib/pkgconfig:/usr/lib/arm-linux-gnueabihf/pkgconfig:/usr/lib/pkgconfig"

if [ ! -d ffmpeg ]; then
  git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git ffmpeg
fi
cd ffmpeg
./configure \
  --enable-cross-compile \
  --cross-prefix=armv6-unknown-linux-gnueabihf- \
  --cc=armv6-unknown-linux-gnueabihf-gcc \
  --arch=arm \
  --cpu=arm1176jzf-s \
  --target-os=linux \
  --sysroot=/usr/xcc/armv6-unknown-linux-gnueabihf/\
armv6-unknown-linux-gnueabihf/sysroot \
  --extra-cflags="-I/usr/xcc/armv6-unknown-linux-gnueabihf/\
armv6-unknown-linux-gnueabihf/sysroot/usr/include -I/usr/local/include" \
  --extra-ldflags="-L/usr/xcc/armv6-unknown-linux-gnueabihf/\
armv6-unknown-linux-gnueabihf/sysroot/usr/lib -L/usr/local/lib" \
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
  --prefix=/usr/local
make -j$(nproc)
make install
