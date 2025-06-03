# 🛠️ ZeroFFmpeg Build Guide

## 🚀 Quick Start

### Using GitHub Actions (Recommended)
1. Go to **Actions** tab → **"Build FFmpeg"** workflow
2. Click **"Run workflow"** 
3. Select configuration:
   - **minimal** (3-8MB) - Basic operations
   - **normal** (15-25MB) - Full multimedia (default)
   - **full** (35-50MB) - Complete FFmpeg
4. Download artifacts when complete

### Local Docker Build
```bash
# Build normal configuration
docker build --build-arg OPTION=normal --target output --output type=local,dest=./output .

# Build minimal
docker build --build-arg OPTION=minimal --target output --output type=local,dest=./output .

# Build full  
docker build --build-arg OPTION=full --target output --output type=local,dest=./output .
```

## 📦 Configuration Details

### 🔧 Minimal
- H.264, MJPEG codecs
- V4L2 camera support
- Basic filters (scale, format)
- File and pipe protocols only

### ⚙️ Normal (Default)
- All minimal features +
- H.264 hardware acceleration (V4L2 M2M)
- Streaming (RTSP, HTTP/HTTPS, RTP)
- Audio codecs (AAC, MP3, Opus)
- Advanced filters and processing
- OpenSSL and x264 support

### 🔥 Full
- Complete FFmpeg with all features
- All codecs, filters, protocols
- Maximum compatibility

## 🎯 Architecture

```
ffmpeg-configs.sh → Dockerfile → GitHub Actions → Static Binaries
```

## ✨ Benefits

- ✅ Clean Docker multi-stage build
- ✅ No verbose output in CI logs
- ✅ Configurable build options
- ✅ Optimized layer caching
- ✅ ARMv6 static binaries

Build system is now streamlined and production-ready! 🎉 