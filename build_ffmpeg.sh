#!/usr/bin/env bash
set -euxo pipefail

source /etc/dockcross/env

# Pi Zero
export CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os"
PREFIX="$PWD/root"
mkdir -p "$PREFIX"

########## x264 #############################################################
git clone --depth 1 --branch stable https://code.videolan.org/videolan/x264.git
pushd x264
./configure \
  --host="$CROSS_TRIPLE" \
  --cross-prefix="$CROSS_PREFIX" \
  --enable-static  --disable-opencl --disable-asm \
  --prefix="$PREFIX"
make -j"$(nproc)"
make install
popd

########## FFmpeg ###########################################################
git clone --depth 1 https://github.com/ffmpeg/ffmpeg.git
pushd ffmpeg
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" \
./configure \
  --prefix="$PREFIX" \
  --arch=armel --cpu=arm1176jzf-s --target-os=linux \
  --cross-prefix="$CROSS_PREFIX" \
  --enable-cross-compile \
  --extra-cflags="-I$PREFIX/include $CFLAGS" \
  --extra-ldflags="-L$PREFIX/lib" \
  --pkg-config-flags="--static" \
  --enable-gpl --enable-version3 \
  --enable-static --disable-shared \
  --disable-debug --disable-doc \
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
  --enable-zlib --enable-openssl
make -j"$(nproc)"
make install
popd

tar -C "$PREFIX/bin" -czf ffmpeg-armv6.tar.gz ffmpeg
echo "✅  ffmpeg-armv6.tar.gz created"