# 🎬 ZeroFFmpeg - Optimized Multi-Stage Build for Ultra-Fast Rebuilds 🚀

# ============================================================================
# Stage 1: Base Environment with Dependencies (Cached Layer)
# ============================================================================
FROM dockcross/linux-armv6 AS base-deps

# 📦 Install system dependencies (this layer changes rarely, so cache it)
RUN apt-get update && apt-get install -y --no-install-recommends \
	# Core build tools
	git pkg-config build-essential yasm nasm cmake autoconf automake libtool \
	# SSL and compression
	libssl-dev zlib1g-dev \
	# Video libraries (for reference, we build our own)
	libv4l-dev v4l-utils libdrm-dev \
	# Image libraries  
	libjpeg-dev libpng-dev \
	# Cleanup to reduce layer size
	&& rm -rf /var/lib/apt/lists/* \
	&& apt-get clean

# 🔧 Set up build environment
ENV PKG_CONFIG_PATH="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig"
ENV PKG_CONFIG_LIBDIR="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig"
ENV PKG_CONFIG_SYSROOT_DIR="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot"

# 📁 Create directory structure (cache this)
RUN mkdir -p /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib && \
	mkdir -p /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/include && \
	mkdir -p /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig && \
	chmod -R 777 /usr/xcc/armv6-unknown-linux-gnueabihf

# ============================================================================
# Stage 2: Pre-built Dependencies (Heavy Caching Layer)
# ============================================================================
FROM base-deps AS deps-builder

# 🗜️ Build zlib (cache this, it rarely changes)
RUN echo "🗜️ Building zlib..." && \
	git clone --depth 1 https://github.com/madler/zlib.git /tmp/zlib && \
	cd /tmp/zlib && \
	export CC=armv6-unknown-linux-gnueabihf-gcc && \
	export AR=armv6-unknown-linux-gnueabihf-ar && \
	export RANLIB=armv6-unknown-linux-gnueabihf-ranlib && \
	CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os" \
	./configure --prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr --static && \
	make -j$(nproc) && make install && \
	echo 'prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr
exec_prefix=${prefix}
libdir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib
includedir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/include

Name: zlib
Description: zlib compression library
Version: 1.2.13
Libs: -L${libdir} -lz
Cflags: -I${includedir}' > /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/zlib.pc && \
	rm -rf /tmp/zlib

# 🔐 Build OpenSSL (cache this, it rarely changes)
RUN echo "🔐 Building OpenSSL..." && \
	git clone --depth 1 --branch OpenSSL_1_1_1-stable https://github.com/openssl/openssl.git /tmp/openssl && \
	cd /tmp/openssl && \
	CC="armv6-unknown-linux-gnueabihf-gcc" \
	AR="armv6-unknown-linux-gnueabihf-ar" \
	RANLIB="armv6-unknown-linux-gnueabihf-ranlib" \
	./Configure linux-generic32 \
		--prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr \
		--openssldir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/ssl \
		no-shared no-dso no-engine no-unit-test no-ui-console no-asm -static \
		-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os && \
	# Fix double prefix issue
	sed -i "s/CC=\$(CROSS_COMPILE)armv6-unknown-linux-gnueabihf-gcc/CC=armv6-unknown-linux-gnueabihf-gcc/" Makefile && \
	sed -i "s/armv6-unknown-linux-gnueabihf-armv6-unknown-linux-gnueabihf-/armv6-unknown-linux-gnueabihf-/g" Makefile && \
	sed -i "s/AR=\$(CROSS_COMPILE)armv6-unknown-linux-gnueabihf-ar/AR=armv6-unknown-linux-gnueabihf-ar/" Makefile && \
	sed -i "s/RANLIB=\$(CROSS_COMPILE)armv6-unknown-linux-gnueabihf-ranlib/RANLIB=armv6-unknown-linux-gnueabihf-ranlib/" Makefile && \
	make -j$(nproc) build_libs && make install_dev && \
	# Create pkg-config files
	echo 'prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr
exec_prefix=${prefix}
libdir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib
includedir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/include

Name: OpenSSL-libssl
Description: Secure Sockets Layer and cryptography libraries - libssl
Version: 1.1.1
Requires: libcrypto
Libs: -L${libdir} -lssl
Cflags: -I${includedir}' > /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libssl.pc && \
	echo 'prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr
exec_prefix=${prefix}
libdir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib
includedir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/include

Name: OpenSSL-libcrypto
Description: OpenSSL cryptography library
Version: 1.1.1
Libs: -L${libdir} -lcrypto
Libs.private: -ldl -pthread
Cflags: -I${includedir}' > /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libcrypto.pc && \
	rm -rf /tmp/openssl

# 🎬 Build x264 (cache this, it rarely changes)
RUN echo "🎬 Building x264..." && \
	git clone --depth 1 https://code.videolan.org/videolan/x264.git /tmp/x264 && \
	cd /tmp/x264 && \
	export CC=armv6-unknown-linux-gnueabihf-gcc && \
	export AR=armv6-unknown-linux-gnueabihf-ar && \
	export RANLIB=armv6-unknown-linux-gnueabihf-ranlib && \
	./configure \
		--cross-prefix=armv6-unknown-linux-gnueabihf- \
		--host=arm-linux-gnueabihf \
		--enable-static \
		--disable-cli \
		--disable-opencl \
		--disable-thread \
		--disable-asm \
		--extra-cflags="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os" \
		--prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr && \
	make -j$(nproc) && make install && \
	echo 'prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr
exec_prefix=${prefix}
libdir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib
includedir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/include

Name: x264
Description: x264 library
Version: 0.164.x
Requires:
Libs: -L${libdir} -lx264
Libs.private: -lpthread -lm
Cflags: -I${includedir}' > /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/x264.pc && \
	rm -rf /tmp/x264

# ============================================================================
# Stage 3: FFmpeg Builder (Fast rebuild layer)
# ============================================================================
FROM deps-builder AS ffmpeg-builder

# 📥 Clone FFmpeg (this layer may change more often)
RUN echo "📥 Cloning FFmpeg..." && \
	git clone --depth 1 --branch n6.1.1 https://git.ffmpeg.org/ffmpeg.git /tmp/ffmpeg

# 🎥 Build FFmpeg directly
WORKDIR /tmp
RUN echo "🎥 Building FFmpeg with pre-built dependencies..." && \
	mkdir -p /tmp/install && \
	mkdir -p build && cd build && \
	echo "⚙️  Configuring FFmpeg..." && \
	PKG_CONFIG_PATH="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig" \
	PKG_CONFIG_LIBDIR="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig" \
	PKG_CONFIG_SYSROOT_DIR="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot" \
	/tmp/ffmpeg/configure \
		--prefix="/tmp/install" \
		--cross-prefix=armv6-unknown-linux-gnueabihf- \
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
		--enable-libx264 \
		--enable-encoder=libx264 \
		--enable-demuxer=rtp,rtsp,h264,mjpeg,aac,mp3,flv,ogg,opus,adts,image2,image2pipe \
		--enable-filter=showinfo,split,scale,format,colorspace,fps,tblend,blackframe \
		--enable-decoder=h264,mjpeg,aac,mp3float,vorbis,opus,pcm_s16le \
		--enable-parser=h264,mjpeg,aac,mpegaudio,vorbis,opus \
		--enable-encoder=mjpeg,rawvideo,aac,wrapped_avframe \
		--enable-protocol=http,https,tls,tcp,udp,file,rtp \
		--enable-muxer=mjpeg,mp4,null,image2 \
		--enable-bsf=mjpeg2jpeg \
		--enable-indev=lavfi \
		--extra-cflags="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os -I/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/include" \
		--extra-ldflags="--sysroot=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot -static -L/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib -lssl -lcrypto" \
		--pkg-config=pkg-config \
		--pkg-config-flags="--static" \
		--sysroot="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot" && \
	echo "⏳ Building FFmpeg..." && \
	make -j$(nproc) && \
	echo "📦 Installing FFmpeg..." && \
	make install && \
	echo "✅ FFmpeg build complete!" && \
	echo "📊 Built files:" && \
	ls -la /tmp/install/bin/

# ============================================================================
# Stage 4: Final Output (Minimal layer)
# ============================================================================
FROM scratch AS output

# 📤 Copy only the final binaries
COPY --from=ffmpeg-builder /tmp/install/bin/ /

# 🎯 Default: just show the binary
CMD ["./ffmpeg", "-version"]