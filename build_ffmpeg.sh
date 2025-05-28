#!/usr/bin/env bash
set -euo pipefail

# Function to log only important messages
log_important() {
    echo "$1"
}

# Function to run commands silently
run_silent() {
    "$@" >/dev/null 2>&1
}

# Function to run commands and show only errors
run_with_errors() {
    "$@" 2>&1 | grep -E "(error|Error|ERROR|failed|Failed|FAILED)" || true
}

log_important "🚀 Starting FFmpeg build for Raspberry Pi Zero"

# Setup cross-compilation environment
export CROSS_COMPILE=${CROSS_COMPILE:-"armv6-unknown-linux-gnueabihf-"}
export SYSROOT=${SYSROOT:-"/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot"}
export PATH="/usr/xcc/armv6-unknown-linux-gnueabihf/bin:$PATH"

# Verify cross-compiler is available
if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    log_important "❌ Error: Cross compiler ${CROSS_COMPILE}gcc not found in PATH"
    exit 1
fi

# Setup pkg-config for cross-compilation
PKG_CONFIG_DIR="${SYSROOT}/usr/lib/pkgconfig"
run_silent mkdir -p "$PKG_CONFIG_DIR"

export PKG_CONFIG_PATH="$PKG_CONFIG_DIR"
export PKG_CONFIG_LIBDIR="$PKG_CONFIG_DIR"
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"

# Create a cross-compile aware pkg-config wrapper
PKG_CONFIG_CROSS="${CROSS_COMPILE}pkg-config"
if ! command -v "$PKG_CONFIG_CROSS" >/dev/null 2>&1; then
    PKG_CONFIG_CROSS="pkg-config"
fi

# Ensure pkg-config is available
if ! command -v "$PKG_CONFIG_CROSS" >/dev/null 2>&1; then
    export PKG_CONFIG="false"
else
    export PKG_CONFIG="$PKG_CONFIG_CROSS"
fi

# Ensure library paths are correct
export LIBRARY_PATH="$SYSROOT/usr/lib:$SYSROOT/lib"
export C_INCLUDE_PATH="$SYSROOT/usr/include"
export CPLUS_INCLUDE_PATH="$SYSROOT/usr/include"

# Build zlib
log_important "🗜️ Building zlib..."
if [ ! -d "zlib" ]; then
    run_silent git clone --depth 1 https://github.com/madler/zlib.git
fi
cd zlib

# Export cross-compiler tools for zlib build
export CC=${CROSS_COMPILE}gcc
export AR=${CROSS_COMPILE}ar
export RANLIB=${CROSS_COMPILE}ranlib
export STRIP=${CROSS_COMPILE}strip

# Configure and build zlib
CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os" \
run_silent ./configure \
    --prefix="$SYSROOT/usr" \
    --libdir="$SYSROOT/usr/lib" \
    --includedir="$SYSROOT/usr/include" \
    --static

run_silent make -j"$(nproc)"
run_silent sudo make install

# Create zlib.pc file
run_silent sudo tee "$PKG_CONFIG_DIR/zlib.pc" << 'EOF'
prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr
exec_prefix=${prefix}
libdir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib
includedir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/include

Name: zlib
Description: zlib compression library
Version: 1.2.13
Libs: -L${libdir} -lz
Cflags: -I${includedir}
EOF

cd ..

# Build OpenSSL
log_important "🔐 Building OpenSSL..."
if [ ! -d "openssl" ]; then
    run_silent git clone --depth 1 --branch OpenSSL_1_1_1-stable https://github.com/openssl/openssl.git
fi
cd openssl

# Clean any previous builds
run_silent make clean || true

# Configure OpenSSL for ARM using linux-generic32 platform
CC="${CROSS_COMPILE}gcc" \
AR="${CROSS_COMPILE}ar" \
RANLIB="${CROSS_COMPILE}ranlib" \
STRIP="${CROSS_COMPILE}strip" \
run_silent ./Configure linux-generic32 \
    --prefix="$SYSROOT/usr" \
    --openssldir="$SYSROOT/usr/ssl" \
    no-shared \
    no-dso \
    no-engine \
    no-unit-test \
    no-ui-console \
    no-asm \
    -static \
    -march=armv6 \
    -mfpu=vfp \
    -mfloat-abi=hard \
    -Os

# Fix the CC line that uses $(CROSS_COMPILE)
run_silent sed -i "s/CC=\$(CROSS_COMPILE)armv6-unknown-linux-gnueabihf-gcc/CC=armv6-unknown-linux-gnueabihf-gcc/" Makefile
# Fix any remaining double prefixes
run_silent sed -i "s/armv6-unknown-linux-gnueabihf-armv6-unknown-linux-gnueabihf-/armv6-unknown-linux-gnueabihf-/g" Makefile
# Also fix AR and RANLIB if they have the same issue
run_silent sed -i "s/AR=\$(CROSS_COMPILE)armv6-unknown-linux-gnueabihf-ar/AR=armv6-unknown-linux-gnueabihf-ar/" Makefile
run_silent sed -i "s/RANLIB=\$(CROSS_COMPILE)armv6-unknown-linux-gnueabihf-ranlib/RANLIB=armv6-unknown-linux-gnueabihf-ranlib/" Makefile

run_silent make -j"$(nproc)" build_libs
run_silent sudo make install_dev

# Create OpenSSL pkg-config files
run_silent sudo tee "$PKG_CONFIG_DIR/openssl.pc" << 'EOF'
prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr
exec_prefix=${prefix}
libdir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib
includedir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/include

Name: OpenSSL
Description: Secure Sockets Layer and cryptography libraries
Version: 1.1.1
Requires: libssl libcrypto
EOF

run_silent sudo tee "$PKG_CONFIG_DIR/libssl.pc" << 'EOF'
prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr
exec_prefix=${prefix}
libdir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib
includedir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/include

Name: OpenSSL-libssl
Description: Secure Sockets Layer and cryptography libraries - libssl
Version: 1.1.1
Requires: libcrypto
Libs: -L${libdir} -lssl
Cflags: -I${includedir}
EOF

run_silent sudo tee "$PKG_CONFIG_DIR/libcrypto.pc" << 'EOF'
prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr
exec_prefix=${prefix}
libdir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib
includedir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/include

Name: OpenSSL-libcrypto
Description: OpenSSL cryptography library
Version: 1.1.1
Libs: -L${libdir} -lcrypto
Libs.private: -ldl -pthread
Cflags: -I${includedir}
EOF

cd ..

# Build libsrtp2
log_important "🔒 Building libsrtp2..."
if [ ! -d "libsrtp" ]; then
    run_silent git clone --depth 1 --branch v2.5.0 https://github.com/cisco/libsrtp.git
fi
cd libsrtp

# Export cross-compiler tools for libsrtp2 build
export CC=${CROSS_COMPILE}gcc
export AR=${CROSS_COMPILE}ar
export RANLIB=${CROSS_COMPILE}ranlib
export STRIP=${CROSS_COMPILE}strip

# Configure and build libsrtp2
CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os" \
run_silent ./configure \
    --host=arm-linux-gnueabihf \
    --prefix="$SYSROOT/usr"

run_silent make -j"$(nproc)"
run_silent sudo make install

# Create libsrtp2.pc file
run_silent sudo tee "$PKG_CONFIG_DIR/libsrtp2.pc" << 'EOF'
prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr
exec_prefix=${prefix}
libdir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib
includedir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/include

Name: libsrtp2
Description: Secure Real-time Transport Protocol (SRTP) library
Version: 2.5.0
Libs: -L${libdir} -lsrtp2
Cflags: -I${includedir}
EOF

cd ..

# Build x264
log_important "🎬 Building x264..."
if [ ! -d "x264" ]; then
    run_silent git clone --depth 1 https://code.videolan.org/videolan/x264.git
fi
cd x264

# Export cross-compiler tools for x264 build BEFORE any make commands
export CC=${CROSS_COMPILE}gcc
export AR=${CROSS_COMPILE}ar
export RANLIB=${CROSS_COMPILE}ranlib
export STRIP=${CROSS_COMPILE}strip

# Ensure directories exist with proper permissions
run_silent sudo mkdir -p "$SYSROOT/usr/lib"
run_silent sudo mkdir -p "$SYSROOT/usr/include"
run_silent sudo mkdir -p "$PKG_CONFIG_DIR"
run_silent sudo chmod -R 755 "$SYSROOT/usr/lib"
run_silent sudo chmod -R 755 "$SYSROOT/usr/include"
run_silent sudo chmod -R 755 "$PKG_CONFIG_DIR"

# Configure x264 with proper paths and flags
PKG_CONFIG_PATH="$PKG_CONFIG_DIR" \
PKG_CONFIG_LIBDIR="$PKG_CONFIG_DIR" \
PKG_CONFIG_SYSROOT_DIR="$SYSROOT" \
run_silent ./configure \
    --cross-prefix=${CROSS_COMPILE} \
    --host=arm-linux-gnueabihf \
    --enable-static \
    --disable-cli \
    --disable-opencl \
    --disable-thread \
    --disable-asm \
    --extra-cflags="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os" \
    --prefix="$SYSROOT/usr" \
    --libdir="$SYSROOT/usr/lib" \
    --includedir="$SYSROOT/usr/include"

run_silent make -j"$(nproc)"
run_silent sudo make install

# Create x264.pc with absolute paths
run_silent sudo tee "$PKG_CONFIG_DIR/x264.pc" << 'EOF'
prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr
exec_prefix=${prefix}
libdir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib
includedir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/include

Name: x264
Description: x264 library
Version: 0.164.x
Requires:
Libs: -L${libdir} -lx264
Libs.private: -lpthread -lm
Cflags: -I${includedir}
EOF

cd ..

# Build libv4l2 (for V4L2 camera support)
log_important "📹 Building libv4l2..."
if [ ! -d "v4l-utils" ]; then
    run_silent git clone --depth 1 --branch v4l-utils-1.24.1 https://git.linuxtv.org/v4l-utils.git v4l-utils
fi
cd v4l-utils

# Export cross-compiler tools for libv4l2 build
export CC=${CROSS_COMPILE}gcc
export CXX=${CROSS_COMPILE}g++
export AR=${CROSS_COMPILE}ar
export RANLIB=${CROSS_COMPILE}ranlib
export STRIP=${CROSS_COMPILE}strip

# Configure and build libv4l2
run_silent ./bootstrap.sh
CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os" \
CXXFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os" \
PKG_CONFIG_PATH="$PKG_CONFIG_DIR" \
PKG_CONFIG_LIBDIR="$PKG_CONFIG_DIR" \
PKG_CONFIG_SYSROOT_DIR="$SYSROOT" \
run_silent ./configure \
    --host=arm-linux-gnueabihf \
    --prefix="$SYSROOT/usr" \
    --disable-shared \
    --enable-static \
    --disable-v4l-utils \
    --disable-qv4l2 \
    --disable-qvidcap \
    --without-libudev

run_silent make -j"$(nproc)"
run_silent sudo make install

# Create libv4l2.pc file
run_silent sudo tee "$PKG_CONFIG_DIR/libv4l2.pc" << 'EOF'
prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr
exec_prefix=${prefix}
libdir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib
includedir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/include

Name: libv4l2
Description: Video4Linux2 library
Version: 1.24.1
Libs: -L${libdir} -lv4l2 -lv4lconvert
Cflags: -I${includedir}
EOF

cd ..

# Clone specific FFmpeg version
FFMPEG_SRC="ffmpeg"
if [ ! -d "$FFMPEG_SRC" ]; then
    log_important "🎥 Cloning FFmpeg..."
    run_silent git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git "$FFMPEG_SRC"
fi

# Prepare build environment
ARCH_FLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os"
PREFIX="$(pwd)/install"
run_silent mkdir -p build

# Configure and build FFmpeg
cd build
log_important "🎥 Configuring FFmpeg..."

# Check if x264 is available via pkg-config
X264_AVAILABLE=0
if [ "$PKG_CONFIG" != "false" ] && $PKG_CONFIG --exists x264 2>/dev/null; then
    X264_AVAILABLE=1
    X264_CFLAGS="$($PKG_CONFIG --cflags x264)"
    X264_LIBS="$($PKG_CONFIG --libs x264)"
    X264_CONFIGURE_FLAGS="--enable-libx264 --enable-encoder=libx264"
else
    X264_CONFIGURE_FLAGS="--disable-libx264"
fi

# Set up CFLAGS and LDFLAGS
EXTRA_CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os -I$SYSROOT/usr/include"
EXTRA_LDFLAGS="--sysroot=$SYSROOT -static -L$SYSROOT/usr/lib"

# Add x264 flags if available
if [ $X264_AVAILABLE -eq 1 ]; then
    EXTRA_CFLAGS="$EXTRA_CFLAGS $X264_CFLAGS"
    EXTRA_LDFLAGS="$EXTRA_LDFLAGS $X264_LIBS"
fi

# Configure FFmpeg
PKG_CONFIG_PATH="$PKG_CONFIG_DIR" \
PKG_CONFIG_LIBDIR="$PKG_CONFIG_DIR" \
PKG_CONFIG_SYSROOT_DIR="$SYSROOT" \
PKG_CONFIG="$PKG_CONFIG" \
run_silent ../$FFMPEG_SRC/configure \
    --prefix="$PREFIX" \
    --cross-prefix=${CROSS_COMPILE} \
    --arch=arm \
    --target-os=linux \
    --enable-cross-compile \
    --disable-runtime-cpudetect \
    --disable-shared \
    --enable-static \
    --disable-doc \
    --disable-debug \
    --disable-everything \
    --enable-gpl \
    --enable-nonfree \
    --enable-version3 \
    --enable-openssl \
    --enable-zlib \
    --enable-filter=testsrc,showinfo,split,scale,format,colorspace,fps,tblend,blackframe,setsar \
    --enable-demuxer=rtp,rtsp,h264,mjpeg,aac,mp3,flv,ogg,opus,adts,image2,image2pipe \
    --enable-decoder=h264_v4l2m2m,h264,mjpeg,rawvideo,aac,mp3float,vorbis,opus,pcm_s16le \
    --enable-encoder=h264_v4l2m2m,mjpeg,rawvideo,aac,wrapped_avframe,libx264 \
    --enable-parser=h264,mjpeg,aac,mpegaudio,vorbis,opus \
    --enable-protocol=rtsp,pipe,http,https,tls,tcp,udp,file,rtp \
    --enable-muxer=rtsp,mjpeg,mp4,null,image2,rtp \
    --enable-bsf=mjpeg2jpeg \
    --enable-indev=lavfi,v4l2 \
    --enable-outdev=v4l2 \
    $X264_CONFIGURE_FLAGS \
    --extra-cflags="$EXTRA_CFLAGS" \
    --extra-ldflags="$EXTRA_LDFLAGS -lssl -lcrypto" \
    --pkg-config="$PKG_CONFIG" \
    --pkg-config-flags="--static" \
    --sysroot="$SYSROOT"

if [ $? -eq 0 ]; then
    log_important "✅ FFmpeg configuration successful"
else
    log_important "❌ FFmpeg configuration failed"
    exit 1
fi

log_important "⏳ Building FFmpeg (this may take several minutes)..."
make -j"$(nproc)" 2>&1 | grep -E "(CC|LD|GEN|INSTALL)" || true
run_silent make install

if [ -f "$PREFIX/bin/ffmpeg" ]; then
    log_important "✅ FFmpeg binary built successfully!"
    log_important "🎉 Build completed! Binary location: $PREFIX/bin/ffmpeg"
else
    log_important "❌ FFmpeg binary not found!"
    exit 1
fi 