#!/usr/bin/env bash
set -euo pipefail

# Debug: print environment information
echo "=== Environment ==="
env | sort

echo "=== GCC version ==="
${CROSS_COMPILE:-armv6-unknown-linux-gnueabihf-}gcc --version

echo "=== pkg-config version ==="
pkg-config --version

# Static build flags defaults
export PKG_CONFIG_ALL_STATIC=${PKG_CONFIG_ALL_STATIC:-1}
export PKG_CONFIG_FLAGS=${PKG_CONFIG_FLAGS:-"--static"}

echo "PKG_CONFIG_ALL_STATIC=$PKG_CONFIG_ALL_STATIC"
echo "PKG_CONFIG_FLAGS=$PKG_CONFIG_FLAGS"

# Architecture and toolchain prefixes
CROSS_PREFIX=${CROSS_COMPILE:-armv6-unknown-linux-gnueabihf-}
echo "Using cross-prefix: $CROSS_PREFIX"

# Set compilers
export CC=${CROSS_PREFIX}gcc
export AR=${CROSS_PREFIX}ar
export AS=${CROSS_PREFIX}as
export LD=${CROSS_PREFIX}ld
export NM=${CROSS_PREFIX}nm
export RANLIB=${CROSS_PREFIX}ranlib
export STRIP=${CROSS_PREFIX}strip

# Set ARCHFLAGS for ARMv6 hard-float
ARCH_FLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os"

# pkg-config paths for ARM
echo "PKG_CONFIG_PATH=/usr/lib/arm-linux-gnueabihf/pkgconfig"
export PKG_CONFIG_PATH=/usr/lib/arm-linux-gnueabihf/pkgconfig
export PKG_CONFIG_LIBDIR=$PKG_CONFIG_PATH

# Compute CFLAGS and extra ldflags
CFLAGS="$ARCH_FLAGS $(pkg-config $PKG_CONFIG_FLAGS --cflags libv4l2 libv4lconvert gnutls)"
EXTRA_LDFLAGS="$(pkg-config $PKG_CONFIG_FLAGS --libs libv4l2 libv4lconvert gnutls) -static"
echo "CFLAGS=$CFLAGS"
echo "EXTRA_LDFLAGS=$EXTRA_LDFLAGS"

# Define installation prefix
PREFIX="$(pwd)/install"

if [ ! -d ffmpeg ]; then
  git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git ffmpeg
fi
cd ffmpeg

# Configure FFmpeg for fully static ARMv6 build
bash -x ./configure \
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
  --enable-protocol=http \
  --enable-protocol=https \
  --enable-protocol=tls \
  --enable-protocol=tcp \
  --enable-protocol=udp \
  --enable-protocol=file \
  --enable-protocol=rtp \
  --enable-demuxer=rtp,rtsp \
  --enable-demuxer=h264 --enable-parser=h264 --enable-decoder=h264 \
  --enable-demuxer=mjpeg --enable-parser=mjpeg --enable-decoder=mjpeg \
  --enable-encoder=mjpeg --enable-muxer=mjpeg \
  --enable-bsf=mjpeg2jpeg \
  --enable-indev=lavfi \
  --enable-filter=showinfo,split,scale,format,colorspace,fps,tblend,blackframe \
  --enable-muxer=mp4,null \
  --enable-encoder=libx264,rawvideo --enable-libx264 \
  --enable-libv4l2 --enable-libdrm --enable-zlib --enable-gnutls \
  --enable-indev=alsa --enable-encoder=aac \
  --enable-demuxer=aac,mp3,flv,ogg,opus,adts \
  --enable-parser=aac,mpegaudio,vorbis,opus \
  --enable-decoder=aac,mp3float,vorbis,opus,pcm_s16le \
  --enable-demuxer=image2,image2pipe --enable-muxer=image2 \
  --disable-doc --disable-debug \
  --extra-cflags="$CFLAGS" \
  --extra-ldflags="$EXTRA_LDFLAGS"

# Build and install
make -j"$(nproc)"
make install

echo "Static build complete. Binaries are in $PREFIX/bin"