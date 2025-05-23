#!/usr/bin/env bash
set -euo pipefail

# Debug: environment info
echo "=== Environment ==="
env | sort

echo "=== GCC version ==="
${CROSS_COMPILE:-armv6-unknown-linux-gnueabihf-}gcc --version

echo "=== pkg-config version ==="
pkg-config --version

# Toolchain prefixes
CROSS_PREFIX=${CROSS_COMPILE:-armv6-unknown-linux-gnueabihf-}
echo "Using cross-prefix: $CROSS_PREFIX"
export CC=${CROSS_PREFIX}gcc
export AR=${CROSS_PREFIX}ar
export AS=${CROSS_PREFIX}as
export LD=${CROSS_PREFIX}ld
export NM=${CROSS_PREFIX}nm
export RANLIB=${CROSS_PREFIX}ranlib
export STRIP=${CROSS_PREFIX}strip

# Set fully static build flags
export PKG_CONFIG_ALL_STATIC=1
export PKG_CONFIG_FLAGS="--static"
echo "PKG_CONFIG_ALL_STATIC=$PKG_CONFIG_ALL_STATIC"
echo "PKG_CONFIG_FLAGS=$PKG_CONFIG_FLAGS"

# ARCH flags for ARMv6 hard-float
ARCH_FLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os"

# Ensure build dependencies for v4l-utils are available
# Build libv4l2 and libv4lconvert from source to enable static linking
V4L_SRC_DIR="v4l-utils"
V4L_INSTALL_DIR="$(pwd)/v4l-install"
if [ ! -d "$V4L_SRC_DIR" ]; then
  echo "Cloning v4l-utils for static libv4l build..."
  git clone --depth 1 https://linuxtv.org/hg/v4l-utils?v=1.20.0 "$V4L_SRC_DIR"
fi
cd "$V4L_SRC_DIR"
# Prepare and configure static build of v4l-utils
autoreconf -fiv
./configure \
  --host=armv6-unknown-linux-gnueabihf \
  --prefix="$V4L_INSTALL_DIR" \
  --disable-shared \
  --enable-static \
  --disable-tools
make -j"$(nproc)"
make install
cd ..

echo "Static v4l-utils installed to $V4L_INSTALL_DIR"

# Configure pkg-config to use v4l-install first
export PKG_CONFIG_PATH="$V4L_INSTALL_DIR/lib/pkgconfig:/usr/lib/arm-linux-gnueabihf/pkgconfig"

echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH"

# Compute CFLAGS and LDFLAGS for static build
CFLAGS="$ARCH_FLAGS $(pkg-config $PKG_CONFIG_FLAGS --cflags \
  libv4l2 libv4lconvert openssl libdrm x264 zlib)"
echo "CFLAGS=$CFLAGS"
LDFLAGS="$(pkg-config $PKG_CONFIG_FLAGS --libs \
  libv4l2 libv4lconvert openssl libdrm x264 zlib) -static"
echo "LDFLAGS=$LDFLAGS"

# Clone latest FFmpeg from Git if missing
FFMPEG_SRC="ffmpeg"
if [ ! -d "$FFMPEG_SRC" ]; then
  echo "Cloning latest FFmpeg from Git..."
  git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git "$FFMPEG_SRC"
fi

# Prepare build directory
PREFIX="$(pwd)/install"
mkdir -p build && cd build

# Configure fully static FFmpeg with v4l2 support
echo "Configuring FFmpeg..."
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

# Build & install
make -j"$(nproc)"
make install

echo "Fully static build complete. Binaries in $PREFIX/bin"