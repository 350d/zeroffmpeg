#!/usr/bin/env bash
set -euxo pipefail

echo "🚀 ===============================================" >/dev/null 2>&1
echo "🎬 FFmpeg Static Build for Raspberry Pi Zero 🥧" >/dev/null 2>&1
echo "🚀 ===============================================" >/dev/null 2>&1

# Setup cross-compilation environment
export CROSS_COMPILE=${CROSS_COMPILE:-"armv6-unknown-linux-gnueabihf-"}
export SYSROOT=${SYSROOT:-"/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot"}
export PATH="/usr/xcc/armv6-unknown-linux-gnueabihf/bin:$PATH"

# Verify cross-compiler is available
if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    echo "❌ Error: Cross compiler ${CROSS_COMPILE}gcc not found in PATH" >/dev/null 2>&1
    exit 1
fi

# 1) Debug: environment info
echo "" >/dev/null 2>&1
echo "🔍 =============== ENVIRONMENT INFO ===============" >/dev/null 2>&1
env | sort >/dev/null 2>&1
echo "" >/dev/null 2>&1
echo "🔧 =============== GCC VERSION ===============" >/dev/null 2>&1
${CROSS_COMPILE}gcc --version >/dev/null 2>&1
echo "" >/dev/null 2>&1
echo "📁 =============== WORKING DIRECTORY ===============" >/dev/null 2>&1
pwd >/dev/null 2>&1
ls -la >/dev/null 2>&1

# 2) Setup pkg-config for cross-compilation
echo "" >/dev/null 2>&1
echo "📦 =============== SETTING UP PKG-CONFIG ===============" >/dev/null 2>&1
PKG_CONFIG_DIR="${SYSROOT}/usr/lib/pkgconfig"
mkdir -p "$PKG_CONFIG_DIR" >/dev/null 2>&1

export PKG_CONFIG_PATH="$PKG_CONFIG_DIR"
export PKG_CONFIG_LIBDIR="$PKG_CONFIG_DIR"
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"

# Create a cross-compile aware pkg-config wrapper
PKG_CONFIG_CROSS="${CROSS_COMPILE}pkg-config"
if ! command -v "$PKG_CONFIG_CROSS" >/dev/null 2>&1; then
    echo "⚠️  Cross-compile pkg-config not found, using system pkg-config" >/dev/null 2>&1
    PKG_CONFIG_CROSS="pkg-config"
fi

# Ensure pkg-config is available
if ! command -v "$PKG_CONFIG_CROSS" >/dev/null 2>&1; then
    echo "⚠️  Warning: pkg-config not available, will build without libx264" >/dev/null 2>&1
    export PKG_CONFIG="false"
else
    export PKG_CONFIG="$PKG_CONFIG_CROSS"
fi

# Ensure library paths are correct
export LIBRARY_PATH="$SYSROOT/usr/lib:$SYSROOT/lib"
export C_INCLUDE_PATH="$SYSROOT/usr/include"
export CPLUS_INCLUDE_PATH="$SYSROOT/usr/include"

echo "📦 PKG_CONFIG=$PKG_CONFIG" >/dev/null 2>&1
echo "📦 PKG_CONFIG_PATH=$PKG_CONFIG_PATH" >/dev/null 2>&1
echo "📦 PKG_CONFIG_LIBDIR=$PKG_CONFIG_LIBDIR" >/dev/null 2>&1
echo "📦 PKG_CONFIG_SYSROOT_DIR=$PKG_CONFIG_SYSROOT_DIR" >/dev/null 2>&1
echo "📦 LIBRARY_PATH=$LIBRARY_PATH" >/dev/null 2>&1

# 3) Build zlib
echo "" >/dev/null 2>&1
echo "🗜️  =============== BUILDING ZLIB ===============" >/dev/null 2>&1
if [ ! -d "zlib" ]; then
    echo "📥 Cloning zlib repository..." >/dev/null 2>&1
    git clone --depth 1 https://github.com/madler/zlib.git >/dev/null 2>&1
fi
cd zlib

# Export cross-compiler tools for zlib build
export CC=${CROSS_COMPILE}gcc
export AR=${CROSS_COMPILE}ar
export RANLIB=${CROSS_COMPILE}ranlib
export STRIP=${CROSS_COMPILE}strip

echo "🔧 Building zlib with:" >/dev/null 2>&1
echo "🔧 CC=$CC" >/dev/null 2>&1
echo "🔧 AR=$AR" >/dev/null 2>&1
echo "🔧 RANLIB=$RANLIB" >/dev/null 2>&1

# Configure and build zlib
echo "⏳ Configuring zlib..." >/dev/null 2>&1
CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os" \
./configure \
    --prefix="$SYSROOT/usr" \
    --libdir="$SYSROOT/usr/lib" \
    --includedir="$SYSROOT/usr/include" \
    --static >/dev/null 2>&1

echo "⏳ Compiling zlib..." >/dev/null 2>&1
make -j"$(nproc)" >/dev/null 2>&1
echo "📦 Installing zlib..." >/dev/null 2>&1
sudo make install >/dev/null 2>&1

# Create zlib.pc file
echo "📝 Creating zlib.pc..." >/dev/null 2>&1
sudo tee "$PKG_CONFIG_DIR/zlib.pc" >/dev/null 2>&1 << EOF
prefix=$SYSROOT/usr
exec_prefix=\${prefix}
libdir=$SYSROOT/usr/lib
includedir=$SYSROOT/usr/include

Name: zlib
Description: zlib compression library
Version: 1.2.13
Libs: -L\${libdir} -lz
Cflags: -I\${includedir}
EOF

echo "✅ Verifying zlib installation..." >/dev/null 2>&1
ls "$SYSROOT/usr/lib/libz.a" >/dev/null 2>&1 && echo "✅ zlib library found" >/dev/null 2>&1 || echo "❌ zlib library not found" >/dev/null 2>&1
ls "$SYSROOT/usr/include/zlib.h" >/dev/null 2>&1 && echo "✅ zlib headers found" >/dev/null 2>&1 || echo "❌ zlib headers not found" >/dev/null 2>&1

cd ..

# 4) Build OpenSSL
echo "" >/dev/null 2>&1
echo "🔐 =============== BUILDING OPENSSL ===============" >/dev/null 2>&1
if [ ! -d "openssl" ]; then
    echo "📥 Cloning OpenSSL repository..." >/dev/null 2>&1
    git clone --depth 1 --branch OpenSSL_1_1_1-stable https://github.com/openssl/openssl.git >/dev/null 2>&1
fi
cd openssl

# Clean any previous builds
make clean >/dev/null 2>&1 || true

# Set up cross-compilation with a different approach
echo "🔧 Building OpenSSL with cross-compilation for ARM" >/dev/null 2>&1

# Configure OpenSSL for ARM using linux-generic32 platform
echo "⏳ Configuring OpenSSL..." >/dev/null 2>&1
CC="${CROSS_COMPILE}gcc" \
AR="${CROSS_COMPILE}ar" \
RANLIB="${CROSS_COMPILE}ranlib" \
STRIP="${CROSS_COMPILE}strip" \
./Configure linux-generic32 \
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
    -Os >/dev/null 2>&1

echo "🔧 Fixing double prefix in Makefile..." >/dev/null 2>&1
# Fix the CC line that uses $(CROSS_COMPILE)
sed -i "s/CC=\$(CROSS_COMPILE)armv6-unknown-linux-gnueabihf-gcc/CC=armv6-unknown-linux-gnueabihf-gcc/" Makefile >/dev/null 2>&1
# Fix any remaining double prefixes
sed -i "s/armv6-unknown-linux-gnueabihf-armv6-unknown-linux-gnueabihf-/armv6-unknown-linux-gnueabihf-/g" Makefile >/dev/null 2>&1
# Also fix AR and RANLIB if they have the same issue
sed -i "s/AR=\$(CROSS_COMPILE)armv6-unknown-linux-gnueabihf-ar/AR=armv6-unknown-linux-gnueabihf-ar/" Makefile >/dev/null 2>&1
sed -i "s/RANLIB=\$(CROSS_COMPILE)armv6-unknown-linux-gnueabihf-ranlib/RANLIB=armv6-unknown-linux-gnueabihf-ranlib/" Makefile >/dev/null 2>&1

echo "⏳ Compiling OpenSSL..." >/dev/null 2>&1
make -j"$(nproc)" build_libs >/dev/null 2>&1
echo "📦 Installing OpenSSL..." >/dev/null 2>&1
sudo make install_dev >/dev/null 2>&1

# Create OpenSSL pkg-config files
echo "📝 Creating OpenSSL pkg-config files..." >/dev/null 2>&1
sudo tee "$PKG_CONFIG_DIR/openssl.pc" >/dev/null 2>&1 << EOF
prefix=$SYSROOT/usr
exec_prefix=\${prefix}
libdir=$SYSROOT/usr/lib
includedir=$SYSROOT/usr/include

Name: OpenSSL
Description: Secure Sockets Layer and cryptography libraries
Version: 1.1.1
Requires: libssl libcrypto
EOF

sudo tee "$PKG_CONFIG_DIR/libssl.pc" >/dev/null 2>&1 << EOF
prefix=$SYSROOT/usr
exec_prefix=\${prefix}
libdir=$SYSROOT/usr/lib
includedir=$SYSROOT/usr/include

Name: OpenSSL-libssl
Description: Secure Sockets Layer and cryptography libraries - libssl
Version: 1.1.1
Requires: libcrypto
Libs: -L\${libdir} -lssl
Cflags: -I\${includedir}
EOF

sudo tee "$PKG_CONFIG_DIR/libcrypto.pc" >/dev/null 2>&1 << EOF
prefix=$SYSROOT/usr
exec_prefix=\${prefix}
libdir=$SYSROOT/usr/lib
includedir=$SYSROOT/usr/include

Name: OpenSSL-libcrypto
Description: OpenSSL cryptography library
Version: 1.1.1
Libs: -L\${libdir} -lcrypto
Libs.private: -ldl -pthread
Cflags: -I\${includedir}
EOF

echo "✅ Verifying OpenSSL installation..." >/dev/null 2>&1
ls "$SYSROOT/usr/lib/libssl.a" >/dev/null 2>&1 && echo "✅ libssl found" >/dev/null 2>&1 || echo "❌ libssl not found" >/dev/null 2>&1
ls "$SYSROOT/usr/lib/libcrypto.a" >/dev/null 2>&1 && echo "✅ libcrypto found" >/dev/null 2>&1 || echo "❌ libcrypto not found" >/dev/null 2>&1
ls -d "$SYSROOT/usr/include/openssl" >/dev/null 2>&1 && echo "✅ OpenSSL headers found" >/dev/null 2>&1 || echo "❌ OpenSSL headers not found" >/dev/null 2>&1

cd ..

# 5) Build libsrtp2
echo "" >/dev/null 2>&1
echo "🔒 =============== BUILDING LIBSRTP2 ===============" >/dev/null 2>&1
if [ ! -d "libsrtp" ]; then
    echo "📥 Cloning libsrtp repository..." >/dev/null 2>&1
    git clone --depth 1 --branch v2.5.0 https://github.com/cisco/libsrtp.git >/dev/null 2>&1
fi
cd libsrtp

# Export cross-compiler tools for libsrtp2 build
export CC=${CROSS_COMPILE}gcc
export AR=${CROSS_COMPILE}ar
export RANLIB=${CROSS_COMPILE}ranlib
export STRIP=${CROSS_COMPILE}strip

echo "🔧 Building libsrtp2 with:" >/dev/null 2>&1
echo "🔧 CC=$CC" >/dev/null 2>&1
echo "🔧 AR=$AR" >/dev/null 2>&1
echo "🔧 RANLIB=$RANLIB" >/dev/null 2>&1

# Configure and build libsrtp2
echo "⏳ Configuring libsrtp2..." >/dev/null 2>&1
CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os" \
./configure \
    --host=arm-linux-gnueabihf \
    --prefix="$SYSROOT/usr" >/dev/null 2>&1

echo "⏳ Compiling libsrtp2..." >/dev/null 2>&1
make -j"$(nproc)" >/dev/null 2>&1
echo "📦 Installing libsrtp2..." >/dev/null 2>&1
sudo make install >/dev/null 2>&1

# Create libsrtp2.pc file
echo "📝 Creating libsrtp2.pc..." >/dev/null 2>&1
sudo tee "$PKG_CONFIG_DIR/libsrtp2.pc" >/dev/null 2>&1 << EOF
prefix=$SYSROOT/usr
exec_prefix=\${prefix}
libdir=$SYSROOT/usr/lib
includedir=$SYSROOT/usr/include

Name: libsrtp2
Description: Secure Real-time Transport Protocol (SRTP) library
Version: 2.5.0
Libs: -L\${libdir} -lsrtp2
Cflags: -I\${includedir}
EOF

echo "✅ Verifying libsrtp2 installation..." >/dev/null 2>&1
ls "$SYSROOT/usr/lib/libsrtp2.a" >/dev/null 2>&1 && echo "✅ libsrtp2 library found" >/dev/null 2>&1 || echo "❌ libsrtp2 library not found" >/dev/null 2>&1
ls "$SYSROOT/usr/include/srtp2" >/dev/null 2>&1 && echo "✅ libsrtp2 headers found" >/dev/null 2>&1 || echo "❌ libsrtp2 headers not found" >/dev/null 2>&1

cd ..

# 6) Build x264
echo "" >/dev/null 2>&1
echo "🎬 =============== BUILDING X264 ===============" >/dev/null 2>&1
if [ ! -d "x264" ]; then
    echo "📥 Cloning x264 repository..." >/dev/null 2>&1
    git clone --depth 1 https://code.videolan.org/videolan/x264.git >/dev/null 2>&1
fi
cd x264

# Export cross-compiler tools for x264 build BEFORE any make commands
export CC=${CROSS_COMPILE}gcc
export AR=${CROSS_COMPILE}ar
export RANLIB=${CROSS_COMPILE}ranlib
export STRIP=${CROSS_COMPILE}strip

echo "🔧 Exported compiler variables:" >/dev/null 2>&1
echo "🔧 CC=$CC" >/dev/null 2>&1
echo "🔧 AR=$AR" >/dev/null 2>&1
echo "🔧 RANLIB=$RANLIB" >/dev/null 2>&1
echo "🔧 STRIP=$STRIP" >/dev/null 2>&1

# Ensure directories exist with proper permissions
echo "📁 Setting up directories..." >/dev/null 2>&1
sudo mkdir -p "$SYSROOT/usr/lib" >/dev/null 2>&1
sudo mkdir -p "$SYSROOT/usr/include" >/dev/null 2>&1
sudo mkdir -p "$PKG_CONFIG_DIR" >/dev/null 2>&1
sudo chmod -R 755 "$SYSROOT/usr/lib" >/dev/null 2>&1
sudo chmod -R 755 "$SYSROOT/usr/include" >/dev/null 2>&1
sudo chmod -R 755 "$PKG_CONFIG_DIR" >/dev/null 2>&1

# Configure x264 with proper paths and flags
echo "⏳ Configuring x264..." >/dev/null 2>&1
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
    --includedir="$SYSROOT/usr/include" >/dev/null 2>&1

echo "⏳ Compiling x264..." >/dev/null 2>&1
make -j"$(nproc)" >/dev/null 2>&1
echo "📦 Installing x264..." >/dev/null 2>&1
sudo make install >/dev/null 2>&1

# Create x264.pc with absolute paths
echo "📝 Creating x264.pc..." >/dev/null 2>&1
sudo tee "$PKG_CONFIG_DIR/x264.pc" >/dev/null 2>&1 << EOF
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

echo "✅ Verifying x264 installation..." >/dev/null 2>&1
ls "$SYSROOT/usr/lib/libx264.a" >/dev/null 2>&1 && echo "✅ x264 library found" >/dev/null 2>&1 || echo "❌ x264 library not found" >/dev/null 2>&1
ls "$SYSROOT/usr/include/x264.h" >/dev/null 2>&1 && echo "✅ x264 headers found" >/dev/null 2>&1 || echo "❌ x264 headers not found" >/dev/null 2>&1

# Test pkg-config with x264
echo "🧪 Testing pkg-config with x264..." >/dev/null 2>&1
if [ "$PKG_CONFIG" != "false" ]; then
    $PKG_CONFIG --exists x264 2>/dev/null && echo "✅ x264 pkg-config working" >/dev/null 2>&1 || echo "❌ x264 pkg-config failed" >/dev/null 2>&1
fi

cd ..

# 7) Build libv4l2 (for V4L2 camera support)
echo "" >/dev/null 2>&1
echo "📹 =============== BUILDING LIBV4L2 ===============" >/dev/null 2>&1
if [ ! -d "v4l-utils" ]; then
    echo "📥 Cloning v4l-utils repository..." >/dev/null 2>&1
    git clone --depth 1 --branch v4l-utils-1.24.1 https://git.linuxtv.org/v4l-utils.git v4l-utils >/dev/null 2>&1
fi
cd v4l-utils

# Export cross-compiler tools for libv4l2 build
export CC=${CROSS_COMPILE}gcc
export CXX=${CROSS_COMPILE}g++
export AR=${CROSS_COMPILE}ar
export RANLIB=${CROSS_COMPILE}ranlib
export STRIP=${CROSS_COMPILE}strip

echo "🔧 Building libv4l2 with:" >/dev/null 2>&1
echo "🔧 CC=$CC" >/dev/null 2>&1
echo "🔧 CXX=$CXX" >/dev/null 2>&1
echo "🔧 AR=$AR" >/dev/null 2>&1
echo "🔧 RANLIB=$RANLIB" >/dev/null 2>&1

# Configure and build libv4l2
echo "⏳ Configuring libv4l2..." >/dev/null 2>&1
./bootstrap.sh >/dev/null 2>&1
CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os" \
CXXFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os" \
PKG_CONFIG_PATH="$PKG_CONFIG_DIR" \
PKG_CONFIG_LIBDIR="$PKG_CONFIG_DIR" \
PKG_CONFIG_SYSROOT_DIR="$SYSROOT" \
./configure \
    --host=arm-linux-gnueabihf \
    --prefix="$SYSROOT/usr" \
    --disable-shared \
    --enable-static \
    --disable-v4l-utils \
    --disable-qv4l2 \
    --disable-qvidcap \
    --without-libudev >/dev/null 2>&1

echo "⏳ Compiling libv4l2..." >/dev/null 2>&1
make -j"$(nproc)" >/dev/null 2>&1
echo "📦 Installing libv4l2..." >/dev/null 2>&1
sudo make install >/dev/null 2>&1

# Create libv4l2.pc file
echo "📝 Creating libv4l2.pc..." >/dev/null 2>&1
sudo tee "$PKG_CONFIG_DIR/libv4l2.pc" >/dev/null 2>&1 << EOF
prefix=$SYSROOT/usr
exec_prefix=\${prefix}
libdir=$SYSROOT/usr/lib
includedir=$SYSROOT/usr/include

Name: libv4l2
Description: Video4Linux2 library
Version: 1.24.1
Libs: -L\${libdir} -lv4l2 -lv4lconvert
Cflags: -I\${includedir}
EOF

echo "✅ Verifying libv4l2 installation..." >/dev/null 2>&1
ls "$SYSROOT/usr/lib/libv4l2.a" >/dev/null 2>&1 && echo "✅ libv4l2 library found" >/dev/null 2>&1 || echo "❌ libv4l2 library not found" >/dev/null 2>&1
ls "$SYSROOT/usr/include/libv4l2.h" >/dev/null 2>&1 && echo "✅ libv4l2 headers found" >/dev/null 2>&1 || echo "❌ libv4l2 headers not found" >/dev/null 2>&1

cd ..

# 8) Clone specific FFmpeg version
echo "" >/dev/null 2>&1
echo "🎥 =============== CLONING FFMPEG ===============" >/dev/null 2>&1
FFMPEG_SRC="ffmpeg"
if [ ! -d "$FFMPEG_SRC" ]; then
    echo "📥 Cloning FFmpeg latest..." >/dev/null 2>&1
    git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git "$FFMPEG_SRC" >/dev/null 2>&1
else
    echo "✅ FFmpeg already cloned" >/dev/null 2>&1
fi

# 9) Prepare build environment
echo "" >/dev/null 2>&1
echo "🔧 =============== PREPARING BUILD ENVIRONMENT ===============" >/dev/null 2>&1
ARCH_FLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os"
PREFIX="$(pwd)/install"
mkdir -p build >/dev/null 2>&1

# Prepare for FFmpeg build
echo "🔧 Checking dependencies for FFmpeg..." >/dev/null 2>&1
if [ "$PKG_CONFIG" != "false" ] && $PKG_CONFIG --exists x264 2>/dev/null; then
    echo "✅ x264 ready for FFmpeg" >/dev/null 2>&1
else
    echo "⚠️  x264 not available - will build without libx264" >/dev/null 2>&1
fi

if [ "$PKG_CONFIG" != "false" ] && $PKG_CONFIG --exists libsrtp2 2>/dev/null; then
    echo "✅ libsrtp2 ready for FFmpeg" >/dev/null 2>&1
else
    echo "⚠️  libsrtp2 not available - will build without SRTP support" >/dev/null 2>&1
fi

if [ "$PKG_CONFIG" != "false" ] && $PKG_CONFIG --exists libv4l2 2>/dev/null; then
    echo "✅ libv4l2 ready for FFmpeg" >/dev/null 2>&1
else
    echo "⚠️  libv4l2 not available - will build without V4L2 support" >/dev/null 2>&1
fi

# 10) Configure and build FFmpeg
cd build
echo "" >/dev/null 2>&1
echo "🎥 =============== CONFIGURING FFMPEG ===============" >/dev/null 2>&1

# Check if x264 is available via pkg-config
X264_AVAILABLE=0
if [ "$PKG_CONFIG" != "false" ] && $PKG_CONFIG --exists x264 2>/dev/null; then
    echo "✅ Including x264 in FFmpeg build" >/dev/null 2>&1
    X264_AVAILABLE=1
    X264_CFLAGS="$($PKG_CONFIG --cflags x264)"
    X264_LIBS="$($PKG_CONFIG --libs x264)"
    X264_CONFIGURE_FLAGS="--enable-libx264 --enable-encoder=libx264"
else
    echo "⚠️  Building FFmpeg without x264" >/dev/null 2>&1
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

# Configure and build FFmpeg
echo "⏳ Configuring FFmpeg with V4L2 hardware acceleration..." >/dev/null 2>&1

PKG_CONFIG_PATH="$PKG_CONFIG_DIR" \
PKG_CONFIG_LIBDIR="$PKG_CONFIG_DIR" \
PKG_CONFIG_SYSROOT_DIR="$SYSROOT" \
PKG_CONFIG="$PKG_CONFIG" \
../$FFMPEG_SRC/configure \
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
    --enable-filter=showinfo,split,scale,format,colorspace,fps,tblend,blackframe,setsar \
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
    --sysroot="$SYSROOT" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ FFmpeg configuration successful" >/dev/null 2>&1
else
    echo "❌ FFmpeg configuration failed" >/dev/null 2>&1
    exit 1
fi

echo "⏳ Building FFmpeg (this may take several minutes)..." >/dev/null 2>&1
make -j"$(nproc)" 2>&1 | grep -E "(CC|LD|GEN|INSTALL)" || true
echo "📦 Installing FFmpeg..." >/dev/null 2>&1
make install >/dev/null 2>&1

echo "" >/dev/null 2>&1
echo "🎯 =============== BUILD COMPLETE! ===============" >/dev/null 2>&1
if [ -f "$PREFIX/bin/ffmpeg" ]; then
    echo "✅ FFmpeg binary built successfully!" >/dev/null 2>&1
    BINARY_SIZE=$(ls -lh "$PREFIX/bin/ffmpeg" 2>/dev/null | awk '{print $5}')
    BINARY_ARCH=$(file "$PREFIX/bin/ffmpeg" 2>/dev/null | grep -o 'ARM.*')
    echo "📊 Binary size: $BINARY_SIZE" >/dev/null 2>&1
    echo "🏗️  Architecture: $BINARY_ARCH" >/dev/null 2>&1
    echo "🔗 Linking: Static (no external dependencies)" >/dev/null 2>&1
else
    echo "❌ FFmpeg binary not found!" >/dev/null 2>&1
    exit 1
fi

echo "" >/dev/null 2>&1
echo "🎉 ===============================================" >/dev/null 2>&1
echo "🎊 FFmpeg Static Build Successfully Completed! 🎊" >/dev/null 2>&1
echo "🎉 ===============================================" >/dev/null 2>&1
echo "🎥 FFmpeg location: $PREFIX/bin/ffmpeg" >/dev/null 2>&1
echo "🔍 FFprobe location: $PREFIX/bin/ffprobe" >/dev/null 2>&1
echo "🎯 Target: ARMv6 (Raspberry Pi Zero compatible)" >/dev/null 2>&1
echo "🔐 Features: OpenSSL, zlib, x264, V4L2 cameras, h264_v4l2m2m" >/dev/null 2>&1
echo "🎉 ===============================================" >/dev/null 2>&1 