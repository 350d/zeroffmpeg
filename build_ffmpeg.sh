#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌  Error in line $LINENO, code $?"' ERR
set -x

source /etc/dockcross/env

export CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os"
export LDFLAGS="-static"
#export LDFLAGS=""

X264_PREFIX="$PWD/x264-build"
export PKG_CONFIG_PATH="$X264_PREFIX/lib/pkgconfig"

CROSS_PREFIX="${CROSS_TRIPLE}-"

git clone --depth=1 https://code.videolan.org/videolan/x264.git
pushd x264
./configure \
  --host="$CROSS_TRIPLE" \
  --enable-static \
  --disable-opencl \
  --prefix="$X264_PREFIX" \
  --cross-prefix="$CROSS_PREFIX" \
  --cc="$CC"
make -j"$(nproc)"
make install
popd

############ 2. FFmpeg #########################################################
PREFIX="$PWD/build"
git clone --depth=1 https://github.com/FFmpeg/FFmpeg.git ffmpeg
pushd ffmpeg
./configure \
  --prefix="$PREFIX" \
  --cc="$CC" \
  --cross-prefix="$CROSS_PREFIX" \
  --arch=armel --cpu=arm1176jzf-s --target-os=linux \
  --enable-cross-compile \
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
  --enable-libx264 --enable-libv4l2 --enable-libdrm \
  --enable-openssl --enable-gpl --enable-version3 \
  --enable-static
  --disable-shared \
  --pkg-config-flags="--static" \
  --disable-doc --disable-debug
make -j"$(nproc)"
make install
popd

tar -C "$PREFIX/bin" -czf "$GITHUB_WORKSPACE/ffmpeg-armv6.tar.gz" ffmpeg
echo "✅  ffmpeg-armv6.tar.gz created"