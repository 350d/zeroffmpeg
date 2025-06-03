# 🎬 ZeroFFmpeg - Optimized Multi-Stage Build for Ultra-Fast Rebuilds 🚀

# ============================================================================
# Stage 1: Base Environment with Dependencies (Cached Layer)
# ============================================================================
FROM dockcross/linux-armv6 AS base-deps

# 📦 Install system dependencies (this layer changes rarely, so cache it)
RUN apt-get update >/dev/null 2>&1 && apt-get install -y --no-install-recommends \
	# Core build tools
	git pkg-config build-essential yasm nasm cmake autoconf automake libtool \
	# SSL and compression
	libssl-dev zlib1g-dev \
	# Video libraries (for reference, we build our own)
	libv4l-dev v4l-utils \
	# Image libraries  
	libjpeg-dev libpng-dev \
	# Additional tools for V4L2 builds
	gettext \
	# Cleanup to reduce layer size
	>/dev/null 2>&1 && rm -rf /var/lib/apt/lists/* && apt-get clean >/dev/null 2>&1

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
RUN git clone --depth 1 https://github.com/madler/zlib.git /tmp/zlib >/dev/null 2>&1 && \
	cd /tmp/zlib && \
	export CC=armv6-unknown-linux-gnueabihf-gcc && \
	export AR=armv6-unknown-linux-gnueabihf-ar && \
	export RANLIB=armv6-unknown-linux-gnueabihf-ranlib && \
	CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os" \
	./configure --prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr --static >/dev/null 2>&1 && \
	make -j$(nproc) >/dev/null 2>&1 && make install >/dev/null 2>&1 && \
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
RUN git clone --depth 1 --branch OpenSSL_1_1_1-stable https://github.com/openssl/openssl.git /tmp/openssl >/dev/null 2>&1 && \
	cd /tmp/openssl && \
	CC="armv6-unknown-linux-gnueabihf-gcc" \
	AR="armv6-unknown-linux-gnueabihf-ar" \
	RANLIB="armv6-unknown-linux-gnueabihf-ranlib" \
	./Configure linux-generic32 \
		--prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr \
		--openssldir=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/ssl \
		no-shared no-dso no-engine no-unit-test no-ui-console no-asm -static \
		-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os >/dev/null 2>&1 && \
	# Fix double prefix issue
	sed -i "s/CC=\$(CROSS_COMPILE)armv6-unknown-linux-gnueabihf-gcc/CC=armv6-unknown-linux-gnueabihf-gcc/" Makefile && \
	sed -i "s/armv6-unknown-linux-gnueabihf-armv6-unknown-linux-gnueabihf-/armv6-unknown-linux-gnueabihf-/g" Makefile && \
	sed -i "s/AR=\$(CROSS_COMPILE)armv6-unknown-linux-gnueabihf-ar/AR=armv6-unknown-linux-gnueabihf-ar/" Makefile && \
	sed -i "s/RANLIB=\$(CROSS_COMPILE)armv6-unknown-linux-gnueabihf-ranlib/RANLIB=armv6-unknown-linux-gnueabihf-ranlib/" Makefile && \
	make -j$(nproc) build_libs >/dev/null 2>&1 && make install_dev >/dev/null 2>&1 && \
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
RUN git clone --depth 1 https://code.videolan.org/videolan/x264.git /tmp/x264 >/dev/null 2>&1 && \
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
		--prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr >/dev/null 2>&1 && \
	make -j$(nproc) >/dev/null 2>&1 && make install >/dev/null 2>&1 && \
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
RUN git clone --depth 1 --branch v2.5.0 https://github.com/cisco/libsrtp.git /tmp/libsrtp >/dev/null 2>&1 && \
	cd /tmp/libsrtp && \
	export CC=armv6-unknown-linux-gnueabihf-gcc && \
	export AR=armv6-unknown-linux-gnueabihf-ar && \
	export RANLIB=armv6-unknown-linux-gnueabihf-ranlib && \
	export CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os" && \
	./configure \
		--host=arm-linux-gnueabihf \
		--prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr >/dev/null 2>&1 && \
	make -j$(nproc) >/dev/null 2>&1 && \
	make install >/dev/null 2>&1 && \
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
	rm -rf /tmp/libsrtp

# 📹 Build libv4l2 (for V4L2 camera support)
RUN git clone --depth 1 --branch v4l-utils-1.24.1 https://git.linuxtv.org/v4l-utils.git /tmp/v4l-utils >/dev/null 2>&1 && \
	cd /tmp/v4l-utils && \
	export CC=armv6-unknown-linux-gnueabihf-gcc && \
	export CXX=armv6-unknown-linux-gnueabihf-g++ && \
	export AR=armv6-unknown-linux-gnueabihf-ar && \
	export RANLIB=armv6-unknown-linux-gnueabihf-ranlib && \
	export STRIP=armv6-unknown-linux-gnueabihf-strip && \
	export PKG_CONFIG_PATH="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig" && \
	export CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os" && \
	export CXXFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os" && \
	./bootstrap.sh >/dev/null 2>&1 && \
	./configure \
		--host=arm-linux-gnueabihf \
		--prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr \
		--disable-shared \
		--enable-static \
		--disable-v4l-utils \
		--disable-qv4l2 \
		--disable-qvidcap \
		--without-libudev >/dev/null 2>&1 && \
	make -j$(nproc) >/dev/null 2>&1 && \
	make install >/dev/null 2>&1 && \
	# Create pkg-config file for libv4l2
	echo "prefix=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr" > /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libv4l2.pc && \
	echo "exec_prefix=\${prefix}" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libv4l2.pc && \
	echo "libdir=\${prefix}/lib" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libv4l2.pc && \
	echo "includedir=\${prefix}/include" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libv4l2.pc && \
	echo "" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libv4l2.pc && \
	echo "Name: libv4l2" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libv4l2.pc && \
	echo "Description: Video4Linux2 library" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libv4l2.pc && \
	echo "Version: 1.24.1" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libv4l2.pc && \
	echo "Libs: -L\${libdir} -lv4l2 -lv4lconvert" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libv4l2.pc && \
	echo "Cflags: -I\${includedir}" >> /usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig/libv4l2.pc && \
	rm -rf /tmp/v4l-utils

# ============================================================================
# Stage 3: FFmpeg Builder (Fast rebuild layer)
# ============================================================================
FROM deps-builder AS ffmpeg-builder

# Set build option (default: normal)
ARG OPTION=normal
ENV OPTION=${OPTION}

# 📥 Clone FFmpeg (this layer may change more often)  
RUN git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git /tmp/ffmpeg >/dev/null 2>&1

# 📝 Copy FFmpeg configuration script
COPY ffmpeg-configs.sh /tmp/ffmpeg-configs.sh
RUN chmod +x /tmp/ffmpeg-configs.sh

# 🎥 Build FFmpeg directly
WORKDIR /tmp

# Configure FFmpeg based on OPTION
RUN mkdir -p /tmp/install && \
	mkdir -p build && cd build && \
	export PKG_CONFIG_PATH="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig" && \
	export PKG_CONFIG_LIBDIR="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib/pkgconfig" && \
	export PKG_CONFIG_SYSROOT_DIR="/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot" && \
	# Source configuration and get options using bash
	bash -c ". /tmp/ffmpeg-configs.sh && get_ffmpeg_config \"$OPTION\" > /tmp/ffmpeg_options.txt" && \
	echo "Building FFmpeg with $OPTION configuration..." && \
	# Configure FFmpeg with selected options
	/tmp/ffmpeg/configure $(cat /tmp/ffmpeg_options.txt) >/dev/null 2>&1

# Build and Install FFmpeg
RUN cd build && \
	make -j$(nproc) 2>&1 | grep -E "(CC|LD|GEN|INSTALL)" || true && \
	make install >/dev/null 2>&1

# ============================================================================
# Stage 4: Final Output (Minimal layer)
# ============================================================================
FROM scratch AS output

# 📤 Copy only the final binaries from the correct stage
COPY --from=ffmpeg-builder /tmp/install/bin/ffmpeg /ffmpeg
COPY --from=ffmpeg-builder /tmp/install/bin/ffprobe /ffprobe

# 🎯 Default: just show the binary
CMD ["./ffmpeg", "-version"]