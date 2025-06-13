#!/bin/bash

# AppMCP Build Script
# Builds release version and installs to system PATH

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PRODUCT_NAME="appmcpd"
INSTALL_PATH="/usr/local/bin"
BUILD_CONFIG="release"

echo -e "${BLUE}🔨 Building AppMCP...${NC}"

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
swift package clean

# Build release version
echo -e "${YELLOW}Building release version...${NC}"
swift build -c release

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build completed successfully${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

# Find the built executable
BUILT_EXECUTABLE=".build/release/${PRODUCT_NAME}"

if [ ! -f "$BUILT_EXECUTABLE" ]; then
    echo -e "${RED}❌ Built executable not found at ${BUILT_EXECUTABLE}${NC}"
    exit 1
fi

# Check if we have permission to install
if [ ! -w "$INSTALL_PATH" ]; then
    echo -e "${YELLOW}⚠️  Need sudo permission to install to ${INSTALL_PATH}${NC}"
    NEED_SUDO=true
else
    NEED_SUDO=false
fi

# Copy to install path
echo -e "${YELLOW}Installing ${PRODUCT_NAME} to ${INSTALL_PATH}...${NC}"

if [ "$NEED_SUDO" = true ]; then
    sudo cp "$BUILT_EXECUTABLE" "$INSTALL_PATH/"
    sudo chmod +x "${INSTALL_PATH}/${PRODUCT_NAME}"
else
    cp "$BUILT_EXECUTABLE" "$INSTALL_PATH/"
    chmod +x "${INSTALL_PATH}/${PRODUCT_NAME}"
fi

# Verify installation
if [ -f "${INSTALL_PATH}/${PRODUCT_NAME}" ]; then
    echo -e "${GREEN}✅ Successfully installed ${PRODUCT_NAME} to ${INSTALL_PATH}${NC}"
    
    # Show version info
    echo -e "${BLUE}📋 Installation details:${NC}"
    echo -e "  Executable: ${INSTALL_PATH}/${PRODUCT_NAME}"
    echo -e "  Size: $(du -h "${INSTALL_PATH}/${PRODUCT_NAME}" | cut -f1)"
    echo -e "  Permissions: $(ls -l "${INSTALL_PATH}/${PRODUCT_NAME}" | cut -d' ' -f1)"
    
    # Verify it's in PATH
    if command -v "$PRODUCT_NAME" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ ${PRODUCT_NAME} is now available in PATH${NC}"
        echo -e "${BLUE}💡 You can now run: ${PRODUCT_NAME} --help${NC}"
    else
        echo -e "${YELLOW}⚠️  ${PRODUCT_NAME} may not be in your PATH. You might need to restart your terminal or run:${NC}"
        echo -e "  export PATH=\"${INSTALL_PATH}:\$PATH\""
    fi
else
    echo -e "${RED}❌ Installation failed${NC}"
    exit 1
fi

# Optional: Create symbolic link for easier access (if needed)
# if [ ! -L "/usr/local/bin/appmcp" ]; then
#     echo -e "${YELLOW}Creating symbolic link appmcp -> appmcpd...${NC}"
#     if [ "$NEED_SUDO" = true ]; then
#         sudo ln -sf "${INSTALL_PATH}/${PRODUCT_NAME}" "${INSTALL_PATH}/appmcp"
#     else
#         ln -sf "${INSTALL_PATH}/${PRODUCT_NAME}" "${INSTALL_PATH}/appmcp"
#     fi
# fi

echo -e "${GREEN}🎉 AppMCP build and installation completed successfully!${NC}"
echo -e "${BLUE}📚 For usage information, run: ${PRODUCT_NAME} --help${NC}"