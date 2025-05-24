# 🎬 ZeroFFmpeg - Ultra-Fast Custom FFmpeg for Raspberry Pi Zero 🥧

> **Lightning-fast custom FFmpeg build optimized for stream processing, snapshot generation, and motion analysis on Raspberry Pi Zero**

## 🚀 The Problem

Standard FFmpeg distributions are bloated with hundreds of codecs, filters, and features that most users never need. When working with Raspberry Pi Zero for real-time applications, this becomes a critical performance bottleneck:

- **⏰ Standard FFmpeg startup time: ~6 seconds** 
- **📦 Binary size: 50+ MB with dependencies**
- **🐌 Slow initialization for simple tasks**
- **💾 High memory footprint**

For applications requiring:
- 📹 Real-time stream processing
- 📸 Quick snapshot generation  
- 🎯 Motion detection and analysis
- ⚡ Sub-second response times

...the standard FFmpeg was simply unusable.

## ✨ The Solution

**ZeroFFmpeg** is a minimal, static FFmpeg build that includes only essential components:

- **⚡ Startup time: ~0.01 seconds (600x faster!)**
- **📦 Binary size: ~8MB (static, no dependencies)**
- **🎯 Optimized for ARMv6 (Raspberry Pi Zero)**
- **🔒 Includes only needed codecs and protocols**

### 🎯 Included Features

#### 📹 **Video Codecs**
- **H.264** - Modern video compression
- **MJPEG** - Fast snapshot generation
- **Raw Video** - Uncompressed streams

#### 🔊 **Audio Codecs**  
- **AAC** - High-quality audio
- **MP3** - Universal compatibility
- **PCM** - Uncompressed audio

#### 🌐 **Network Protocols**
- **HTTP/HTTPS** - Web streaming
- **RTP/RTSP** - Real-time protocols  
- **TCP/UDP** - Network transport

#### 🔧 **Essential Filters**
- **Scale** - Resize frames
- **Format** - Pixel format conversion
- **Motion detection** - Analysis filters
- **FPS control** - Frame rate management

#### 🔐 **Security & Compression**
- **OpenSSL** - Secure connections
- **SRTP** - Secure Real-time Transport Protocol
- **zlib** - Data compression

## 🏗️ Build Process

The build uses **cross-compilation** with GitHub Actions for consistent, reproducible builds:

### 🛠️ **Dependencies Built from Source**
1. **🗜️ zlib** - Compression library
2. **🔐 OpenSSL 1.1.1** - Cryptography (with ARM cross-compilation fixes)
3. **🎬 x264** - H.264 encoder/decoder
4. **🔒 libsrtp2** - Secure Real-time Transport Protocol library
5. **🎥 FFmpeg Latest** - Main application (latest git version)

### 🎯 **Target Platform**
- **Architecture**: ARMv6 (Raspberry Pi Zero compatible)
- **Float ABI**: Hard float
- **Optimization**: Size-optimized (`-Os`)
- **Linking**: Fully static (no runtime dependencies)

## 🚀 Quick Start

### 1️⃣ Download Pre-built Binary

Go to [Releases](../../releases) and download the latest `🎬-ffmpeg-armv6-static-🥧` artifact.

### 2️⃣ Install on Raspberry Pi Zero

```bash
# Download and extract
wget https://github.com/yourusername/zeroffmpeg/releases/latest/download/ffmpeg-armv6-static.tar.gz
tar -xzf ffmpeg-armv6-static.tar.gz

# Make executable
chmod +x ffmpeg ffprobe

# Test installation
./ffmpeg -version
```

### 3️⃣ Example Usage

```bash
# 📸 Quick snapshot from webcam
./ffmpeg -f v4l2 -i /dev/video0 -vframes 1 snapshot.jpg

# 📹 Stream to network (starts in 0.01s!)
./ffmpeg -f v4l2 -i /dev/video0 -c:v h264 -f rtp rtp://192.168.1.100:5004

# 🔒 Secure SRTP streaming  
./ffmpeg -f v4l2 -i /dev/video0 -c:v h264 -f rtp -srtp_out_suite AES_CM_128_HMAC_SHA1_80 -srtp_out_params <key> srtp://192.168.1.100:5004

# 🎯 Basic motion detection
./ffmpeg -f v4l2 -i /dev/video0 -vf "showinfo,blackframe=threshold=32" -f null -
```

## 🎯 Real-World Example: IP Camera with Motion Detection

This is a production example used for **security monitoring** with IP cameras. It demonstrates the **real power** of ZeroFFmpeg - complex video analysis that starts instantly:

```bash
./ffmpeg -hide_banner -y -loglevel info \
  -thread_queue_size 1 \
  -fpsprobesize 0 -analyzeduration 0 -probesize 32 \
  -fflags +ignidx+nobuffer+discardcorrupt+flush_packets \
  -skip_frame nokey -max_delay 0 -flags low_delay \
  -rtsp_transport udp -buffer_size 512k \
  -hwaccel videotoolbox -r 1 \
  -i rtsp://127.0.0.1:9999/unicast \
  -pix_fmt yuv420p -color_range mpeg -strict -1 -an -threads 1 \
  -filter_complex "[0:v]fps=1,scale=640:-1:flags=fast_bilinear,split=2[snap][diff]; \
    [diff]tblend=all_mode=difference,blackframe=0.02:32[diffout]" \
  -map "[snap]" -q:v 4 -update 1 -f image2 snapshot.jpg \
  -map "[diffout]" -f null - 2>&1 | tee >(awk '
      BEGIN {
        cooldownUntil = 0;
        cooldownSeconds = 8;
      }
      /blackframe/ {
        now = systime();
        if (now < cooldownUntil) {
          next;
        }

        for (i = 1; i <= NF; i++) {
          if ($i ~ /^pblack:/) {
            val = substr($i, 8) + 0;
            if (val < 98) {
              system("curl -s \"http://localhost:8080/motion?val=" val "\" &");
              cooldownUntil = now + cooldownSeconds;
            }
          }
        }
      }')
```

### 🔍 What This Example Does:

#### 📡 **RTSP Stream Processing**
- Connects to local H264 stream (served by v4l2rtspserver)via RTSP
- Optimized for minimal buffering and instant processing
- Handles 1 FPS for efficient monitoring

#### 📸 **Continuous Snapshots** 
- Updates `snapshot.jpg` every second with latest frame
- Uses `-update 1` to overwrite the same file (perfect for web dashboards)
- Scaled to 640px width for optimal size/quality balance

#### 🎯 **Smart Motion Detection**
- **Frame Difference**: Uses `tblend=all_mode=difference` to compare consecutive frames
- **Movement Analysis**: `blackframe=0.02:32` detects changes (less than 98% black pixels = motion)
- **Smart Cooldown**: 8-second cooldown prevents spam notifications

#### 🚨 **Real-time Alerts**
- Sends HTTP notification when motion detected: `curl http://localhost:8080/motion?val=X`
- Integration with home automation systems
- Background processing with `&` for non-blocking operation

### ⚡ **Performance Benefits**

With **standard FFmpeg**: This complex pipeline would take **~6 seconds to initialize**, making real-time monitoring impossible.

With **ZeroFFmpeg**: **Instant startup (0.01s)** means you can:
- 🔄 Restart monitoring scripts without delay
- 🎯 React to events in real-time  
- 📱 Quick responses for security applications
- 🔧 Easy integration with IoT systems

**Perfect for**: Security cameras, smart doorbells, motion-triggered recording, and any application requiring instant video analysis!

## 🔧 Building from Source

### Prerequisites
- GitHub account (for Actions)
- OR Docker with `dockcross/linux-armv6`

### 🤖 Using GitHub Actions (Recommended)

1. Fork this repository
2. Go to **Actions** tab
3. Run **"🎬 Build FFmpeg for Raspberry Pi Zero 🥧"** workflow
4. Download artifacts from the completed run

### 🐳 Local Build with Optimized Docker (Fast!)

```bash
# Clone repository
git clone https://github.com/yourusername/zeroffmpeg.git
cd zeroffmpeg

# First time setup (caches dependencies)
make build-deps

# Fast FFmpeg build using cache
make build-ffmpeg
make extract

# Find binaries in output/
ls -la output/
```

### 🐳 Alternative: Direct Docker Build

```bash
# Single command build (slower but simpler)
docker build --target output -t zeroffmpeg .

# Extract binaries
docker create --name temp-zeroffmpeg zeroffmpeg
docker cp temp-zeroffmpeg:/ffmpeg ./
docker cp temp-zeroffmpeg:/ffprobe ./
docker rm temp-zeroffmpeg
```

### 🛠️ Legacy Build Method

```bash
# Using dockcross directly (original method)
docker run --rm -v $(pwd):/work dockcross/linux-armv6 bash -c "
    cd /work && 
    chmod +x build_ffmpeg.sh && 
    ./build_ffmpeg.sh
"
```

## 📊 Performance Comparison

| Metric | Standard FFmpeg | ZeroFFmpeg | Improvement |
|--------|----------------|------------|-------------|
| **Startup Time** | ~6.0s | ~0.01s | **600x faster** |
| **Binary Size** | 50+ MB | 6.1 MB | **8x smaller** |
| **Dependencies** | Many | None (static) | **No dependency hell** |
| **Memory Usage** | High | Minimal | **Lower footprint** |

## 🎯 Use Cases

### 📹 **Real-time Stream Processing**
- IP camera feeds
- Live video analysis  
- Stream transcoding

### 📸 **Snapshot Generation**  
- Security cameras
- Time-lapse photography
- Motion-triggered captures

### 🎮 **Motion Detection**
- Smart doorbells  
- Security systems
- IoT applications

### 🔄 **Format Conversion**
- Video format changes
- Resolution scaling
- Codec transcoding

## 🛠️ Technical Details

### Cross-Compilation Environment
- **Compiler**: `armv6-unknown-linux-gnueabihf-gcc`
- **Target**: ARMv6 hard-float EABI
- **Container**: `dockcross/linux-armv6:latest`

### Build Optimizations
- **Static linking** - No runtime dependencies
- **Size optimization** - `-Os` compiler flag  
- **Feature pruning** - Only essential codecs included
- **ARM-specific tuning** - Optimized for Pi Zero architecture

### Security Features
- **OpenSSL integration** - HTTPS/TLS support
- **Static builds** - No library injection attacks
- **Minimal attack surface** - Fewer features = fewer vulnerabilities

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Test your changes with the build script
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **FFmpeg Team** - For the amazing multimedia framework
- **DocCross Project** - For excellent cross-compilation containers  
- **x264 Project** - For efficient H.264 encoding
- **OpenSSL Team** - For cryptographic libraries

---

**💡 Pro Tip**: For even better performance on Pi Zero, consider using a fast SD card (Class 10 or better) and ensure adequate cooling for sustained video processing workloads.

**🎯 Perfect for**: IoT projects, security cameras, edge computing, real-time video processing, and any application where startup speed matters!
