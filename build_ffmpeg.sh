#!/usr/bin/env bash
set -euo pipefail
set -x

# Debug info
echo "=== ENVIRONMENT ==="
env
echo "=== PATH ==="
echo "$PATH"
echo "=== COMPILERS ==="
echo "CC=$CC"
echo "AS=$AS"
which "$CC" || echo "[$CC not found]"
which as   || echo "[as not found]"

# Force assembler through gcc
export AS="$CC"


exit 1

export CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os"
#export LDFLAGS="-static"           # musl → полностью статик
export LDFLAGS=""
export PATH="/usr/xcc/bin:$PATH"


X264_PREFIX="$PWD/x264-build"
export PKG_CONFIG_PATH="$X264_PREFIX/lib/pkgconfig"

git clone --depth=1 https://code.videolan.org/videolan/x264.git
pushd x264
./configure \
  --host=arm-unknown-linux-gnueabi \
  --enable-static        \
  --disable-opencl       \
  --cross-prefix="${CROSS_TRIPLE}-" \
  --prefix="$X264_PREFIX"
make -j2
make install
popd

PREFIX="$PWD/build"

git clone --depth=1 https://github.com/FFmpeg/FFmpeg ffmpeg
pushd ffmpeg

./configure \
  --prefix="$PREFIX" \
  --arch=armel --cpu=arm1176jzf-s --target-os=linux \
  --enable-cross-compile \
  --cross-prefix="${CROSS_TRIPLE}-" \
  --cc="$CC" --ar="$AR" --ranlib="$RANLIB" \
  --extra-cflags="-I$X264_PREFIX/include $CFLAGS" \
  --extra-ldflags="-L$X264_PREFIX/lib $LDFLAGS" \
  --disable-everything \
  --enable-protocol=http,https,tls,tcp,udp,file,rtp \
  --enable-demuxer=rtp,rtsp,h264,mjpeg,image2,image2pipe \
  --enable-parser=h264,mjpeg \
  --enable-decoder=h264,mjpeg \
  --enable-encoder=mjpeg,libx264 \
  --enable-muxer=mjpeg,mp4,image2,null \
  --enable-bsf=mjpeg2jpeg \
  --enable-filter=showinfo,scale,format,colorspace \
  --enable-indev=lavfi \
  --enable-libx264 \
  --enable-openssl --enable-version3 \
  --enable-libv4l2 \
  --enable-libdrm \
  --enable-zlib \
  --enable-gpl \
  --enable-static --disable-shared \
  --pkg-config-flags="--static" \
  --disable-doc --disable-debug

make -j2
make install
popd

strip -s "$PREFIX/bin/ffmpeg"

# ---------- 3. Артефакт ---------------------
tar -C "$PREFIX/bin" -czf "$GITHUB_WORKSPACE/ffmpeg-armv6.tar.gz" ffmpeg
echo "✅  ffmpeg-armv6.tar.gz created"