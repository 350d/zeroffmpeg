#!/usr/bin/env bash
set -euo pipefail

PREFIX="/usr/local"
SYSROOT="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot"

echo "===== DATE & WHOAMI ====="
date
whoami
echo

echo "===== APT: УСТАНОВКА ДЕПЕНДОВ ====="
apt-get update
apt-get install -y --no-install-recommends \
    pkg-config build-essential yasm \
    libssl-dev libv4l-dev v4l-utils libdrm-dev zlib1g-dev \
    libjpeg-dev libpng-dev libx264-dev \
    libavcodec-dev libavformat-dev libavfilter-dev libavutil-dev \
    libswscale-dev libswresample-dev \
  && rm -rf /var/lib/apt/lists/*
echo "dep-packages installed"
echo

echo "===== ENVIRONMENT ====="
echo "PREFIX   = $PREFIX"
echo "SYSROOT  = $SYSROOT"
echo "PATH     = $PATH"
echo "PKG_CONFIG_PATH (before) = ${PKG_CONFIG_PATH:-<unset>}"
echo

# убедимся, что .pc-файлы лежат именно здесь:
echo "===== pkg-config SEARCH DIRS ====="
for d in /usr/lib/pkgconfig /usr/share/pkgconfig /usr/lib/arm-linux-gnueabihf/pkgconfig; do
  echo "--- $d ---"
  ls -1 "$d"/*.pc 2>/dev/null || echo "(нет)"
done
echo

# выставляем так, чтобы pkg-config видел arm-мультиарх:
export PKG_CONFIG_PATH="/usr/lib/arm-linux-gnueabihf/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig"
echo "PKG_CONFIG_PATH = $PKG_CONFIG_PATH"
echo "Проверка libv4l2.pc:"
pkg-config --modversion libv4l2 && echo "OK" || echo "FAIL"

if [ ! -d ffmpeg ]; then
  git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git ffmpeg
fi
pushd ffmpeg

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
