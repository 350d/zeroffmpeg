#!/usr/bin/env bash
set -euo pipefail

PREFIX="/usr/local"
SYSROOT="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot"

if [ ! -d ffmpeg ]; then
  git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git ffmpeg
fi
pushd ffmpeg

echo
echo "=== DEBUG: ENVIRONMENT ==="
echo "USER: $(whoami)"
echo "DATE: $(date)"
echo "PREFIX = $PREFIX"
echo "SYSROOT = $SYSROOT"
echo "PATH = $PATH"
echo "PKG_CONFIG_PATH = ${PKG_CONFIG_PATH:-<unset>}"
echo "PKG_CONFIG_SYSROOT_DIR = ${PKG_CONFIG_SYSROOT_DIR:-<unset>}"
echo "---- pkg-config info ----"
command -v pkg-config && pkg-config --version
pkg-config --variable pc_path pkg-config
echo

echo "=== DEBUG: LOOK FOR .pc FILES IN HOST PKGCONFIG DIRS ==="
for d in /usr/lib/pkgconfig /usr/share/pkgconfig /usr/lib/arm-linux-gnueabihf/pkgconfig; do
  echo "--- $d ---"
  ls -l "$d"/*.pc 2>/dev/null || echo "(no files)"
done
echo

echo "=== DEBUG: LOOK FOR .pc FILES IN SYSROOT PKGCONFIG DIRS ==="
for d in \
  "$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig" \
  "$SYSROOT/usr/lib/pkgconfig" \
  "$SYSROOT/usr/share/pkgconfig"; do
  echo "--- $d ---"
  ls -l "$d"/*.pc 2>/dev/null || echo "(no files)"
done
echo

echo "=== DEBUG: pkg-config list-all FILTER v4l2/drm/zlib/x264 ==="
pkg-config --list-all | grep -E 'libv4l2|v4l2|drm|zlib|x264' || true
echo

echo "=== Now running ./configure ==="
export PKG_CONFIG_PATH="/usr/lib/arm-linux-gnueabihf/pkgconfig:/usr/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"

./configure \
  --enable-cross-compile \
  --cross-prefix=armv6-unknown-linux-gnueabihf- \
  --cc=armv6-unknown-linux-gnueabihf-gcc \
  --arch=arm --cpu=arm1176jzf-s --target-os=linux \
  --sysroot="$SYSROOT" \
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
  --enable-openssl \
  --enable-version3 \
  --enable-libv4l2 \
  --enable-libdrm \
  --enable-zlib \
  --enable-gpl \
  --disable-doc --disable-debug \
  --prefix="$PREFIX"

make -j$(nproc)
make install

popd