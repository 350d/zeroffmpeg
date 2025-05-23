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

echo "PKG_CONFIG_ALL_STATIC=$PKG_CONFIG_ALL_STATIC"

# Ensure fetch tools available
command -v git >/dev/null || { echo "git not found, install it"; exit 1; }
command -v wget >/dev/null || { echo "wget not found, install it"; exit 1; }
command -v bzip2 >/dev/null || { echo "bzip2 not found, install it"; exit 1; }

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

# ARCHFLAGS for ARMv6 hard-float
ARCH_FLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os"

echo "PKG_CONFIG_PATH=/usr/lib/arm-linux-gnueabihf/pkgconfig"
export PKG_CONFIG_PATH=/usr/lib/arm-linux-gnueabihf/pkgconfig
export PKG_CONFIG_LIBDIR=$PKG_CONFIG_PATH

# Compute CFLAGS and EXTRA_LDFLAGS including libv4l2 and OpenSSL
V4L2_CFLAGS=$(pkg-config --cflags libv4l2 libv4lconvert)
SSL_CFLAGS=$(pkg-config --cflags openssl)
CFLAGS="$ARCH_FLAGS $V4L2_CFLAGS $SSL_CFLAGS"
echo "CFLAGS=$CFLAGS"

V4L2_LDFLAGS=$(pkg-config --libs libv4l2 libv4lconvert)
SSL_LDFLAGS=$(pkg-config --static --libs openssl)
EXTRA_LDFLAGS="$V4L2_LDFLAGS $SSL_LDFLAGS -static"
echo "EXTRA_LDFLAGS=$EXTRA_LDFLAGS"

# Fetch latest FFmpeg from Git if not present
SRC_DIR="ffmpeg"
if [ ! -d "$SRC_DIR" ]; then
  echo "Cloning FFmpeg from Git..."
  git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git "$SRC_DIR"
fi

# Prepare build directory
PREFIX="$(pwd)/install"
mkdir -p build
cd build

# Configure FFmpeg (static, cross-compile) with libv4l2 support
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
  --disable-doc --disable-debug \
  --extra-cflags="$CFLAGS" \
  --extra-ldflags="$EXTRA_LDFLAGS"

# Build & install
make -j"$(nproc)"
make install

echo "Static build complete. Binaries in $PREFIX/bin"
