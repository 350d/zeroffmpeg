#!/bin/bash

# FFmpeg configuration options based on OPTION variable
# Usage: source ffmpeg-configs.sh && get_ffmpeg_config $OPTION

get_ffmpeg_config() {
    local option=${1:-normal}
    
    # Base configuration for all builds
    local base_config="
        --prefix=/tmp/install
        --cross-prefix=armv6-unknown-linux-gnueabihf-
        --arch=arm
        --target-os=linux
        --enable-cross-compile
        --disable-runtime-cpudetect
        --disable-shared
        --enable-static
        --disable-doc
        --disable-debug
        --extra-cflags=-march=armv6 -mfpu=vfp -mfloat-abi=hard -Os -w -I/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/include
        --extra-ldflags=--sysroot=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot -static -L/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot/usr/lib
        --pkg-config=pkg-config
        --pkg-config-flags=--static
        --sysroot=/usr/xcc/armv6-unknown-linux-gnueabihf/armv6-unknown-linux-gnueabihf/sysroot"

    case "$option" in
        "minimal")
            echo "$base_config
                --disable-everything
                --enable-gpl
                --enable-zlib
                --enable-decoder=h264,mjpeg,rawvideo
                --enable-encoder=mjpeg,rawvideo
                --enable-demuxer=h264,mjpeg,image2
                --enable-muxer=mjpeg,image2
                --enable-parser=h264,mjpeg
                --enable-protocol=file,pipe
                --enable-filter=scale,format
                --enable-indev=v4l2
                --enable-outdev=v4l2"
            ;;
            
        "normal")
            echo "$base_config
                --disable-everything
                --enable-gpl
                --enable-nonfree
                --enable-version3
                --enable-openssl
                --enable-zlib
                --enable-libx264
                --enable-filter=concat,testsrc,showinfo,split,scale,format,colorspace,fps,tblend,blackframe,setsar
                --enable-demuxer=rtp,rtsp,h264,mjpeg,aac,mp3,flv,ogg,opus,adts,image2,image2pipe
                --enable-decoder=h264_v4l2m2m,h264,mjpeg,rawvideo,aac,mp3float,vorbis,opus,pcm_s16le
                --enable-encoder=h264_v4l2m2m,mjpeg,rawvideo,aac,wrapped_avframe,libx264
                --enable-parser=h264,mjpeg,aac,mpegaudio,vorbis,opus
                --enable-protocol=rtsp,pipe,http,https,tls,tcp,udp,file,rtp
                --enable-muxer=rtsp,mjpeg,mp4,null,image2,rtp
                --enable-bsf=mjpeg2jpeg,h264_mp4toannexb,h264_metadata,null,extract_extradata
                --enable-indev=lavfi,v4l2
                --enable-outdev=v4l2"
            ;;
            
        "full")
            echo "$base_config
                --enable-gpl
                --enable-nonfree
                --enable-version3
                --enable-openssl
                --enable-zlib
                --enable-libx264
                --enable-filters
                --enable-demuxers
                --enable-decoders
                --enable-encoders
                --enable-parsers
                --enable-protocols
                --enable-muxers
                --enable-bsfs
                --enable-indevs
                --enable-outdevs
                --enable-postproc
                --enable-swscale
                --enable-swresample
                --enable-avfilter
                --enable-avformat
                --enable-avcodec
                --enable-avutil"
            ;;
            
        *)
            echo "Error: Unknown option '$option'. Available options: minimal, normal, full" >&2
            exit 1
            ;;
    esac
} 