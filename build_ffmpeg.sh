#!/usr/bin/env bash
set -euo pipefail

# Debug: environment info
echo "=== Environment ==="
env | sort

echo "=== GCC version ==="
${CROSS_COMPILE:-armv6-unknown-linux-gnueabihf-}gcc --version

echo "=== pkg-config version ==="
pkg-config --version

# Enable fully static build
export PKG_CONFIG_ALL_STATIC=1
export PKG_CONFIG_FLAGS="--static"
echo "PKG_CONFIG_ALL_STATIC=$PKG_CONFIG_ALL_STATIC"
echo "PKG_CONFIG_FLAGS=$PKG_CONFIG_FLAGS"

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

# ARCH flags for ARMv6 hard-float
ARCH_FLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os"

# pkg-config for ARM multiarch
export PKG_CONFIG_PATH=/usr/lib/arm-linux-gnueabihf/pkgconfig
export PKG_CONFIG_LIBDIR=$PKG_CONFIG_PATH

# Compute CFLAGS using correct pkg-config names
CFLAGS="$ARCH_FLAGS $(pkg-config $PKG_CONFIG_FLAGS --cflags \
  libv4l2 libv4lconvert openssl libdrm x264 zlib lame opus ogg vorbis libjpeg)"
echo "CFLAGS=$CFLAGS"

# Compute LDFLAGS with static libraries
LDFLAGS="$(pkg-config $PKG_CONFIG_FLAGS --libs \
  libv4l2 libv4lconvert openssl libdrm x264 zlib lame opus ogg vorbis libjpeg) -static"
echo "LDFLAGS=$LDFLAGS"

# Clone latest FFmpeg from Git if missing
SRC_DIR="ffmpeg"
if [ ! -d "$SRC_DIR" ]; then
  echo "Cloning FFmpeg from Git..."
  git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git "$SRC_DIR"
fi

# Prepare build directory
PREFIX="$(pwd)/install"
mkdir -p build && cd build

# Configure fully static FFmpeg
bash -x ../$SRC_DIR/configure \
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
  --enable-libmp3lame \
  --enable-libopus \
  --enable-libogg \
  --enable-libvorbis \
  --enable-libjpeg \
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

# Build and install
make -j"$(nproc)"
make install

echo "Fully static build complete. Binaries in $PREFIX/bin"