#!/bin/bash
set -euo pipefail

# Lambda Build Script
# Builds and packages Lambda functions for deployment

FUNCTION_NAME="${1:-}"
OUTPUT_DIR="${2:-dist}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FUNCTION_DIR="$PROJECT_ROOT/infra/lambda-functions/$FUNCTION_NAME"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[BUILD]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

usage() {
    cat << EOF
Usage: $0 <function-name> [output-dir]

Builds and packages a Lambda function for deployment.

Arguments:
  function-name    Name of the Lambda function to build
  output-dir       Output directory for the package (default: dist)

Supported functions:
  - api-docs-generator
  - generate-presigned-url
  - insert-ppu-data
  - lambda-test-runner
  - presigned-url-s3-upload
  - software-event-update-handler
  - sync-clock

Examples:
  $0 sync-clock
  $0 insert-ppu-data build

Environment Variables:
  PYTHON_VERSION   Python version to use (default: auto-detect)
  BUILD_MODE       Build mode (dev|prod) (default: prod)
EOF
}

validate_function() {
    local func_name="$1"
    
    log "🔍 Validating function: $func_name"
    
    if [ ! -d "$FUNCTION_DIR" ]; then
        error "❌ Function directory not found: $FUNCTION_DIR"
        return 1
    fi
    
    # Check for main handler file
    local handler_files=("lambda_function.py" "insertPPUData.py" "main.py" "handler.py")
    local handler_found=false
    
    for handler in "${handler_files[@]}"; do
        if [ -f "$FUNCTION_DIR/$handler" ]; then
            log "✅ Found handler: $handler"
            handler_found=true
            break
        fi
    done
    
    if [ "$handler_found" = false ]; then
        error "❌ No handler file found in $FUNCTION_DIR"
        error "   Expected one of: ${handler_files[*]}"
        return 1
    fi
    
    return 0
}

setup_build_environment() {
    log "🔧 Setting up build environment"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Create temporary build directory
    BUILD_TEMP_DIR=$(mktemp -d)
    log "📁 Build directory: $BUILD_TEMP_DIR"
    
    # Copy function source code
    log "📋 Copying function source code"
    cp -r "$FUNCTION_DIR"/* "$BUILD_TEMP_DIR/"
    
    return 0
}

install_dependencies() {
    local build_dir="$1"
    
    log "📦 Installing dependencies"
    
    cd "$build_dir"
    
    # Check if requirements.txt exists
    if [ -f "requirements.txt" ]; then
        log "📋 Found requirements.txt, installing dependencies"
        
        # Install to build directory
        pip install -r requirements.txt -t . --no-deps --no-cache-dir
        
        log "✅ Dependencies installed successfully"
    else
        log "ℹ️ No requirements.txt found, skipping dependency installation"
    fi
    
    return 0
}

optimize_package() {
    local build_dir="$1"
    
    log "🚀 Optimizing package"
    
    cd "$build_dir"
    
    # Remove unnecessary files
    log "🧹 Removing unnecessary files"
    
    # Remove test files and directories
    find . -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true
    find . -name "*_test.py" -delete 2>/dev/null || true
    find . -name "test_*.py" -delete 2>/dev/null || true
    
    # Remove documentation and example files
    find . -name "*.md" -delete 2>/dev/null || true
    find . -name "*.rst" -delete 2>/dev/null || true
    find . -name "*.txt" ! -name "requirements.txt" -delete 2>/dev/null || true
    find . -name "examples" -type d -exec rm -rf {} + 2>/dev/null || true
    
    # Remove cache files
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.pyc" -delete 2>/dev/null || true
    find . -name "*.pyo" -delete 2>/dev/null || true
    find . -name ".DS_Store" -delete 2>/dev/null || true
    
    # Remove development and build files
    find . -name ".git*" -delete 2>/dev/null || true
    find . -name "setup.py" -delete 2>/dev/null || true
    find . -name "setup.cfg" -delete 2>/dev/null || true
    find . -name "*.egg-info" -type d -exec rm -rf {} + 2>/dev/null || true
    
    log "✅ Package optimization completed"
    
    return 0
}

create_package() {
    local build_dir="$1"
    local package_name="$2"
    
    log "📦 Creating deployment package"
    
    cd "$build_dir"
    
    # Create ZIP package
    local package_path="$PROJECT_ROOT/$OUTPUT_DIR/$package_name"
    
    # Remove existing package if it exists
    rm -f "$package_path"
    
    # Create the ZIP file
    zip -r "$package_path" . -x "*.zip" > /dev/null
    
    if [ -f "$package_path" ]; then
        local package_size=$(stat -f%z "$package_path" 2>/dev/null || stat -c%s "$package_path")
        local package_size_mb=$((package_size / 1024 / 1024))
        
        success "✅ Package created successfully: $package_path"
        log "📊 Package size: ${package_size} bytes (${package_size_mb}MB)"
        
        # Warn if package is large
        if [ "$package_size" -gt 50000000 ]; then  # 50MB
            warn "⚠️ Package is large (>50MB). Consider optimizing dependencies."
        fi
        
        # Error if package is too large for Lambda
        if [ "$package_size" -gt 262144000 ]; then  # 250MB
            error "❌ Package exceeds AWS Lambda limit (250MB uncompressed)"
            return 1
        fi
        
        return 0
    else
        error "❌ Failed to create package: $package_path"
        return 1
    fi
}

validate_package() {
    local package_path="$1"
    
    log "✅ Validating package"
    
    # Check if package exists
    if [ ! -f "$package_path" ]; then
        error "❌ Package not found: $package_path"
        return 1
    fi
    
    # Check if package can be opened
    if ! unzip -t "$package_path" > /dev/null 2>&1; then
        error "❌ Package is corrupted or invalid: $package_path"
        return 1
    fi
    
    # List package contents for verification
    log "📋 Package contents:"
    unzip -l "$package_path" | head -20 | sed 's/^/   /'
    
    local file_count=$(unzip -l "$package_path" | wc -l)
    log "📊 Total files in package: $file_count"
    
    success "✅ Package validation completed"
    
    return 0
}

cleanup() {
    if [ -n "${BUILD_TEMP_DIR:-}" ] && [ -d "$BUILD_TEMP_DIR" ]; then
        log "🧹 Cleaning up temporary files"
        rm -rf "$BUILD_TEMP_DIR"
    fi
}

main() {
    # Validate arguments
    if [ -z "$FUNCTION_NAME" ]; then
        error "Function name is required"
        usage
        exit 1
    fi
    
    log "🚀 Starting build for function: $FUNCTION_NAME"
    log "📁 Output directory: $OUTPUT_DIR"
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Validate function
    if ! validate_function "$FUNCTION_NAME"; then
        error "❌ Function validation failed"
        exit 1
    fi
    
    # Setup build environment
    if ! setup_build_environment; then
        error "❌ Failed to setup build environment"
        exit 1
    fi
    
    # Install dependencies
    if ! install_dependencies "$BUILD_TEMP_DIR"; then
        error "❌ Failed to install dependencies"
        exit 1
    fi
    
    # Optimize package
    if ! optimize_package "$BUILD_TEMP_DIR"; then
        error "❌ Failed to optimize package"
        exit 1
    fi
    
    # Create package
    local package_name="$FUNCTION_NAME.zip"
    if ! create_package "$BUILD_TEMP_DIR" "$package_name"; then
        error "❌ Failed to create package"
        exit 1
    fi
    
    # Validate package
    local package_path="$PROJECT_ROOT/$OUTPUT_DIR/$package_name"
    if ! validate_package "$package_path"; then
        error "❌ Package validation failed"
        exit 1
    fi
    
    success "🎉 Build completed successfully for $FUNCTION_NAME"
    success "📦 Package: $package_path"
}

# Handle help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

main "$@"