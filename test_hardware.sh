#!/bin/bash
# 🧪 Test script for hardware acceleration features

echo "🧪 ==============================================="
echo "🎬 Testing ZeroFFmpeg Hardware Acceleration 🚀"
echo "🧪 ==============================================="

FFMPEG_BIN="./ffmpeg"
if [ ! -f "$FFMPEG_BIN" ]; then
    FFMPEG_BIN="./output/ffmpeg"
fi

if [ ! -f "$FFMPEG_BIN" ]; then
    echo "❌ FFmpeg binary not found! Please build first."
    exit 1
fi

echo "🔍 Testing FFmpeg version and capabilities..."
$FFMPEG_BIN -version

echo ""
echo "📹 Testing V4L2 support..."
$FFMPEG_BIN -hide_banner -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -f v4l2 -list_formats all /dev/video0 2>/dev/null && echo "✅ V4L2 support detected" || echo "⚠️  V4L2 support not available (normal if no camera)"

echo ""
echo "🖥️ Testing DRM support..."
$FFMPEG_BIN -hide_banner -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -f null - 2>&1 | grep -q "drm" && echo "✅ DRM support detected" || echo "⚠️  DRM support not detected"

echo ""
echo "🚀 Testing H.264 V4L2M2M encoder..."
$FFMPEG_BIN -hide_banner -encoders 2>/dev/null | grep h264_v4l2m2m && echo "✅ H.264 V4L2M2M encoder available" || echo "⚠️  H.264 V4L2M2M encoder not available"

echo ""
echo "📊 Testing H.264 V4L2M2M decoder..."
$FFMPEG_BIN -hide_banner -decoders 2>/dev/null | grep h264_v4l2m2m && echo "✅ H.264 V4L2M2M decoder available" || echo "⚠️  H.264 V4L2M2M decoder not available"

echo ""
echo "🎯 Testing basic encoding with test pattern..."
echo "⏳ Creating 5-second test video..."
if $FFMPEG_BIN -hide_banner -f lavfi -i testsrc=duration=5:size=640x480:rate=30 -c:v libx264 -preset ultrafast -y test_software.mp4 >/dev/null 2>&1; then
    echo "✅ Software H.264 encoding successful"
    ls -lh test_software.mp4
    rm -f test_software.mp4
else
    echo "❌ Software H.264 encoding failed"
fi

echo ""
echo "🎬 Testing hardware encoding (if available)..."
if $FFMPEG_BIN -hide_banner -f lavfi -i testsrc=duration=5:size=640x480:rate=30 -c:v h264_v4l2m2m -y test_hardware.mp4 >/dev/null 2>&1; then
    echo "✅ Hardware H.264 encoding successful"
    ls -lh test_hardware.mp4
    rm -f test_hardware.mp4
else
    echo "⚠️  Hardware H.264 encoding not available (normal on non-Pi hardware)"
fi

echo ""
echo "🎉 ==============================================="
echo "🎊 Hardware Acceleration Test Complete! 🎊"
echo "🎉 ==============================================="
echo "💡 Note: Some features may not be available without"
echo "💡 actual Raspberry Pi hardware and camera."
echo "🎉 ===============================================" 