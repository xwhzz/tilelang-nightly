#!/bin/bash

# Optimized build script that replaces your current build.sh and build_118.sh
# This version eliminates host dependencies and provides better isolation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUDA_VERSIONS=("11.8" "12.1" "12.4")
PYTHON_VERSIONS=("3.8" "3.9" "3.10" "3.11" "3.12")

echo "🚀 Starting optimized TileLang build process..."

# Clean previous builds
rm -rf wheelhouse-* final-wheelhouse
mkdir -p final-wheelhouse

# Function to build for a specific CUDA version
build_cuda_version() {
    local cuda_version=$1
    local wheelhouse_dir="wheelhouse-${cuda_version//./}"
    
    echo "🔨 Building for CUDA $cuda_version..."
    
    # Use Docker BuildKit for better performance
    DOCKER_BUILDKIT=1 docker build \
        --build-arg CUDA_VERSION=$cuda_version \
        --build-arg MANYLINUX_IMAGE=quay.io/pypa/manylinux_2_28_x86_64 \
        -f Dockerfile.cuda-build \
        -t tilelang-builder:cuda$cuda_version \
        .
    
    # Run the build container
    docker run --rm \
        --platform linux/amd64 \
        -v "${SCRIPT_DIR}/tilelang:/workspace:ro" \
        -v "${SCRIPT_DIR}/$wheelhouse_dir:/workspace/wheelhouse" \
        -e CUDA_VERSION=$cuda_version \
        tilelang-builder:cuda$cuda_version
        
    echo "✅ Completed build for CUDA $cuda_version"
}

# Build for each CUDA version in parallel (if system supports it)
if command -v parallel > /dev/null; then
    echo "🔄 Building CUDA versions in parallel..."
    printf '%s\n' "${CUDA_VERSIONS[@]}" | parallel -j 3 build_cuda_version
else
    echo "🔄 Building CUDA versions sequentially..."
    for cuda_version in "${CUDA_VERSIONS[@]}"; do
        build_cuda_version "$cuda_version"
    done
fi

# Merge all wheels
echo "📦 Merging wheels from all CUDA versions..."
for wheelhouse in wheelhouse-*; do
    if [[ -d "$wheelhouse" ]]; then
        cp "$wheelhouse"/*.whl final-wheelhouse/ 2>/dev/null || true
    fi
done

# Display results
echo "🎉 Build complete! Final wheels:"
ls -la final-wheelhouse/

# Verify wheels
echo "🔍 Verifying wheel compatibility..."
for wheel in final-wheelhouse/*.whl; do
    if [[ -f "$wheel" ]]; then
        echo "Checking: $(basename "$wheel")"
        python -m wheel tags --remove "$wheel" 2>/dev/null || echo "  ⚠️  Could not verify tags"
    fi
done

echo "✨ Optimized build process completed successfully!"
