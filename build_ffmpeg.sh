#!/usr/bin/env bash
set -euo pipefail

PREFIX="/usr/local"
SYSROOT="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot"

echo "=== DEBUG: .pc in sysroot ==="
ls "$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig/" || true

[ -d ffmpeg ] || git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git ffmpeg
pushd ffmpeg

# указываем PKG_CONFIG_PATH на только что заполненный каталог
PKG_CONFIG_PATH="$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig" ./configure \
  --enable-cross-compile \
  --cross-prefix=armv6-unknown-linux-gnueabihf- \
  --cc=armv6-unknown-linux-gnueabihf-gcc \
  --arch=arm --cpu=arm1176jzf-s --target-os=linux \
  --sysroot="$SYSROOT" \
  --prefix="$PREFIX" \
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
  --enable-libv4l2 \
  --enable-libdrm \
  --enable-openssl \
  --enable-version3 \
  --enable-zlib \
  --enable-gpl \
  --disable-doc --disable-debug

make -j"$(nproc)"
make install
popd