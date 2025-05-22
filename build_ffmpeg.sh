#!/usr/bin/env bash
set -euxo pipefail

apt-get update
apt-get install -y --no-install-recommends \
  build-essential \
  git \
  pkg-config \
  yasm \
  libssl-dev           # --enable-openssl, --enable-version3, https/tls
  zlib1g-dev           # --enable-zlib
  libv4l-dev           # --enable-libv4l2
  libdrm-dev           # --enable-libdrm
  libjpeg-dev          # mjpeg encoder/decoder, image2 demuxer
  libpng-dev           # image2 support (PNG input/output)
  libx264-dev          # libx264 (хотя вы можете собрать x264 вручную)
  libavcodec-dev       # базовые кодеки (h264, mjpeg парсеры/декодеры)
  libavformat-dev      # контейнеры (mp4, rtp/rtsp демультиплексор)
  libavfilter-dev      # фильтры (scale, format, colorspace, showinfo через lavfi)
  libavutil-dev        # вспомогательные утилиты
  libswscale-dev       # масштабирование (scale)
  libswresample-dev    # ресэмплинг (если появится аудио)

rm -rf /var/lib/apt/lists/*

export PKG_CONFIG_PATH=/usr/xcc/armv6-unknown-linux-gnueabihf/\
armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig:$PKG_CONFIG_PATH

mkdir -p /work/build

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
