# 🎬 ZeroFFmpeg - Makefile for Ultra-Fast Docker Builds 🚀

.PHONY: help build build-deps build-ffmpeg extract clean cache-info

# Default target
help: ## 📋 Show this help message
	@echo "🎬 ZeroFFmpeg - Ultra-Fast Docker Build System 🚀"
	@echo ""
	@echo "🎯 Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## 🏗️  Full build (all stages)
	@echo "🏗️  Building ZeroFFmpeg with all dependencies..."
	docker build --target output -t zeroffmpeg:latest .
	@echo "✅ Build complete! Use 'make extract' to get binaries."

build-deps: ## 📦 Build only dependencies (for caching)
	@echo "📦 Building dependencies layer for caching..."
	docker build --target deps-builder -t zeroffmpeg-deps:latest .
	@echo "✅ Dependencies cached! Next builds will be much faster."

build-ffmpeg: ## ⚡ Fast FFmpeg-only build (assumes deps cached)
	@echo "⚡ Fast FFmpeg build using cached dependencies..."
	docker build --target ffmpeg-builder -t zeroffmpeg-builder:latest .
	docker build --target output -t zeroffmpeg:latest .
	@echo "✅ FFmpeg build complete!"

extract: ## 📤 Extract binaries from Docker image
	@echo "📤 Extracting binaries..."
	@mkdir -p ./output
	docker create --name temp-zeroffmpeg zeroffmpeg:latest
	docker cp temp-zeroffmpeg:/ffmpeg ./output/
	docker cp temp-zeroffmpeg:/ffprobe ./output/ 2>/dev/null || echo "⚠️  ffprobe not found"
	docker rm temp-zeroffmpeg
	@echo "✅ Binaries extracted to ./output/"
	@echo "📊 Binary sizes:"
	@ls -lh ./output/

test: ## 🧪 Test the built FFmpeg
	@echo "🧪 Testing FFmpeg binary..."
	docker run --rm zeroffmpeg:latest ./ffmpeg -version
	@echo "✅ FFmpeg is working!"

clean: ## 🧹 Clean up Docker images and containers
	@echo "🧹 Cleaning up..."
	docker rmi zeroffmpeg:latest zeroffmpeg-deps:latest zeroffmpeg-builder:latest 2>/dev/null || true
	docker system prune -f
	rm -rf ./output
	@echo "✅ Cleanup complete!"

cache-info: ## 📊 Show Docker cache information
	@echo "📊 Docker build cache information:"
	@echo ""
	@echo "🎯 Available cached images:"
	@docker images | grep -E "(zeroffmpeg|dockcross)" || echo "❌ No cached images found"
	@echo ""
	@echo "💾 Docker build cache usage:"
	@docker system df

# 🚀 Quick development workflow
dev-build: build-deps build-ffmpeg extract ## 🔧 Development build (deps -> ffmpeg -> extract)

# 🏃‍♂️ Speed test comparison
speed-test: ## ⏱️  Compare build speeds
	@echo "⏱️  Testing build speed with cache..."
	@echo "🔄 First build (building cache):"
	@time make build-deps > /dev/null 2>&1
	@echo "🔄 Second build (using cache):"
	@time make build-ffmpeg > /dev/null 2>&1
	@echo "✅ Speed test complete!"

# 📋 Build info
info: ## ℹ️  Show build information
	@echo "ℹ️  ZeroFFmpeg Build Information:"
	@echo "🎯 Target: ARMv6 (Raspberry Pi Zero)"
	@echo "🔧 Base image: dockcross/linux-armv6"
	@echo "📦 Dependencies: zlib, OpenSSL, x264"
	@echo "🎬 FFmpeg version: Latest (git)"
	@echo "🔒 Security: HTTPS support"
	@echo "⚡ Expected startup: ~0.01 seconds"
	@echo "📊 Expected size: ~8MB (static)"

# 💡 Pro tips
tips: ## 💡 Show optimization tips
	@echo "💡 ZeroFFmpeg Build Optimization Tips:"
	@echo ""
	@echo "🚀 For fastest rebuilds:"
	@echo "   1. Run 'make build-deps' once to cache dependencies"
	@echo "   2. Use 'make build-ffmpeg' for quick FFmpeg-only rebuilds"
	@echo "   3. Keep the deps image: 'docker tag zeroffmpeg-deps:latest zeroffmpeg-deps:cache'"
	@echo ""
	@echo "🔧 For development:"
	@echo "   1. Use 'make dev-build' for full dev cycle"
	@echo "   2. Edit build_ffmpeg.sh and run 'make build-ffmpeg'"
	@echo "   3. Test with 'make test'"
	@echo ""
	@echo "🧹 For cleanup:"
	@echo "   1. 'make clean' - remove all images"
	@echo "   2. 'docker system prune -a' - deep clean" 