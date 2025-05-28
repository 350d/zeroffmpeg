# 🐳 Docker Workflow Guide - ZeroFFmpeg

This guide explains how to use the optimized Docker-based build system for maximum speed and reliability.

## 🚀 Quick Start

### 1️⃣ First Time Setup (One-time, slow)
```bash
# Cache dependencies (20-30 minutes first time)
make build-deps
```

### 2️⃣ Fast Development Cycle 
```bash
# Edit build_ffmpeg.sh or Dockerfile
# Then rebuild FFmpeg only (2-5 minutes)
make build-ffmpeg

# Extract binaries
make extract

# Test the result
make test
```

### 3️⃣ Full Build from Scratch
```bash
# Complete build (if you want to start fresh)
make build
make extract
```

## 🏗️ Available Make Targets

| Command | Description | Time | Use Case |
|---------|-------------|------|----------|
| `make help` | 📋 Show all available commands | Instant | Learning |
| `make build-deps` | 📦 Cache dependencies (zlib, OpenSSL, libsrtp2, libv4l2, libdrm, x264) | 25-35 min | First setup |
| `make build-ffmpeg` | ⚡ Fast FFmpeg build using cache | 2-5 min | Development |
| `make build` | 🏗️ Full build (all stages) | 30-40 min | Clean rebuild |
| `make extract` | 📤 Get binaries from Docker | 10 sec | Get results |
| `make test` | 🧪 Test built FFmpeg | 5 sec | Verification |
| `make clean` | 🧹 Clean up images | 30 sec | Cleanup |
| `make dev-build` | 🔧 deps→ffmpeg→extract | 2-5 min | Development |
| `make cache-info` | 📊 Show cache status | Instant | Debug |
| `make tips` | 💡 Optimization tips | Instant | Learning |

## 🎯 Development Workflows

### 🔧 **Tweaking FFmpeg Configuration**
```bash
# 1. Edit build_ffmpeg.sh (change --enable/--disable flags)
# 2. Quick rebuild
make build-ffmpeg
make extract
# 3. Test
./output/ffmpeg -version
```

### 📦 **Adding New Dependencies**
```bash
# 1. Edit Dockerfile (add to deps-builder stage)
# 2. Rebuild deps cache
make clean
make build-deps
# 3. Fast FFmpeg build
make build-ffmpeg
make extract
```

### 🐛 **Debugging Build Issues**
```bash
# Show what's cached
make cache-info

# Check specific stage
docker build --target deps-builder -t debug-deps .
docker run -it debug-deps bash

# Full verbose build
docker build --no-cache --progress=plain .
```

## 🚀 GitHub Actions Integration

The GitHub Actions workflow now uses the same optimized Docker build:

```yaml
# .github/workflows/build.yaml automatically:
# 1. Builds using optimized Dockerfile
# 2. Extracts binaries 
# 3. Uploads as artifacts
```

### Manual GitHub Actions Trigger
1. Go to **Actions** tab in GitHub
2. Select **"🎬 Build FFmpeg for Raspberry Pi Zero 🥧"**
3. Click **"Run workflow"**
4. Download artifacts when complete

## ⚡ Speed Comparison

| Scenario | Old Approach | New Docker | Improvement |
|----------|--------------|------------|-------------|
| **First build** | 30-40 min | 25-35 min | **15% faster** |
| **Rebuild after script change** | 30-40 min | 2-5 min | **90% faster** |
| **Rebuild after deps change** | 30-40 min | 10-15 min | **60% faster** |

## 🎯 Best Practices

### 🚀 **For Maximum Speed**
1. Always run `make build-deps` first
2. Keep the deps cache: `docker tag zeroffmpeg-deps:latest zeroffmpeg-deps:backup`  
3. Use `make build-ffmpeg` for iterations
4. Only use `make build` when starting fresh

### 🔧 **For Development**
1. Use `make dev-build` for complete cycle
2. Edit configurations in small increments
3. Test frequently with `make test`
4. Use `docker run -it zeroffmpeg-deps bash` to debug

### 💾 **For CI/CD**
1. Cache the `deps-builder` stage in CI
2. Use multi-stage builds for different targets
3. Tag final images with version numbers
4. Extract binaries as artifacts

## 🐛 Troubleshooting

### ❌ "No space left on device"
```bash
# Clean up Docker
make clean
docker system prune -a
```

### ❌ "Build fails on dependencies"
```bash
# Force rebuild deps without cache
docker build --no-cache --target deps-builder -t zeroffmpeg-deps .
make build-ffmpeg
```

### ❌ "Binary not found after build"
```bash
# Check if build completed
docker images | grep zeroffmpeg
# Manual extraction
docker create --name manual-extract zeroffmpeg:latest
docker cp manual-extract:/ ./debug-output/
docker rm manual-extract
```

### ❌ "Out of memory during build"
```bash
# Reduce parallel jobs
docker build --build-arg JOBS=2 .
# Or edit Dockerfile: make -j2 instead of make -j$(nproc)
```

## 📊 Docker Layer Caching Strategy

The Dockerfile uses smart layering for maximum cache efficiency:

```
Layer 1: Base deps     (Changes: Never)     Cache: Forever
Layer 2: System pkgs   (Changes: Rarely)    Cache: Months  
Layer 3: zlib build    (Changes: Rarely)    Cache: Months
Layer 4: OpenSSL build (Changes: Rarely)    Cache: Months
Layer 5: x264 build    (Changes: Rarely)    Cache: Months
Layer 6: libsrtp2 build(Changes: Rarely)    Cache: Months
Layer 7: libv4l2 build (Changes: Rarely)    Cache: Months
Layer 8: libdrm build  (Changes: Rarely)    Cache: Months
Layer 9: FFmpeg clone  (Changes: Sometimes) Cache: Weeks
Layer 10: FFmpeg build (Changes: Often)     Cache: None
```

**Result**: 90% of the build is cached most of the time! 🎉

## 💡 Pro Tips

- Keep multiple dependency caches: `docker tag zeroffmpeg-deps:latest zeroffmpeg-deps:$(date +%Y%m%d)`
- Use `.dockerignore` to minimize build context
- Monitor cache usage: `docker system df`
- For ultimate speed: Use local registry to cache layers
- Test on Pi Zero: `scp output/ffmpeg pi@your-pi:~/` 

---

**🎯 Remember**: The first build is slow, but every subsequent build is lightning fast! ⚡ 