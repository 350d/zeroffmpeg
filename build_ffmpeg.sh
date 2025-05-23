#!/usr/bin/env bash
set -euxo pipefail

# Setup cross-compilation environment
export CROSS_COMPILE=${CROSS_COMPILE:-"armv6-unknown-linux-gnueabihf-"}
export SYSROOT=${SYSROOT:-"/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot"}
export PATH="/usr/xcc/armv6-unknown-linux-gnueabihf/bin:$PATH"

# Verify cross-compiler is available
if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    echo "Error: Cross compiler ${CROSS_COMPILE}gcc not found in PATH"
    exit 1
fi

# 1) Debug: environment info
echo "=== Environment ==="
env | sort
echo "=== GCC version ==="
${CROSS_COMPILE}gcc --version
echo "=== Working directory ==="
pwd
ls -la

# 2) Setup pkg-config for cross-compilation
echo "=== Setting up pkg-config ==="
PKG_CONFIG_DIR="${SYSROOT}/usr/lib/pkgconfig"
mkdir -p "$PKG_CONFIG_DIR"

export PKG_CONFIG_PATH="$PKG_CONFIG_DIR"
export PKG_CONFIG_LIBDIR="$PKG_CONFIG_DIR"
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"

# Create a cross-compile aware pkg-config wrapper
PKG_CONFIG_CROSS="${CROSS_COMPILE}pkg-config"
if ! command -v "$PKG_CONFIG_CROSS" >/dev/null 2>&1; then
    echo "Cross-compile pkg-config not found, using system pkg-config"
    PKG_CONFIG_CROSS="pkg-config"
fi

# Ensure pkg-config is available
if ! command -v "$PKG_CONFIG_CROSS" >/dev/null 2>&1; then
    echo "Warning: pkg-config not available, will build without libx264"
    export PKG_CONFIG="false"
else
    export PKG_CONFIG="$PKG_CONFIG_CROSS"
fi

# Ensure library paths are correct
export LIBRARY_PATH="$SYSROOT/usr/lib:$SYSROOT/lib"
export C_INCLUDE_PATH="$SYSROOT/usr/include"
export CPLUS_INCLUDE_PATH="$SYSROOT/usr/include"

echo "PKG_CONFIG=$PKG_CONFIG"
echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH"
echo "PKG_CONFIG_LIBDIR=$PKG_CONFIG_LIBDIR"
echo "PKG_CONFIG_SYSROOT_DIR=$PKG_CONFIG_SYSROOT_DIR"
echo "LIBRARY_PATH=$LIBRARY_PATH"

# 3) Build x264
echo "=== Building x264 ==="
if [ ! -d "x264" ]; then
    git clone --depth 1 https://code.videolan.org/videolan/x264.git
fi
cd x264

# Clean any previous builds
make clean || true
make distclean || true

# Ensure directories exist with proper permissions
sudo mkdir -p "$SYSROOT/usr/lib"
sudo mkdir -p "$SYSROOT/usr/include"
sudo mkdir -p "$PKG_CONFIG_DIR"
sudo chmod -R 755 "$SYSROOT/usr/lib"
sudo chmod -R 755 "$SYSROOT/usr/include"
sudo chmod -R 755 "$PKG_CONFIG_DIR"

# Configure x264 with proper paths and flags
PKG_CONFIG_PATH="$PKG_CONFIG_DIR" \
PKG_CONFIG_LIBDIR="$PKG_CONFIG_DIR" \
PKG_CONFIG_SYSROOT_DIR="$SYSROOT" \
./configure \
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

make -j"$(nproc)" V=1
sudo make install

# Create x264.pc with absolute paths
sudo tee "$PKG_CONFIG_DIR/x264.pc" << EOF
prefix=$SYSROOT/usr
exec_prefix=\${prefix}
libdir=$SYSROOT/usr/lib
includedir=$SYSROOT/usr/include

Name: x264
Description: x264 library
Version: 0.164.x
Requires:
Libs: -L\${libdir} -lx264
Libs.private: -lpthread -lm
Cflags: -I\${includedir}
EOF

echo "=== Verifying x264 installation ==="
echo "Checking x264.pc contents:"
cat "$PKG_CONFIG_DIR/x264.pc"
echo "Checking x264 library:"
ls -la "$SYSROOT/usr/lib/libx264*" || echo "No x264 libraries found"
echo "Checking x264 headers:"
ls -la "$SYSROOT/usr/include/x264*" || echo "No x264 headers found"
echo "Checking pkg-config directory:"
ls -la "$PKG_CONFIG_DIR"

# Test pkg-config with x264 more thoroughly
echo "=== Testing pkg-config with x264 ==="
if [ "$PKG_CONFIG" != "false" ]; then
    echo "PKG_CONFIG=$PKG_CONFIG"
    echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH"
    echo "PKG_CONFIG_LIBDIR=$PKG_CONFIG_LIBDIR"
    echo "PKG_CONFIG_SYSROOT_DIR=$PKG_CONFIG_SYSROOT_DIR"
    
    echo "Testing x264 package existence:"
    $PKG_CONFIG --exists x264 2>&1 || echo "x264 package not found"
    echo "Testing x264 cflags:"
    $PKG_CONFIG --cflags x264 2>&1 || echo "Failed to get cflags"
    echo "Testing x264 libs:"
    $PKG_CONFIG --libs x264 2>&1 || echo "Failed to get libs"
    echo "Available packages:"
    $PKG_CONFIG --list-all 2>&1 | grep x264 || echo "No x264 in package list"
    
    # Verify library can be found by the compiler
    echo "Testing library with compiler:"
    echo "int main() { return 0; }" > test.c
    ${CROSS_COMPILE}gcc test.c $($PKG_CONFIG --cflags --libs x264) -o test && echo "Compilation successful" || echo "Compilation failed"
    rm -f test.c test
fi

cd ..

# Create libv4l2.pc manually
cat > "$PKG_CONFIG_DIR/libv4l2.pc" << EOF
prefix=$SYSROOT/usr
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: libv4l2
Description: v4l2 device access library
Version: 1.22.1
Requires: libv4lconvert
Libs: -L\${libdir} -lv4l2
Cflags: -I\${includedir}
EOF

echo "=== Verifying libv4l2.pc ==="
cat "$PKG_CONFIG_DIR/libv4l2.pc"

cd ..

# 4) Clone specific FFmpeg version
FFMPEG_SRC="ffmpeg"
if [ ! -d "$FFMPEG_SRC" ]; then
    echo "Cloning FFmpeg..."
    git clone --depth 1 --branch n6.1.1 https://git.ffmpeg.org/ffmpeg.git "$FFMPEG_SRC"
fi

# 5) Prepare build environment
ARCH_FLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os"
PREFIX="$(pwd)/install"
mkdir -p build

# Debug pkg-config
echo "=== Testing pkg-config for x264 ==="
echo "PKG_CONFIG: $PKG_CONFIG"
if [ "$PKG_CONFIG" != "false" ]; then
    $PKG_CONFIG --exists x264 2>/dev/null && echo "x264 found via pkg-config" || echo "x264 NOT found via pkg-config"
    echo "=== x264 pkg-config output ==="
    $PKG_CONFIG --cflags x264 2>/dev/null || echo "No cflags available"
    $PKG_CONFIG --libs x264 2>/dev/null || echo "No libs available"
else
    echo "pkg-config not available - x264 will be disabled"
fi
echo "=== x264 library check ==="
ls -la $SYSROOT/usr/lib/libx264* || echo "No x264 libraries found"
ls -la $SYSROOT/usr/include/x264* || echo "No x264 headers found"

# Before FFmpeg configuration, verify x264 is properly set up
echo "=== Verifying x264 setup before FFmpeg configuration ==="
echo "Testing pkg-config with verbose output:"
pkg-config --debug --exists x264 2>&1
echo "x264 CFLAGS:"
pkg-config --cflags x264 2>&1
echo "x264 LIBS:"
pkg-config --libs x264 2>&1

# Create a test program to verify x264
cat > test_x264.c << EOF
#include <stdint.h>
#include <x264.h>
int main() {
    x264_param_t param;
    x264_picture_t pic;
    x264_t *h = NULL;
    x264_encoder_encode(h, NULL, NULL, &pic, NULL);
    return 0;
}
EOF

echo "=== Testing x264 compilation ==="
${CROSS_COMPILE}gcc -o test_x264 test_x264.c $(pkg-config --cflags --libs x264) && echo "x264 test compilation successful" || echo "x264 test compilation failed"
rm -f test_x264 test_x264.c

# 6) Configure and build FFmpeg
cd build
echo "=== Configuring FFmpeg ==="

# Debug cross-compilation setup
echo "=== Cross-compilation debug info ==="
echo "CROSS_COMPILE: $CROSS_COMPILE"
echo "SYSROOT: $SYSROOT"
echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
echo "PKG_CONFIG_LIBDIR: $PKG_CONFIG_LIBDIR"
echo "PKG_CONFIG_SYSROOT_DIR: $PKG_CONFIG_SYSROOT_DIR"

# Check if x264 is available via pkg-config
X264_AVAILABLE=0
if [ "$PKG_CONFIG" != "false" ] && $PKG_CONFIG --exists x264 2>/dev/null; then
    echo "x264 found via pkg-config - including in build"
    X264_AVAILABLE=1
    X264_CFLAGS="$($PKG_CONFIG --cflags x264)"
    X264_LIBS="$($PKG_CONFIG --libs x264)"
    X264_CONFIGURE_FLAGS="--enable-libx264 --enable-encoder=libx264"
    echo "X264 CFLAGS: $X264_CFLAGS"
    echo "X264 LIBS: $X264_LIBS"
else
    echo "x264 NOT found via pkg-config - building without libx264"
    X264_CONFIGURE_FLAGS="--disable-libx264"
fi

echo "Using X264 configuration: $X264_CONFIGURE_FLAGS"

# Set up CFLAGS and LDFLAGS
EXTRA_CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os -I$SYSROOT/usr/include"
EXTRA_LDFLAGS="--sysroot=$SYSROOT -static -L$SYSROOT/usr/lib"

# Add x264 flags if available
if [ $X264_AVAILABLE -eq 1 ]; then
    EXTRA_CFLAGS="$EXTRA_CFLAGS $X264_CFLAGS"
    EXTRA_LDFLAGS="$EXTRA_LDFLAGS $X264_LIBS"
fi

if [ "$PKG_CONFIG" != "false" ]; then
    PKG_CONFIG_PATH="$PKG_CONFIG_DIR" \
    PKG_CONFIG_LIBDIR="$PKG_CONFIG_DIR" \
    PKG_CONFIG_SYSROOT_DIR="$SYSROOT" \
    PKG_CONFIG="$PKG_CONFIG" \
    bash -x ../$FFMPEG_SRC/configure \
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
        --enable-version3 \
        --enable-openssl \
        --enable-protocol=http \
        --enable-protocol=https \
        --enable-protocol=tls \
        --enable-protocol=tcp \
        --enable-protocol=udp \
        --enable-protocol=file \
        --enable-protocol=rtp \
        --enable-demuxer=rtp \
        --enable-demuxer=rtsp \
        --enable-demuxer=h264 \
        --enable-parser=h264 \
        --enable-decoder=h264 \
        --enable-demuxer=mjpeg \
        --enable-parser=mjpeg \
        --enable-decoder=mjpeg \
        --enable-encoder=mjpeg \
        --enable-muxer=mjpeg \
        --enable-bsf=mjpeg2jpeg \
        --enable-indev=lavfi \
        --enable-filter=showinfo,split,scale,format,colorspace,fps,tblend,blackframe \
        --enable-muxer=mp4,null \
        --enable-encoder=rawvideo \
        $X264_CONFIGURE_FLAGS \
        --enable-zlib \
        --enable-encoder=aac \
        --enable-demuxer=aac,mp3,flv,ogg,opus,adts \
        --enable-parser=aac,mpegaudio,vorbis,opus \
        --enable-decoder=aac,mp3float,vorbis,opus,pcm_s16le \
        --enable-demuxer=image2 \
        --enable-demuxer=image2pipe \
        --enable-muxer=image2 \
        --extra-cflags="$EXTRA_CFLAGS" \
        --extra-ldflags="$EXTRA_LDFLAGS -lssl -lcrypto" \
        --pkg-config="$PKG_CONFIG" \
        --sysroot="$SYSROOT"
else
    # Configure without pkg-config
    bash -x ../$FFMPEG_SRC/configure \
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
        --enable-version3 \
        --enable-openssl \
        --enable-protocol=http \
        --enable-protocol=https \
        --enable-protocol=tls \
        --enable-protocol=tcp \
        --enable-protocol=udp \
        --enable-protocol=file \
        --enable-protocol=rtp \
        --enable-demuxer=rtp \
        --enable-demuxer=rtsp \
        --enable-demuxer=h264 \
        --enable-parser=h264 \
        --enable-decoder=h264 \
        --enable-demuxer=mjpeg \
        --enable-parser=mjpeg \
        --enable-decoder=mjpeg \
        --enable-encoder=mjpeg \
        --enable-muxer=mjpeg \
        --enable-bsf=mjpeg2jpeg \
        --enable-indev=lavfi \
        --enable-filter=showinfo,split,scale,format,colorspace,fps,tblend,blackframe \
        --enable-muxer=mp4,null \
        --enable-encoder=rawvideo \
        $X264_CONFIGURE_FLAGS \
        --enable-zlib \
        --enable-encoder=aac \
        --enable-demuxer=aac,mp3,flv,ogg,opus,adts \
        --enable-parser=aac,mpegaudio,vorbis,opus \
        --enable-decoder=aac,mp3float,vorbis,opus,pcm_s16le \
        --enable-demuxer=image2 \
        --enable-demuxer=image2pipe \
        --enable-muxer=image2 \
        --extra-cflags="$EXTRA_CFLAGS" \
        --extra-ldflags="$EXTRA_LDFLAGS -lssl -lcrypto" \
        --sysroot="$SYSROOT"
fi

echo "=== Building FFmpeg ==="
make -j"$(nproc)" V=1
make install

echo "=== Build complete ==="
ls -la $PREFIX/bin/
file $PREFIX/bin/ffmpeg
echo "=== Checking FFmpeg dependencies ==="
ldd $PREFIX/bin/ffmpeg || true
${CROSS_COMPILE}readelf -d $PREFIX/bin/ffmpeg
