#!/usr/bin/env bash
set -euxo pipefail

# 1) Debug: environment info
echo "=== Environment ==="
env | sort
echo "=== GCC version ==="
${CROSS_COMPILE}gcc --version
echo "=== Working directory ==="
pwd
ls -la

# 2) Clone latest FFmpeg if not exists
FFMPEG_SRC="ffmpeg"
if [ ! -d "$FFMPEG_SRC" ]; then
    echo "Cloning latest FFmpeg..."
    git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git "$FFMPEG_SRC"
fi

# 3) Prepare build environment
ARCH_FLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os"
PREFIX="$(pwd)/install"
mkdir -p build

# 4) Configure and build FFmpeg
cd build
echo "=== Configuring FFmpeg ==="
bash -x ../$FFMPEG_SRC/configure \
    --prefix="$PREFIX" \
    --cross-prefix=$CROSS_COMPILE \
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
    --enable-encoder=libx264,rawvideo \
    --enable-libx264 \
    --enable-zlib \
    --enable-indev=alsa \
    --enable-encoder=aac \
    --enable-demuxer=aac,mp3,flv,ogg,opus,adts \
    --enable-parser=aac,mpegaudio,vorbis,opus \
    --enable-decoder=aac,mp3float,vorbis,opus,pcm_s16le \
    --enable-demuxer=image2 \
    --enable-demuxer=image2pipe \
    --enable-muxer=image2 \
    --extra-cflags="$ARCH_FLAGS" \
    --extra-ldflags="-static"

echo "=== Building FFmpeg ==="
make -j"$(nproc)"
make install

echo "=== Build complete ==="
ls -la $PREFIX/bin/
file $PREFIX/bin/ffmpeg
