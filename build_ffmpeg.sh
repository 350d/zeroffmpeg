#!/usr/bin/env bash
set -euo pipefail

# 1) Debug: среда
echo "=== Environment ==="
env | sort
echo "=== GCC version ==="
${CROSS_COMPILE:-armv6-unknown-linux-gnueabihf-}gcc --version
echo "=== pkg-config (host) version ==="
pkg-config --version

# 2) Флаги статической сборки
export PKG_CONFIG_ALL_STATIC=1
export PKG_CONFIG_FLAGS="--static"
echo "PKG_CONFIG_ALL_STATIC=$PKG_CONFIG_ALL_STATIC"
echo "PKG_CONFIG_FLAGS=$PKG_CONFIG_FLAGS"

# 3) Настройка кросс-компилятора
CROSS_PREFIX=${CROSS_COMPILE:-armv6-unknown-linux-gnueabihf-}
echo "Using cross-prefix: $CROSS_PREFIX"
export CC=${CROSS_PREFIX}gcc
export AR=${CROSS_PREFIX}ar
export AS=${CROSS_PREFIX}as
export LD=${CROSS_PREFIX}ld
export NM=${CROSS_PREFIX}nm
export RANLIB=${CROSS_PREFIX}ranlib
export STRIP=${CROSS_PREFIX}strip

# 4) Собираем v4l-utils статически
echo "=== Build static v4l-utils ==="
V4L_SRC=v4l-utils
V4L_INSTALL=$(pwd)/v4l-install
if [ ! -d "$V4L_SRC" ]; then
  echo "Cloning v4l-utils (Mercurial)…"
  hg clone https://linuxtv.org/hg/v4l-utils "$V4L_SRC"
fi
cd "$V4L_SRC"
autoreconf -fvi
HOST_TRIPLE=${CROSS_PREFIX%-}
./configure \
  --host="$HOST_TRIPLE" \
  --prefix="$V4L_INSTALL" \
  --disable-shared \
  --enable-static \
  --disable-tools
make -j"$(nproc)"
make install
cd ..

# 5) Настраиваем pkg-config
export PKG_CONFIG_PATH="$V4L_INSTALL/lib/pkgconfig:/usr/lib/arm-linux-gnueabihf/pkgconfig"
echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH"

# 6) Собираем FFmpeg статически
ARCH_FLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os"

echo "=== Computing CFLAGS/LDFLAGS ==="
CFLAGS="$ARCH_FLAGS $(pkg-config $PKG_CONFIG_FLAGS --cflags libv4l2 libv4lconvert openssl libdrm x264 zlib)"
echo "CFLAGS=$CFLAGS"
LDFLAGS="$(pkg-config $PKG_CONFIG_FLAGS --libs libv4l2 libv4lconvert openssl libdrm x264 zlib) -static"
echo "LDFLAGS=$LDFLAGS"

# 7) Клонируем FFmpeg из Git, если нужно
FFMPEG_SRC=ffmpeg
if [ ! -d "$FFMPEG_SRC" ]; then
  echo "Cloning latest FFmpeg…"
  git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git "$FFMPEG_SRC"
fi

# 8) Конфигурация и сборка FFmpeg
PREFIX="$(pwd)/install"
mkdir -p build && cd build

bash -x ../$FFMPEG_SRC/configure \
  --prefix="$PREFIX" \
  --cross-prefix=$CROSS_PREFIX \
  --arch=arm \
  --cpu=arm1176jzf-s \
  --target-os=linux \
  --enable-cross-compile \
  --disable-runtime-cpudetect \
  --enable-static \
  --disable-shared \
  --pkg-config-flags="$PKG_CONFIG_FLAGS" \
  --disable-everything \
  --enable-gpl \
  --enable-version3 \
  --enable-nonfree \
  --enable-openssl \
  --enable-libv4l2 \
  --enable-libdrm \
  --enable-libx264 \
  --enable-zlib \
  --enable-protocol=http,https,tls,tcp,udp,file \
  --enable-demuxer=rtp,rtsp,h264,mjpeg,aac,mp3,flv,ogg,opus,adts,image2,image2pipe \
  --enable-parser=h264,mjpeg,aac,mpegaudio,vorbis,opus \
  --enable-decoder=h264,mjpeg,aac,mp3float,vorbis,opus,pcm_s16le \
  --enable-encoder=mjpeg,libx264,rawvideo,aac \
  --enable-muxer=mjpeg,mp4,null,image2 \
  --enable-bsf=mjpeg2jpeg \
  --enable-indev=lavfi,alsa \
  --enable-filter=showinfo,split,scale,format,colorspace,fps,tblend,blackframe \
  --extra-cflags="$CFLAGS" \
  --extra-ldflags="$LDFLAGS"

echo "=== Building FFmpeg… ==="
make -j"$(nproc)"
make install

echo "Static FFmpeg build complete. Binaries in $PREFIX/bin"