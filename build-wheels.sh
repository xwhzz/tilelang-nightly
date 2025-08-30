#!/bin/bash
set -e

# Clean, efficient wheel building script that replaces tox
# This script eliminates host system dependencies

echo "Starting wheel build process..."
echo "CUDA Version: $(nvcc --version | grep release)"
echo "GCC Version: $(gcc --version | head -1)"
echo "manylinux_2_28 with native GCC-13 - excellent C++17 support!"

# Verify C++17 support
echo "int main(){return 0;}" | g++ -std=c++17 -x c++ - -o /tmp/test && echo "✓ C++17 support confirmed"

# Build wheels for all Python versions
for py_path in /opt/python/cp3{8,9,10,11,12}-cp3{8,9,10,11,12}; do
    if [[ -d "$py_path" ]]; then
        py_version=$(basename $py_path | cut -d'-' -f1)
        echo "Building for Python $py_version..."
        
        # Install build requirements
        $py_path/bin/pip install -r requirements-build.txt || {
            echo "Warning: Could not install requirements-build.txt for $py_version"
            $py_path/bin/pip install setuptools wheel Cython numpy
        }
        
        # Build the wheel
        $py_path/bin/python setup.py bdist_wheel
        
        echo "✓ Built wheel for Python $py_version"
    fi
done

# Create wheelhouse directory and repair wheels
mkdir -p wheelhouse

# Repair wheels for manylinux compatibility
for wheel in dist/*.whl; do
    if [[ -f "$wheel" ]]; then
        echo "Repairing wheel: $(basename $wheel)"
        auditwheel repair "$wheel" \
            --wheel-dir wheelhouse \
            --exclude libcuda.so.1 \
            --exclude libnvrtc.so.11 \
            --exclude libcudart.so.11 \
            --exclude libnvrtc.so.12 \
            --exclude libcudart.so.12 \
            --plat manylinux_2_28_x86_64 || {
            echo "Warning: Could not repair $wheel, copying as-is"
            cp "$wheel" wheelhouse/
        }
    fi
done

echo "Build complete! Wheels available in wheelhouse/"
ls -la wheelhouse/
