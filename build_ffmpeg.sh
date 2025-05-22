#!/usr/bin/env bash
set -euo pipefail
set -x   # включаем трассировку команд

PREFIX="/usr/local"
SYSROOT="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot"

echo "===== DATE & WHOAMI ====="
date
whoami

echo "===== ENVIRONMENT VARIABLES ====="
env

echo "===== PATH ====="
echo "$PATH"

echo "===== PREFIX & SYSROOT ====="
echo "PREFIX    = $PREFIX"
echo "SYSROOT   = $SYSROOT"

echo "===== PKG-CONFIG INFO ====="
which pkg-config
pkg-config --version
echo "PKG_CONFIG_PATH       = ${PKG_CONFIG_PATH:-<unset>}"
echo "PKG_CONFIG_SYSROOT_DIR= ${PKG_CONFIG_SYSROOT_DIR:-<unset>}"
echo "pkg-config pc_path    = $(pkg-config --variable pc_path pkg-config 2>/dev/null || echo '(error)')"

echo "===== LIST GLOBAL pkgconfig DIRS ====="
for d in /usr/lib/pkgconfig /usr/share/pkgconfig /usr/lib/arm-linux-gnueabihf/pkgconfig; do
  echo "--- $d ---"
  ls -l "$d" || echo "(не найден)"
done

echo "===== LIST SYSROOT pkgconfig DIRS ====="
for d in \
  "$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig" \
  "$SYSROOT/usr/lib/pkgconfig" \
  "$SYSROOT/usr/share/pkgconfig"; do
  echo "--- $d ---"
  ls -l "$d" || echo "(не найден)"
done

echo "===== PKG-CONFIG MODULES (v4l2/drm/zlib/x264) ====="
pkg-config --list-all | grep -E "libv4l2|v4l|drm|zlib|x264" || echo "(ничего)"

echo "===== PKG-CONFIG MODVERSION ====="
pkg-config --with-sysroot="$SYSROOT" --modversion libv4l2  || true
pkg-config --with-sysroot="$SYSROOT" --modversion libdrm    || true
pkg-config --with-sysroot="$SYSROOT" --modversion zlib      || true
pkg-config --with-sysroot="$SYSROOT" --modversion libx264   || true

# Попробуем скопировать .pc для проверки путей
echo "===== COPY .pc FILES FOR DEBUG ====="
mkdir -p "$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig.debug"
cp /usr/lib/arm-linux-gnueabihf/pkgconfig/*.pc                     \
   /usr/lib/pkgconfig/*.pc                                        \
   "$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig.debug" 2>&1 || true
echo "После копирования:"
ls -l "$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig.debug" || true

exit 1




if [ ! -d ffmpeg ]; then
  git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git ffmpeg
fi
pushd ffmpeg

export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
export PKG_CONFIG_PATH="$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig:$SYSROOT/usr/lib/pkgconfig:/usr/lib/pkgconfig"

./configure \
  --enable-cross-compile \
  --cross-prefix=armv6-unknown-linux-gnueabihf- \
  --cc=armv6-unknown-linux-gnueabihf-gcc \
  --arch=arm --cpu=arm1176jzf-s --target-os=linux \
  --sysroot="$SYSROOT" \
  --prefix="$PREFIX" \
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
  --disable-doc --disable-debug

make -j"$(nproc)"
make install

popd
