#!/usr/bin/env bash
set -euo pipefail

# 1) Debug: environment info
echo "=== Environment ==="
env | sort
echo "=== GCC version ==="
${CROSS_COMPILE:-armv6-unknown-linux-gnueabihf-}gcc --version
echo "=== pkg-config (host) version ==="
pkg-config --version

# 2) Static build flags
export PKG_CONFIG_ALL_STATIC=1
export PKG_CONFIG_FLAGS="--static"
echo "PKG_CONFIG_ALL_STATIC=$PKG_CONFIG_ALL_STATIC"
echo "PKG_CONFIG_FLAGS=$PKG_CONFIG_FLAGS"

# 3) Cross-toolchain prefixes
CROSS_PREFIX=${CROSS_COMPILE:-armv6-unknown-linux-gnueabihf-}
echo "Using cross-prefix: $CROSS_PREFIX"
export CC=${CROSS_PREFIX}gcc
export AR=${CROSS_PREFIX}ar
export AS=${CROSS_PREFIX}as
export LD=${CROSS_PREFIX}ld
export NM=${CROSS_PREFIX}nm
export RANLIB=${CROSS_PREFIX}ranlib
export STRIP=${CROSS_PREFIX}strip

# 4) Build static v4l-utils v1.3.0 for libv4l2
V4L_VER=1.3.0
V4L_TARBALL="v4l-utils-$V4L_VER.tar.gz"
V4L_SRC="v4l-utils-$V4L_VER"
V4L_INSTALL="$(pwd)/v4l-install"
if [ ! -d "$V4L_SRC" ]; then
  echo "Downloading v4l-utils $V4L_VER..."
  wget https://linuxtv.org/downloads/v4l-utils/$V4L_TARBALL
  tar xzf $V4L_TARBALL
fi
cd "$V4L_SRC"
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
echo "Static v4l-utils installed to $V4L_INSTALL"

# 5) Setup pkg-config to see v4l-install first
export PKG_CONFIG_PATH="$V4L_INSTALL/lib/pkgconfig:/usr/lib/arm-linux-gnueabihf/pkgconfig"
echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH"

# 6) Compute flags for external libs
echo "=== Computing CFLAGS/LDFLAGS ==="
ARCH_FLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os"
CFLAGS="$ARCH_FLAGS $(pkg-config $PKG_CONFIG_FLAGS --cflags libv4l2 libv4lconvert openssl libdrm x264 zlib)"
echo "CFLAGS=$CFLAGS"
LDFLAGS="$(pkg-config $PKG_CONFIG_FLAGS --libs libv4l2 libv4lconvert openssl libdrm x264 zlib) -static"
echo "LDFLAGS=$LDFLAGS"

# 7) Clone latest FFmpeg
FFMPEG_SRC="ffmpeg"
if [ ! -d "$FFMPEG_SRC" ]; then
  echo "Cloning latest FFmpeg..."
  git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git "$FFMPEG_SRC"
fi

# 8) Prepare build directory
PREFIX="$(pwd)/install"
mkdir -p build && cd build

# 9) Configure fully static FFmpeg
echo "=== Configuring FFmpeg ==="
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

# 10) Build & install
echo "=== Building FFmpeg ==="
make -j"$(nproc)"
make install

echo "Static FFmpeg build complete. Binaries in $PREFIX/bin"