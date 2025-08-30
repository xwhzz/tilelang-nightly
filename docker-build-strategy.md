# Optimized Docker Build Strategy for TileLang

## Current Issues with Your Setup

### 1. GCC-11 + manylinux_2_28 Incompatibility
- **manylinux_2_28** uses AlmaLinux 8 with GCC 13
- **GCC-11** targets older glibc versions (2.17-2.27)
- **Result**: ABI mismatches, symbol versioning conflicts, runtime errors

### 2. Tox + Docker Host Dependencies
- Tox inherits host system configurations
- Docker volume mounts can leak host environment variables
- Inconsistent builds across different CI runners

## Recommended Solutions

### Option 1: Use manylinux_2_17 with GCC-11 (Recommended)
```dockerfile
# Use CentOS 7 based image that supports GCC-11
FROM quay.io/pypa/manylinux_2_17_x86_64

# Install GCC-11 via devtoolset
RUN yum install -y centos-release-scl && \
    yum install -y devtoolset-11-gcc devtoolset-11-gcc-c++

# Activate GCC-11 environment
ENV CC=/opt/rh/devtoolset-11/root/usr/bin/gcc
ENV CXX=/opt/rh/devtoolset-11/root/usr/bin/g++
```

### Option 2: Upgrade to GCC-13 with manylinux_2_28
```dockerfile
FROM quay.io/pypa/manylinux_2_28_x86_64
# Use built-in GCC-13 (supports C++17 and newer standards)
```

### Option 3: Custom Multi-Stage Build
```dockerfile
# Build stage with specific GCC version
FROM nvidia/cuda:12.1-devel-ubuntu20.04 as builder
RUN apt-get update && apt-get install -y gcc-11 g++-11
ENV CC=gcc-11 CXX=g++-11

# Package stage with manylinux compatibility
FROM quay.io/pypa/manylinux_2_17_x86_64 as packager
COPY --from=builder /path/to/built/extensions /workspace/
```

## Optimized Build Architecture

### 1. Replace Tox with Direct Python Management
Instead of tox, use conda/pyenv for cleaner Python version management:

```bash
# Install multiple Python versions
for py_ver in 3.8 3.9 3.10 3.11 3.12; do
    /opt/python/cp${py_ver//./}-cp${py_ver//./}/bin/pip install -r requirements-build.txt
    /opt/python/cp${py_ver//./}-cp${py_ver//./}/bin/python setup.py bdist_wheel
done
```

### 2. CUDA Version Matrix Optimization
Use pre-built CUDA base images instead of installing CUDA in each build:

```yaml
strategy:
  matrix:
    include:
      - cuda-version: "11.8"
        cuda-image: "nvidia/cuda:11.8-devel-ubuntu20.04"
        manylinux-image: "quay.io/pypa/manylinux_2_17_x86_64"
      - cuda-version: "12.1" 
        cuda-image: "nvidia/cuda:12.1-devel-ubuntu20.04"
        manylinux-image: "quay.io/pypa/manylinux_2_17_x86_64"
```

### 3. Eliminate Host System Dependencies
- Use `--platform linux/amd64` to ensure consistent architecture
- Set explicit environment variables in Docker
- Use Docker BuildKit for better caching
- Mount only necessary directories, not entire workspace

## Performance Optimizations

### 1. Docker Layer Caching
```dockerfile
# Cache dependencies separately from source code
COPY requirements*.txt /tmp/
RUN pip install -r /tmp/requirements-build.txt

# Copy source code last to maximize cache hits
COPY . /workspace/
WORKDIR /workspace
```

### 2. Parallel Builds
- Build different CUDA versions in parallel jobs
- Use GitHub Actions matrix to parallelize Python versions
- Cache Docker layers between builds

### 3. Artifact Management
- Use separate artifacts per CUDA version
- Merge artifacts in final stage
- Clean up intermediate files to reduce storage costs
