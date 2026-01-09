#!/bin/bash
# Windows Server 2025 Base Image Build Script
# Baker Street Labs Infrastructure
# 
# This script automates the Packer build process for Windows Server 2025 Standard base image

set -e

# Default values
ISO_PATH="../image_assets/en-us_windows_server_2025_updated_sep_2025_x64_dvd_6d1ad20d.iso"
VIRTIO_ISO_PATH="../image_assets/virtio-win.iso"
PRODUCT_KEY="3NPK2-7TDCT-7KP99-3VHFX-V26D3"
ADMIN_PASSWORD="BakerStreet2025!"
HEADLESS="false"
CLEAN="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --iso-path)
            ISO_PATH="$2"
            shift 2
            ;;
        --virtio-iso-path)
            VIRTIO_ISO_PATH="$2"
            shift 2
            ;;
        --product-key)
            PRODUCT_KEY="$2"
            shift 2
            ;;
        --admin-password)
            ADMIN_PASSWORD="$2"
            shift 2
            ;;
        --headless)
            HEADLESS="true"
            shift
            ;;
        --clean)
            CLEAN="true"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --iso-path PATH          Path to Windows Server 2025 ISO"
            echo "  --virtio-iso-path PATH    Path to VirtIO drivers ISO"
            echo "  --product-key KEY         Windows product key"
            echo "  --admin-password PASS    Administrator password"
            echo "  --headless                Run in headless mode"
            echo "  --clean                   Clean previous builds"
            echo "  -h, --help                Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "Windows Server 2025 Base Image Build Script"
echo "============================================="

# Check if Packer is installed
echo "Checking Packer installation..."
if ! command -v packer &> /dev/null; then
    echo "ERROR: Packer is not installed or not in PATH."
    echo "Please install Packer first: https://www.packer.io/downloads"
    exit 1
fi

PACKER_VERSION=$(packer version | head -n1)
echo "Packer found: $PACKER_VERSION"

# Check if QEMU is available
echo "Checking QEMU availability..."
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "WARNING: QEMU not found. Make sure QEMU is installed and in PATH."
else
    QEMU_VERSION=$(qemu-system-x86_64 --version | head -n1)
    echo "QEMU found: $QEMU_VERSION"
fi

# Validate ISO files
echo "Validating ISO files..."
if [[ ! -f "$ISO_PATH" ]]; then
    echo "ERROR: Windows Server 2025 ISO not found at: $ISO_PATH"
    exit 1
fi
echo "Windows Server 2025 ISO found: $ISO_PATH"

if [[ ! -f "$VIRTIO_ISO_PATH" ]]; then
    echo "WARNING: VirtIO ISO not found at: $VIRTIO_ISO_PATH"
    echo "Please download VirtIO drivers ISO from: https://fedoraproject.org/wiki/Windows_Virtio_Drivers"
    echo "Or set --virtio-iso-path parameter to correct path"
fi

# Clean previous builds if requested
if [[ "$CLEAN" == "true" ]]; then
    echo "Cleaning previous builds..."
    if [[ -d "output" ]]; then
        rm -rf output
        echo "Previous builds cleaned"
    fi
fi

# Create output directory
if [[ ! -d "output" ]]; then
    mkdir -p output
    echo "Output directory created"
fi

# Set environment variables for Packer
export PKR_VAR_win_iso_path="$ISO_PATH"
export PKR_VAR_virtio_win_iso_path="$VIRTIO_ISO_PATH"
export PKR_VAR_product_key="$PRODUCT_KEY"
export PKR_VAR_admin_password="$ADMIN_PASSWORD"
export PKR_VAR_headless="$HEADLESS"

echo "Build configuration:"
echo "  ISO Path: $ISO_PATH"
echo "  VirtIO ISO: $VIRTIO_ISO_PATH"
echo "  Product Key: ${PRODUCT_KEY:0:5}****"
echo "  Headless: $HEADLESS"

# Start Packer build
echo "Starting Packer build..."
echo "This process may take 30-60 minutes depending on your system..."

BUILD_START_TIME=$(date +%s)

if [[ "$HEADLESS" == "true" ]]; then
    packer build -var "headless=true" windows-server-2025-standard.pkr.hcl
else
    packer build windows-server-2025-standard.pkr.hcl
fi

BUILD_END_TIME=$(date +%s)
BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))

echo "Build completed successfully!"
echo "Build duration: $((BUILD_DURATION / 60)) minutes $((BUILD_DURATION % 60)) seconds"

# Display output information
echo "Output files:"
find output -type f -exec ls -lh {} \; | while read -r line; do
    echo "  $line"
done

echo "Windows Server 2025 base image build completed!"
echo "Output location: output/windows-server-2025-standard/"
