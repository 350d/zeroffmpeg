# 🎬 ZeroFFmpeg - Optimized FFmpeg for Raspberry Pi Zero

[![Build Status](https://github.com/your-username/zeroffmpeg/actions/workflows/build.yml/badge.svg)](https://github.com/your-username/zeroffmpeg/actions)

Ultra-optimized FFmpeg build for Raspberry Pi Zero (ARMv6) with hardware acceleration support. Features clean Docker-based build system with configurable options.

## 🚀 Features

- **ARMv6 Optimized**: Specifically compiled for Raspberry Pi Zero architecture
- **Hardware Acceleration**: V4L2 M2M support for hardware-accelerated H.264 encoding/decoding
- **Static Binary**: No external dependencies required
- **Multi-Configuration**: Choose between minimal, normal, or full builds
- **Fast Docker Build**: Multi-stage Docker build with optimal caching
- **GitHub Actions**: Automated builds with configurable options

## 📦 Available Configurations

### 🔧 Minimal (~ 3-8 MB)
- Basic video operations
- H.264 and MJPEG support
- V4L2 camera input/output
- Essential filters (scale, format)
- Protocols: file, pipe

### ⚙️ Normal (~ 15-25 MB) - **Default**
- Comprehensive multimedia support
- H.264 hardware acceleration (V4L2 M2M)
- Streaming protocols (RTSP, HTTP/HTTPS, RTP)
- Audio codecs (AAC, MP3, Opus, Vorbis)
- Advanced filters and processing
- OpenSSL and x264 support

### 🔥 Full (~ 35-50 MB)
- Complete FFmpeg capabilities
- All codecs, filters, and protocols
- Maximum compatibility
- Post-processing and resampling
- All input/output devices

## 🛠️ Building

### Using Docker (Recommended)

```bash
# Build with default (normal) configuration
docker build --build-arg OPTION=normal -t zeroffmpeg .

# Build minimal version
docker build --build-arg OPTION=minimal -t zeroffmpeg-minimal .

# Build full version
docker build --build-arg OPTION=full -t zeroffmpeg-full .

# Extract binaries
docker build --build-arg OPTION=normal --target output --output type=local,dest=./output .
```

### Using GitHub Actions

1. Go to **Actions** tab in your repository
2. Select **"Build FFmpeg"** workflow
3. Click **"Run workflow"**
4. Choose configuration: `minimal`, `normal`, or `full`
5. Download artifacts from completed build

## 📋 Usage Examples

### Camera Streaming
```bash
# Stream from Pi Camera to RTSP
./ffmpeg -f v4l2 -i /dev/video0 -c:v h264_v4l2m2m -f rtsp rtsp://localhost:8554/stream

# Capture MJPEG snapshots
./ffmpeg -f v4l2 -i /dev/video0 -vframes 1 -f image2 snapshot.jpg
```

### Hardware Acceleration
```bash
# Hardware-accelerated H.264 encoding
./ffmpeg -i input.mp4 -c:v h264_v4l2m2m -preset slow output.mp4

# Hardware-accelerated streaming
./ffmpeg -f v4l2 -i /dev/video0 -c:v h264_v4l2m2m -f rtp rtp://192.168.1.100:5004
```

## 🏗️ Architecture

```
┌─────────────────────┐
│   GitHub Actions   │ ← UI for selecting build options
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│ ffmpeg-configs.sh   │ ← Configuration definitions
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│    Dockerfile      │ ← Multi-stage Docker build
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  Static Binaries   │ ← ARMv6 optimized output
└─────────────────────┘
```

## 🔧 Configuration Details

All configurations are defined in `ffmpeg-configs.sh`:

- **Base Configuration**: Common ARM cross-compilation settings
- **Minimal**: Essential video processing only
- **Normal**: Balanced feature set for most applications  
- **Full**: Complete FFmpeg functionality

## 🎯 Performance Optimization

- **ARMv6 Specific**: Optimized for Pi Zero's CPU architecture
- **Hardware Acceleration**: V4L2 M2M for GPU-accelerated encoding
- **Static Linking**: No runtime dependencies
- **Size Optimization**: `-Os` compiler flags
- **Multi-Stage Build**: Efficient Docker layer caching

## 📊 Size Comparison

| Configuration | FFmpeg Size | Features |
|---------------|-------------|----------|
| Minimal       | ~3-8 MB     | Basic video operations |
| Normal        | ~15-25 MB   | Full multimedia support |
| Full          | ~35-50 MB   | Complete FFmpeg |

## 🐛 Troubleshooting

### Common Issues

1. **No hardware acceleration**: Ensure V4L2 M2M drivers are loaded
2. **Permission denied**: Check camera device permissions (`/dev/video*`)
3. **Out of memory**: Use minimal configuration for very limited systems

### Debug Mode
```bash
# Check available encoders
./ffmpeg -encoders | grep h264

# List V4L2 devices
./ffmpeg -f v4l2 -list_devices true -i dummy

# Verbose output
./ffmpeg -loglevel debug -i input.mp4 output.mp4
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 🙏 Acknowledgments

- FFmpeg project for the amazing multimedia framework
- Dockcross project for ARM cross-compilation toolchain
- Raspberry Pi Foundation for the Pi Zero platform
