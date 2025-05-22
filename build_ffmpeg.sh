#!/usr/bin/env bash
set -euo pipefail

PREFIX="/usr/local"
SYSROOT="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot"

mkdir -p "$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig"
cp /usr/lib/arm-linux-gnueabihf/pkgconfig/libv4l*.pc \
   /usr/lib/arm-linux-gnueabihf/pkgconfig/libdrm.pc \
   /usr/lib/arm-linux-gnueabihf/pkgconfig/zlib.pc \
   "$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig/"

export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
export PKG_CONFIG_PATH="$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig:$SYSROOT/usr/lib/pkgconfig:/usr/lib/pkgconfig"

echo "libv4l2 version: $(pkg-config --with-sysroot="$SYSROOT" --modversion libv4l2)"
pkg-config --with-sysroot="$SYSROOT" --libs libv4l2

if [ ! -d ffmpeg ]; then
  git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git ffmpeg
fi
pushd ffmpeg

export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
export PKG_CONFIG_PATH="$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig:$SYSROOT/usr/lib/pkgconfig:/usr/lib/pkgconfig"

./configure \
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
  --enable-openssl \
  --enable-version3 \
  --enable-libv4l2 \
  --enable-libdrm \
  --enable-zlib \
  --enable-gpl \
  --disable-doc --disable-debug

make -j"$(nproc)"
make install

popd
