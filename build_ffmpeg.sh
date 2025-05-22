#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Paths
###############################################################################
PREFIX="/usr/local"
SYSROOT="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot"

###############################################################################
# Ensure pkg-config will look in your ARMHF sysroot
###############################################################################
export PKG_CONFIG_PATH="$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"

###############################################################################
# Download and unpack ARMHF dev packages (including libc) into sysroot
###############################################################################
# List of packages to extract
PKGS=( 
  libc6-dev:armhf 
  libv4l-dev:armhf 
  libdrm-dev:armhf 
  zlib1g-dev:armhf 
  libssl-dev:armhf 
  libx264-dev:armhf 
  libjpeg-dev:armhf 
  libpng-dev:armhf 
)

# Download .deb files
apt-get update
apt-get download "${PKGS[@]}"

# Unpack headers, libs and .pc files into sysroot
mkdir -p "$SYSROOT/usr/include" \
         "$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig" \
         "$SYSROOT/usr/lib/arm-linux-gnueabihf"
for DEB in *.deb; do
  TMP=$(mktemp -d)
  dpkg-deb -x "$DEB" "$TMP"
  # copy include files
  cp -r "$TMP/usr/include"/* "$SYSROOT/usr/include/" || true
  # copy libraries
  cp -r "$TMP/usr/lib/arm-linux-gnueabihf"/* "$SYSROOT/usr/lib/arm-linux-gnueabihf/" || true
  # copy pkg-config metadata
  cp "$TMP/usr/lib/arm-linux-gnueabihf/pkgconfig"/*.pc "$SYSROOT/usr/lib/arm-linux-gnueabihf/pkgconfig/" 2>/dev/null || true
  rm -rf "$TMP"
done
rm -f *.deb

###############################################################################
# Clone FFmpeg if needed
###############################################################################
if [ ! -d ffmpeg ]; then
  git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git ffmpeg
fi
cd ffmpeg

###############################################################################
# Configure
###############################################################################
./configure \
  --enable-cross-compile \
  --cross-prefix=armv6-unknown-linux-gnueabihf- \
  --cc=armv6-unknown-linux-gnueabihf-gcc \
  --ar=armv6-unknown-linux-gnueabihf-ar \
  --as=armv6-unknown-linux-gnueabihf-as \
  --ld=armv6-unknown-linux-gnueabihf-ld \
  --nm=armv6-unknown-linux-gnueabihf-nm \
  --objdump=armv6-unknown-linux-gnueabihf-objdump \
  --strip=armv6-unknown-linux-gnueabihf-strip \
  --arch=arm --cpu=arm1176jzf-s --target-os=linux \
  --sysroot="$SYSROOT" \
  --prefix="$PREFIX" \
  \
  --enable-protocol=http,https,tls,tcp,udp,file,rtp \
  --enable-demuxer=rtp,rtsp,h264,mjpeg,image2,image2pipe \
  --enable-parser=h264,mjpeg \
  --enable-decoder=h264,mjpeg \
  --enable-encoder=mjpeg,libx264 \
  --enable-muxer=mjpeg,mp4,image2,null \
  --enable-bsf=mjpeg2jpeg \
  --enable-filter=showinfo,scale,format,colorspace \
  --enable-indev=lavfi \
  \
  --enable-libx264 \
  --enable-libv4l2 \
  --enable-libdrm \
  --enable-openssl \
  --enable-zlib \
  --enable-gpl \
  --enable-version3 \
  \
  --disable-doc \
  --disable-debug \
  --disable-ffplay

###############################################################################
# Build & Install
###############################################################################
make -j$(nproc)
make install

###############################################################################
# Package
###############################################################################
tar czf ../ffmpeg-armv6.tar.gz -C "$PREFIX" .
