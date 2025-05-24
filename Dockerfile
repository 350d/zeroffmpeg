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
	git clone --depth 1 https://github.com/madler/zlib.git /tmp/zlib >/dev/null 2>&1 && \
	cd /tmp/zlib && \
	export CC=armv6-unknown-linux-gnueabihf-gcc && \
	export AR=armv6-unknown-linux-gnueabihf-ar && \
	export RANLIB=armv6-unknown-linux-gnueabihf-ranlib && \
	CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os" \
	./configure --prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr --static >/dev/null && \
	make -j$(nproc) >/dev/null && make install >/dev/null && \
	# Create simple pkg-config file for zlib
	echo "prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr" > /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/zlib.pc && \
	echo "exec_prefix=\${prefix}" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/zlib.pc && \
	echo "libdir=\${prefix}/lib" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/zlib.pc && \
	echo "includedir=\${prefix}/include" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/zlib.pc && \
	echo "" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/zlib.pc && \
	echo "Name: zlib" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/zlib.pc && \
	echo "Description: zlib compression library" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/zlib.pc && \
	echo "Version: 1.2.13" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/zlib.pc && \
	echo "Libs: -L\${libdir} -lz" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/zlib.pc && \
	echo "Cflags: -I\${includedir}" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/zlib.pc && \
	rm -rf /tmp/zlib

# 🔐 Build OpenSSL (cache this, it rarely changes)
RUN echo "🔐 Building OpenSSL..." && \
	git clone --depth 1 --branch OpenSSL_1_1_1-stable https://github.com/openssl/openssl.git /tmp/openssl >/dev/null 2>&1 && \
	cd /tmp/openssl && \
	CC="armv6-unknown-linux-gnueabihf-gcc" \
	AR="armv6-unknown-linux-gnueabihf-ar" \
	RANLIB="armv6-unknown-linux-gnueabihf-ranlib" \
	./Configure linux-generic32 \
		--prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr \
		--openssldir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/ssl \
		no-shared no-dso no-engine no-unit-test no-ui-console no-asm -static \
		-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os >/dev/null && \
	# Fix double prefix issue
	sed -i "s/CC=\$(CROSS_COMPILE)armv6-unknown-linux-gnueabihf-gcc/CC=armv6-unknown-linux-gnueabihf-gcc/" Makefile && \
	sed -i "s/armv6-unknown-linux-gnueabihf-armv6-unknown-linux-gnueabihf-/armv6-unknown-linux-gnueabihf-/g" Makefile && \
	sed -i "s/AR=\$(CROSS_COMPILE)armv6-unknown-linux-gnueabihf-ar/AR=armv6-unknown-linux-gnueabihf-ar/" Makefile && \
	sed -i "s/RANLIB=\$(CROSS_COMPILE)armv6-unknown-linux-gnueabihf-ranlib/RANLIB=armv6-unknown-linux-gnueabihf-ranlib/" Makefile && \
	make -j$(nproc) build_libs >/dev/null && make install_dev >/dev/null && \
	# Create pkg-config files for OpenSSL
	echo "prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr" > /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libssl.pc && \
	echo "exec_prefix=\${prefix}" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libssl.pc && \
	echo "libdir=\${prefix}/lib" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libssl.pc && \
	echo "includedir=\${prefix}/include" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libssl.pc && \
	echo "" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libssl.pc && \
	echo "Name: OpenSSL-libssl" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libssl.pc && \
	echo "Description: Secure Sockets Layer and cryptography libraries" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libssl.pc && \
	echo "Version: 1.1.1" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libssl.pc && \
	echo "Requires: libcrypto" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libssl.pc && \
	echo "Libs: -L\${libdir} -lssl" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libssl.pc && \
	echo "Cflags: -I\${includedir}" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libssl.pc && \
	echo "prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr" > /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libcrypto.pc && \
	echo "exec_prefix=\${prefix}" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libcrypto.pc && \
	echo "libdir=\${prefix}/lib" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libcrypto.pc && \
	echo "includedir=\${prefix}/include" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libcrypto.pc && \
	echo "" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libcrypto.pc && \
	echo "Name: OpenSSL-libcrypto" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libcrypto.pc && \
	echo "Description: OpenSSL cryptography library" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libcrypto.pc && \
	echo "Version: 1.1.1" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libcrypto.pc && \
	echo "Libs: -L\${libdir} -lcrypto" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libcrypto.pc && \
	echo "Libs.private: -ldl -pthread" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libcrypto.pc && \
	echo "Cflags: -I\${includedir}" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libcrypto.pc && \
	rm -rf /tmp/openssl

# 🎬 Build x264 (cache this, it rarely changes)
RUN echo "🎬 Building x264..." && \
	git clone --depth 1 https://code.videolan.org/videolan/x264.git /tmp/x264 >/dev/null 2>&1 && \
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
		--prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr >/dev/null && \
	make -j$(nproc) >/dev/null && make install >/dev/null && \
	# Create pkg-config file for x264
	echo "prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr" > /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/x264.pc && \
	echo "exec_prefix=\${prefix}" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/x264.pc && \
	echo "libdir=\${prefix}/lib" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/x264.pc && \
	echo "includedir=\${prefix}/include" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/x264.pc && \
	echo "" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/x264.pc && \
	echo "Name: x264" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/x264.pc && \
	echo "Description: x264 library" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/x264.pc && \
	echo "Version: 0.164.x" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/x264.pc && \
	echo "Libs: -L\${libdir} -lx264" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/x264.pc && \
	echo "Libs.private: -lpthread -lm" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/x264.pc && \
	echo "Cflags: -I\${includedir}" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/x264.pc && \
	rm -rf /tmp/x264

# 🔒 Build libsrtp2 (for SRTP support)
RUN echo "🔒 Building libsrtp2..." && \
	git clone --depth 1 --branch v2.5.0 https://github.com/cisco/libsrtp.git /tmp/libsrtp >/dev/null 2>&1 && \
	cd /tmp/libsrtp && \
	export CC=armv6-unknown-linux-gnueabihf-gcc && \
	export AR=armv6-unknown-linux-gnueabihf-ar && \
	export RANLIB=armv6-unknown-linux-gnueabihf-ranlib && \
	export CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os" && \
	./configure \
		--host=arm-linux-gnueabihf \
		--prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr || \
	(echo "❌ libsrtp2 configure failed!" && \
	echo "📋 Configure output:" && \
	cat config.log 2>/dev/null || echo "No config.log found" && \
	exit 1) && \
	make -j$(nproc) || \
	(echo "❌ libsrtp2 build failed!" && exit 1) && \
	make install || \
	(echo "❌ libsrtp2 install failed!" && exit 1) && \
	# Verify libsrtp2 was built
	ls -la /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/libsrtp2* && \
	# Create pkg-config file for libsrtp2
	echo "prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr" > /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libsrtp2.pc && \
	echo "exec_prefix=\${prefix}" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libsrtp2.pc && \
	echo "libdir=\${prefix}/lib" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libsrtp2.pc && \
	echo "includedir=\${prefix}/include" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libsrtp2.pc && \
	echo "" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libsrtp2.pc && \
	echo "Name: libsrtp2" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libsrtp2.pc && \
	echo "Description: Secure Real-time Transport Protocol (SRTP) library" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libsrtp2.pc && \
	echo "Version: 2.5.0" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libsrtp2.pc && \
	echo "Libs: -L\${libdir} -lsrtp2" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libsrtp2.pc && \
	echo "Cflags: -I\${includedir}" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libsrtp2.pc && \
	echo "✅ libsrtp2 build complete!" && \
	rm -rf /tmp/libsrtp

# ============================================================================
# Stage 3: FFmpeg Builder (Fast rebuild layer)
# ============================================================================
FROM deps-builder AS ffmpeg-builder

# 📥 Clone FFmpeg (this layer may change more often)  
RUN echo "📥 Cloning FFmpeg latest..." && \
	git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git /tmp/ffmpeg >/dev/null 2>&1

# 🎥 Build FFmpeg directly
WORKDIR /tmp

# Dependencies are ready from previous stages

# Verify dependencies before FFmpeg configure
RUN echo "🔍 Verifying dependencies..." && \
	echo "📋 Available libraries:" && \
	ls -la /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/ | grep -E "(libz|libssl|libcrypto|libx264|libsrtp2)" && \
	echo "📋 Available pkg-config files:" && \
	ls -la /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/ && \
	echo "📋 Testing pkg-config..." && \
	export PKG_CONFIG_PATH="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig" && \
	export PKG_CONFIG_LIBDIR="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig" && \
	export PKG_CONFIG_SYSROOT_DIR="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot" && \
	pkg-config --exists zlib && echo "✅ zlib pkg-config OK" || echo "❌ zlib pkg-config failed" && \
	pkg-config --exists libssl && echo "✅ libssl pkg-config OK" || echo "❌ libssl pkg-config failed" && \
	pkg-config --exists libcrypto && echo "✅ libcrypto pkg-config OK" || echo "❌ libcrypto pkg-config failed" && \
	pkg-config --exists x264 && echo "✅ x264 pkg-config OK" || echo "❌ x264 pkg-config failed" && \
	pkg-config --exists libsrtp2 && echo "✅ libsrtp2 pkg-config OK" || echo "❌ libsrtp2 pkg-config failed"

# Configure FFmpeg
RUN echo "⚙️  Configuring FFmpeg..." && \
	mkdir -p /tmp/install && \
	mkdir -p build && cd build && \
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

		#--enable-gpl \
		#--enable-nonfree \
		#--enable-version3 \
		#--enable-openssl \
		#--enable-zlib \
		#--enable-libx264 \
		#--enable-encoder=libx264 \
		#--enable-demuxer=rtp,rtsp,h264,mjpeg,aac,mp3,flv,ogg,opus,adts,image2,image2pipe \
		#--enable-filter=showinfo,split,scale,format,colorspace,fps,tblend,blackframe \
		#--enable-decoder=h264_v4l2m2m,h264,mjpeg,aac,mp3float,vorbis,opus,pcm_s16le \
		#--enable-parser=h264,mjpeg,aac,mpegaudio,vorbis,opus \
		#--enable-encoder=mjpeg,rawvideo,aac,wrapped_avframe \
		#--enable-protocol=http,https,tls,tcp,udp,file,rtp \
		#--enable-muxer=mjpeg,mp4,null,image2 \
		#--enable-bsf=mjpeg2jpeg \
		#--enable-indev=lavfi \

		--enable-gpl \
		--enable-zlib \
		--enable-filter=showinfo,split,scale,format,colorspace,fps,tblend,blackframe,setsar \
		--enable-demuxer=rtp,rtsp,h264,mjpeg,image2,image2pipe \
		--enable-decoder=h264,mjpeg \
		--enable-encoder=mjpeg,rawvideo,wrapped_avframe \
		--enable-parser=h264,mjpeg \
		--enable-protocol=http,tcp,udp,file,rtp \
		--enable-muxer=mjpeg,mp4,null,image2,rtp \
		--enable-bsf=mjpeg2jpeg \
		--enable-indev=lavfi \
		--enable-libx264 \

		--extra-cflags="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os -I/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/include" \
		--extra-ldflags="--sysroot=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot -static -L/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib" \
		--pkg-config=pkg-config \
		--pkg-config-flags="--static" \
		--sysroot="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot" 2>&1 | tee configure.log && \
	echo "✅ FFmpeg configure successful!" || \
	(echo "❌ FFmpeg configure failed!" && \
	echo "📋 Configure output (last 100 lines):" && \
	tail -100 configure.log && \
	echo "📋 Config log (last 100 lines):" && \
	tail -100 ffbuild/config.log 2>/dev/null || echo "No config.log found" && \
	exit 1)

# Build and Install FFmpeg
RUN echo "⏳ Building FFmpeg..." && \
	cd build && \
	make -j$(nproc) 2>&1 | tee build.log || \
	(echo "❌ FFmpeg build failed!" && \
	echo "📋 Last 50 lines of build log:" && \
	tail -50 build.log && \
	exit 1) && \
	echo "📦 Installing FFmpeg..." && \
	make install >/dev/null && \
	echo "✅ FFmpeg build complete!"

# ============================================================================
# Stage 4: Final Output (Minimal layer)
# ============================================================================
FROM scratch AS output

# 📤 Copy only the final binaries
COPY --from=ffmpeg-builder /tmp/install/bin/ /

# 🎯 Default: just show the binary
CMD ["./ffmpeg", "-version"]