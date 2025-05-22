#!/usr/bin/env bash
set -euo pipefail

SYSROOT="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot"
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
export PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig:$SYSROOT/usr/share/pkgconfig"

if [ ! -d ffmpeg ]; then
  git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git ffmpeg
fi
pushd ffmpeg
PKG_CONFIG_PATH="/usr/lib/arm-linux-gnueabihf/pkgconfig:/usr/lib/pkgconfig" \
./configure \
  --enable-cross-compile \
  --cross-prefix=armv6-unknown-linux-gnueabihf- \
  --cc=armv6-unknown-linux-gnueabihf-gcc \
  --arch=arm --cpu=arm1176jzf-s --target-os=linux \
  --sysroot="$SYSROOT" \
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
  --disable-doc --disable-debug \
  --prefix=/usr/local
make -j$(nproc)
make install
popd
