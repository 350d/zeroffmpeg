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

# Create cross-pkg-config wrapper so configure finds ARM .pc files
toolchain_bin=$(dirname "$CC")
cat > "$toolchain_bin/${CROSS_PREFIX}pkg-config" << 'EOF'
#!/usr/bin/env bash
export PKG_CONFIG_PATH=/usr/lib/arm-linux-gnueabihf/pkgconfig
exec pkg-config "$@"
EOF
chmod +x "$toolchain_bin/${CROSS_PREFIX}pkg-config"

# ARCH flags for ARMv6 hard-float
ARCH_FLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os"

echo "PKG_CONFIG=$toolchain_bin/${CROSS_PREFIX}pkg-config"

echo "Computing CFLAGS and LDFLAGS..."
# Compute flags for external libs
CFLAGS="$ARCH_FLAGS $(${toolchain_bin}/${CROSS_PREFIX}pkg-config $PKG_CONFIG_FLAGS --cflags libv4l2 libv4lconvert openssl libdrm x264 zlib)"
echo "CFLAGS=$CFLAGS"
LDFLAGS="$(${toolchain_bin}/${CROSS_PREFIX}pkg-config $PKG_CONFIG_FLAGS --libs libv4l2 libv4lconvert openssl libdrm x264 zlib) -static"
echo "LDFLAGS=$LDFLAGS"

# Clone latest FFmpeg from Git if missing
src_dir="ffmpeg"
if [ ! -d "$src_dir" ]; then
  echo "Cloning FFmpeg from Git..."
  git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git "$src_dir"
fi

# Prepare build directory
PREFIX="$(pwd)/install"
mkdir -p build && cd build

echo "Configuring FFmpeg..."
# Configure static FFmpeg with required components
bash -x ../$src_dir/configure \
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
echo "Building FFmpeg..."
make -j"$(nproc)"
make install

echo "Fully static build complete. Binaries in $PREFIX/bin"