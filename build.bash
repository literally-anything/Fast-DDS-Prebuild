#!/usr/bin/env bash
#
# Builds Fast-DDS on MacOS
#
set -e
set -o pipefail

if [[ $# > 0 ]]; then
 TAG=$1
 if [[ -z "$2" ]]; then
  JOBS=8
 else
  JOBS=$2
 fi
else
 echo "Usage: build.bash TAG JOBS"
 echo "where TAG is a Fast-DDS version tag eg. v2.0.1"
 echo "and JOBS is a number of workers to use for each build (defaults to 8)"
 exit -1
fi

info() {
 echo -e "\e[1;36m==> \e[32m${1}\e[0m"
}
info2() {
 echo -e "\e[36m==> \e[32m${1}\e[0m"
}


# Check for command line tools
set +e
xcode-select -p > /dev/null
CLI_TOOLS=$?
set -e
if [[ $CLI_TOOLS != 0 ]]; then
 echo -e "\e[1;31m==> \e[32mXcode Command Line tools must be installed\e[0m"
 echo "Use \"xcode-select --install\" to install them"
 exit -1
fi


# Setup paths
REPO_DIR=$(realpath $(dirname "$0"))
CMAKE_DIR=$REPO_DIR/cmake
BUILD_DIR=$REPO_DIR/build
INSTALL_DIR=$BUILD_DIR/install
mkdir -p $BUILD_DIR $INSTALL_DIR
pushd $BUILD_DIR > /dev/null


# Prepate OpenSSL library
SSL_SRC_DIR=$BUILD_DIR/openssl
if [ -d $SSL_SRC_DIR ]; then
 info "Updating OpenSSL..."

 git -C $SSL_SRC_DIR fetch
 git -C $SSL_SRC_DIR -c advice.detachedHead=false checkout origin/v3 --progress
else
 info "Cloning OpenSSL..."
 git clone --progress https://github.com/viaduck/openssl-cmake.git $SSL_SRC_DIR
fi
SSL_BUILD_DIR=$SSL_SRC_DIR/build
mkdir -p $SSL_BUILD_DIR

# Prepate Asio library
ASIO_SRC_DIR=$BUILD_DIR/asio
if [ -d $ASIO_SRC_DIR ]; then
 info "Updating Asio..."

 git -C $ASIO_SRC_DIR fetch
 git -C $ASIO_SRC_DIR -c advice.detachedHead=false checkout origin/master --progress
else
 info "Cloning Asio..."
 git clone --progress https://github.com/chriskohlhoff/asio.git $ASIO_SRC_DIR
fi
git -C $ASIO_SRC_DIR apply --check --apply $REPO_DIR/asio-cmake.patch || echo "Patch could not apply"
ASIO_BUILD_DIR=$ASIO_SRC_DIR/build
mkdir -p $ASIO_BUILD_DIR

# Prepate foonathan memory library
MEMORY_SRC_DIR=$BUILD_DIR/memory
if [ -d $MEMORY_SRC_DIR ]; then
 info "Updating foonathan memory..."

 git -C $MEMORY_SRC_DIR fetch
 git -C $MEMORY_SRC_DIR -c advice.detachedHead=false checkout origin/master --progress
else
 info "Cloning foonathan memory..."
 git clone --progress https://github.com/eProsima/foonathan_memory_vendor.git $MEMORY_SRC_DIR
fi
MEMORY_BUILD_DIR=$MEMORY_SRC_DIR/build
mkdir -p $MEMORY_BUILD_DIR

# Prepare Fast-CDR
CDR_SRC_DIR=$BUILD_DIR/Fast-CDR
if [ -d $CDR_SRC_DIR ]; then
 info "Updating Fast-CDR..."

 git -C $CDR_SRC_DIR fetch
 git -C $CDR_SRC_DIR -c advice.detachedHead=false checkout origin/master --progress
else
 info "Cloning Fast-CDR..."
 git clone --progress https://github.com/eProsima/Fast-CDR.git $CDR_SRC_DIR
fi
CDR_BUILD_DIR=$CDR_SRC_DIR/build
mkdir -p $CDR_BUILD_DIR

# Prepare Fast-DDS
DDS_SRC_DIR=$BUILD_DIR/Fast-DDS
if [ -d $DDS_SRC_DIR ]; then
 info "Checking out Fast-DDS $TAG..."

 git -C $DDS_SRC_DIR fetch --tags
 git -C $DDS_SRC_DIR -c advice.detachedHead=false checkout tags/$TAG --recurse-submodules --progress
 git -C $DDS_SRC_DIR submodule update --init --recursive --remote --progress
else
 info "Cloning Fast-DDS $TAG..."
 git -c advice.detachedHead=false clone --recurse-submodules --progress -b $TAG https://github.com/eProsima/Fast-DDS.git $DDS_SRC_DIR
fi
git -C $DDS_SRC_DIR apply --check --apply $REPO_DIR/Fast-DDS-cmake.patch || echo "Patch could not apply"
DDS_BUILD_DIR=$DDS_SRC_DIR/build
mkdir -p $DDS_BUILD_DIR


# Check for the VisionOS SDK
info "Checking for VisionOS SDK..."
set +e
xcodebuild -showsdks | grep -sq visionOS
VISION_OS=$?
set -e
if [[ $VISION_OS == 0 ]]; then
 echo "Found VisionOS SDK"
else
 echo "No VisionOS SDK"
 echo "Not compiling for VisionOS"
fi

# List platforms that are going to be built
info "Building for Platforms"
echo "- MacOS: x86_64 and arm64"
#echo "- Mac Catalyst: x86_64 and arm64"
echo "- iOS: arm64"
echo "- iOS Simulator: x86_64 and arm64"
if [[ $VISION_OS == 0 ]]; then
 echo "- VisionOS: arm64"
 echo "- VisionOS Simulator: arm64"
fi


# MacOS Build
info "Building for MacOS..."
PLATFORM=macosx
CUR_SSL_BUILD=$SSL_BUILD_DIR/$PLATFORM
CUR_ASIO_BUILD=$ASIO_BUILD_DIR/$PLATFORM
CUR_MEMORY_BUILD=$MEMORY_BUILD_DIR/$PLATFORM
CUR_CDR_BUILD=$CDR_BUILD_DIR/$PLATFORM
CUR_DDS_BUILD=$DDS_BUILD_DIR/$PLATFORM
CUR_INSTALL=$INSTALL_DIR/$PLATFORM
mkdir -p $CUR_SSL_BUILD $CUR_ASIO_BUILD $CUR_MEMORY_BUILD $CUR_CDR_BUILD $CUR_DDS_BUILD $CUR_INSTALL

# Build OpenSSL
info2 "Building OpenSSL for x86_64 and arm64 on MacOS"
cmake -S$SSL_SRC_DIR -B"$CUR_SSL_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/macos.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/openssl.cmake" \
-G Xcode
cmake --build "$CUR_SSL_BUILD" --config Release --target install -j $JOBS -- -sdk "macosx"

# Build Asio
info2 "Building Asio for x86_64 and arm64 on MacOS"
cmake -S"$ASIO_SRC_DIR/asio" -B"$CUR_ASIO_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D OpenSSL_DIR="$CUR_INSTALL/lib/cmake/OpenSSL" \
-D OPENSSL_ROOT_DIR="$CUR_INSTALL" \
-D OPENSSL_INCLUDE_DIR="$CUR_INSTALL/include" \
-D OPENSSL_SSL_LIBRARY="$CUR_INSTALL/lib" \
-D OPENSSL_CRYPTO_LIBRARY="$CUR_INSTALL/lib" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/macos.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/asio.cmake" \
-G Xcode
cmake --build "$CUR_ASIO_BUILD" --config Release --target install -j $JOBS -- -sdk "macosx"

# Build foonathan memory
info2 "Building foonathan memory for x86_64 and arm64 on MacOS"
cmake -S$MEMORY_SRC_DIR -B"$CUR_MEMORY_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/macos.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/foonathan-memory.cmake" \
-G Xcode
cmake --build "$CUR_MEMORY_BUILD" --config Release --target install -j $JOBS -- -sdk "macosx"

# Build Fast-CDR
info2 "Building Fast-CDR for x86_64 and arm64 on MacOS"
cmake -S$CDR_SRC_DIR -B"$CUR_CDR_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/macos.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/Fast-CDR.cmake" \
-G Xcode
cmake --build "$CUR_CDR_BUILD" --config Release --target install -j $JOBS -- -sdk "macosx"

# Build Fast-DDS
info2 "Building Fast-DDS for x86_64 and arm64 on MacOS"
cmake -S$DDS_SRC_DIR -B"$CUR_DDS_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D Asio_DIR="$CUR_INSTALL/lib/cmake/asio" \
-D TINYXML2_LIBRARY="$CUR_INSTALL" \
-D OpenSSL_DIR="$CUR_INSTALL/lib/cmake/OpenSSL" \
-D OPENSSL_ROOT_DIR="$CUR_INSTALL" \
-D OPENSSL_INCLUDE_DIR="$CUR_INSTALL/include" \
-D OPENSSL_SSL_LIBRARY="$CUR_INSTALL/lib" \
-D OPENSSL_CRYPTO_LIBRARY="$CUR_INSTALL/lib" \
-D foonathan_memory_DIR="$CUR_INSTALL/lib/foonathan_memory/cmake" \
-D fastcdr_DIR="$CUR_INSTALL/lib/cmake/fastcdr" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/macos.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/Fast-DDS.cmake" \
-D CMAKE_CXX_FLAGS="-Wno-shorten-64-to-32" \
-G Xcode
cmake --build "$CUR_DDS_BUILD" --config Release --target install -j $JOBS -- -sdk "macosx"

pushd "$CUR_INSTALL/lib" > /dev/null
libtool -static -D -o libfastdds-prebuild.a libssl.a libcrypto.a libAsio.a libfoonathan_memory-0.7.3.a libfastcdr.a libfastdds.a 
popd > /dev/null


# Mac Catalyst Build
#info "Building for Mac Catalyst..."
#PLATFORM=maccatalyst
#CUR_SSL_BUILD=$SSL_BUILD_DIR/$PLATFORM
#CUR_ASIO_BUILD=$ASIO_BUILD_DIR/$PLATFORM
#CUR_MEMORY_BUILD=$MEMORY_BUILD_DIR/$PLATFORM
#CUR_CDR_BUILD=$CDR_BUILD_DIR/$PLATFORM
#CUR_DDS_BUILD=$DDS_BUILD_DIR/$PLATFORM
#CUR_INSTALL=$INSTALL_DIR/$PLATFORM
#mkdir -p $CUR_SSL_BUILD $CUR_ASIO_BUILD $CUR_MEMORY_BUILD $CUR_CDR_BUILD $CUR_DDS_BUILD $CUR_INSTALL

# Build OpenSSL
#info2 "Building OpenSSL for x86_64 and arm64 on Mac Catalyst"
#cmake -S$SSL_SRC_DIR -B"$CUR_SSL_BUILD" \
#-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
#-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/mac-catalyst.toolchain.cmake" \
#-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/openssl.cmake" \
#-G Xcode
#cmake --build "$CUR_SSL_BUILD" --config Release --target install -j $JOBS

# Build Asio
#info2 "Building Asio for x86_64 and arm64 on Mac Catalyst"
#cmake -S"$ASIO_SRC_DIR/asio" -B"$CUR_ASIO_BUILD" \
#-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
#-D OpenSSL_DIR="$CUR_INSTALL/lib/cmake/OpenSSL" \
#-D OPENSSL_ROOT_DIR="$CUR_INSTALL" \
#-D OPENSSL_INCLUDE_DIR="$CUR_INSTALL/include" \
#-D OPENSSL_SSL_LIBRARY="$CUR_INSTALL/lib" \
#-D OPENSSL_CRYPTO_LIBRARY="$CUR_INSTALL/lib" \
#-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/mac-catalyst.toolchain.cmake" \
#-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/asio.cmake" \
#-G Xcode
#cmake --build "$CUR_ASIO_BUILD" --config Release --target install -j $JOBS

# Build foonathan memory
#info2 "Building foonathan memory for x86_64 and arm64 on Mac Catalyst"
#cmake -S$MEMORY_SRC_DIR -B"$CUR_MEMORY_BUILD" \
#-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
#-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/mac-catalyst.toolchain.cmake" \
#-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/foonathan-memory.cmake" \
#-G Xcode
#cmake --build "$CUR_MEMORY_BUILD" --config Release --target install -j $JOBS -- -sdk "iphoneos"
#xcodebuild build -scheme install -destination 'generic/platform=macOS,variant=Mac Catalyst' -project "$CUR_MEMORY_BUILD/foonathan_memory_vendor.xcodeproj" -jobs $JOBS

# Build Fast-CDR
#info2 "Building Fast-CDR for x86_64 and arm64 on Mac Catalyst"
#cmake -S$CDR_SRC_DIR -B"$CUR_CDR_BUILD" \
#-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
#-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/mac-catalyst.toolchain.cmake" \
#-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/Fast-CDR.cmake" \
#-G Xcode
#xcodebuild build -scheme install -destination 'generic/platform=macOS,variant=Mac Catalyst' -project "$CUR_CDR_BUILD/fastcdr.xcodeproj" -jobs $JOBS

# Build Fast-DDS
#info2 "Building Fast-DDS for x86_64 and arm64 on Mac Catalyst"
#cmake -S$DDS_SRC_DIR -B"$CUR_DDS_BUILD" \
#-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
#-D Asio_DIR="$CUR_INSTALL/lib/cmake/asio" \
#-D TINYXML2_LIBRARY="$CUR_INSTALL" \
#-D OpenSSL_DIR="$CUR_INSTALL/lib/cmake/OpenSSL" \
#-D OPENSSL_ROOT_DIR="$CUR_INSTALL" \
#-D OPENSSL_INCLUDE_DIR="$CUR_INSTALL/include" \
#-D OPENSSL_SSL_LIBRARY="$CUR_INSTALL/lib" \
#-D OPENSSL_CRYPTO_LIBRARY="$CUR_INSTALL/lib" \
#-D foonathan_memory_DIR="$CUR_INSTALL/lib/foonathan_memory/cmake" \
#-D fastcdr_DIR="$CUR_INSTALL/lib/cmake/fastcdr" \
#-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/mac-catalyst.toolchain.cmake" \
#-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/Fast-DDS.cmake" \
#-D CMAKE_CXX_FLAGS="-std=c++11 -Wno-shorten-64-to-32" \
#-D SHM_TRANSPORT_DEFAULT=OFF \
#-G Xcode
#xcodebuild build -scheme install -destination 'generic/platform=macOS,variant=Mac Catalyst' -project "$CUR_DDS_BUILD/fastdds.xcodeproj" -jobs $JOBS

#pushd "$CUR_INSTALL/lib" > /dev/null
#libtool -static -D -o libfastdds-prebuild.a libssl.a libcrypto.a libAsio.a libfoonathan_memory-0.7.3.a libfastcdr.a libfastdds.a 
#popd > /dev/null


# iOS Build
info "Building for iOS..."
PLATFORM=iphoneos
CUR_SSL_BUILD=$SSL_BUILD_DIR/$PLATFORM
CUR_ASIO_BUILD=$ASIO_BUILD_DIR/$PLATFORM
CUR_MEMORY_BUILD=$MEMORY_BUILD_DIR/$PLATFORM
CUR_CDR_BUILD=$CDR_BUILD_DIR/$PLATFORM
CUR_DDS_BUILD=$DDS_BUILD_DIR/$PLATFORM
CUR_INSTALL=$INSTALL_DIR/$PLATFORM
mkdir -p $CUR_SSL_BUILD $CUR_ASIO_BUILD $CUR_MEMORY_BUILD $CUR_CDR_BUILD $CUR_DDS_BUILD $CUR_INSTALL

# Build OpenSSL
info2 "Building OpenSSL for arm64 on iOS"
cmake -S$SSL_SRC_DIR -B"$CUR_SSL_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/ios.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/openssl.cmake" \
-G Xcode
cmake --build "$CUR_SSL_BUILD" --config Release --target install -j $JOBS -- -sdk "iphoneos"

# Build Asio
info2 "Building Asio for arm64 on iOS"
cmake -S"$ASIO_SRC_DIR/asio" -B"$CUR_ASIO_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D OpenSSL_DIR="$CUR_INSTALL/lib/cmake/OpenSSL" \
-D OPENSSL_ROOT_DIR="$CUR_INSTALL" \
-D OPENSSL_INCLUDE_DIR="$CUR_INSTALL/include" \
-D OPENSSL_SSL_LIBRARY="$CUR_INSTALL/lib" \
-D OPENSSL_CRYPTO_LIBRARY="$CUR_INSTALL/lib" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/ios.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/asio.cmake" \
-G Xcode
cmake --build "$CUR_ASIO_BUILD" --config Release --target install -j $JOBS -- -sdk "iphoneos"

# Build foonathan memory
info2 "Building foonathan memory for arm64 on iOS"
cmake -S$MEMORY_SRC_DIR -B"$CUR_MEMORY_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/ios.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/foonathan-memory.cmake" \
-G Xcode
cmake --build "$CUR_MEMORY_BUILD" --config Release --target install -j $JOBS -- -sdk "iphoneos"

# Build Fast-CDR
info2 "Building Fast-CDR for arm64 on iOS"
cmake -S$CDR_SRC_DIR -B"$CUR_CDR_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/ios.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/Fast-CDR.cmake" \
-G Xcode
cmake --build "$CUR_CDR_BUILD" --config Release --target install -j $JOBS -- -sdk "iphoneos"

# Build Fast-DDS
info2 "Building Fast-DDS for arm64 on iOS"
cmake -S$DDS_SRC_DIR -B"$CUR_DDS_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D Asio_DIR="$CUR_INSTALL/lib/cmake/asio" \
-D TINYXML2_LIBRARY="$CUR_INSTALL" \
-D OpenSSL_DIR="$CUR_INSTALL/lib/cmake/OpenSSL" \
-D OPENSSL_ROOT_DIR="$CUR_INSTALL" \
-D OPENSSL_INCLUDE_DIR="$CUR_INSTALL/include" \
-D OPENSSL_SSL_LIBRARY="$CUR_INSTALL/lib" \
-D OPENSSL_CRYPTO_LIBRARY="$CUR_INSTALL/lib" \
-D foonathan_memory_DIR="$CUR_INSTALL/lib/foonathan_memory/cmake" \
-D fastcdr_DIR="$CUR_INSTALL/lib/cmake/fastcdr" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/ios.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/Fast-DDS.cmake" \
-D CMAKE_CXX_FLAGS="-Wno-shorten-64-to-32" \
-D SHM_TRANSPORT_DEFAULT=OFF \
-G Xcode
cmake --build "$CUR_DDS_BUILD" --config Release --target install -j $JOBS -- -sdk "iphoneos"

pushd "$CUR_INSTALL/lib" > /dev/null
libtool -static -D -o libfastdds-prebuild.a libssl.a libcrypto.a libAsio.a libfoonathan_memory-0.7.3.a libfastcdr.a libfastdds.a 
popd > /dev/null


# iOS Simulator Build
info "Building for iOS Simulator..."
PLATFORM=iphonesimulator
CUR_SSL_BUILD=$SSL_BUILD_DIR/$PLATFORM
CUR_ASIO_BUILD=$ASIO_BUILD_DIR/$PLATFORM
CUR_MEMORY_BUILD=$MEMORY_BUILD_DIR/$PLATFORM
CUR_CDR_BUILD=$CDR_BUILD_DIR/$PLATFORM
CUR_DDS_BUILD=$DDS_BUILD_DIR/$PLATFORM
CUR_INSTALL=$INSTALL_DIR/$PLATFORM
mkdir -p $CUR_SSL_BUILD $CUR_ASIO_BUILD $CUR_MEMORY_BUILD $CUR_CDR_BUILD $CUR_DDS_BUILD $CUR_INSTALL

# Build OpenSSL
info2 "Building OpenSSL for x86_64 and arm64 on iOS Simulator"
cmake -S$SSL_SRC_DIR -B"$CUR_SSL_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/ios-simulator.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/openssl.cmake" \
-G Xcode
cmake --build "$CUR_SSL_BUILD" --config Release --target install -j $JOBS -- -sdk "iphonesimulator"

# Build Asio
info2 "Building Asio for x86_64 and arm64 on iOS Simulator"
cmake -S"$ASIO_SRC_DIR/asio" -B"$CUR_ASIO_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D OpenSSL_DIR="$CUR_INSTALL/lib/cmake/OpenSSL" \
-D OPENSSL_ROOT_DIR="$CUR_INSTALL" \
-D OPENSSL_INCLUDE_DIR="$CUR_INSTALL/include" \
-D OPENSSL_SSL_LIBRARY="$CUR_INSTALL/lib" \
-D OPENSSL_CRYPTO_LIBRARY="$CUR_INSTALL/lib" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/ios-simulator.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/asio.cmake" \
-G Xcode
cmake --build "$CUR_ASIO_BUILD" --config Release --target install -j $JOBS -- -sdk "iphonesimulator"

# Build foonathan memory
info2 "Building foonathan memory for arm64 on iOS Simulator"
cmake -S$MEMORY_SRC_DIR -B"$CUR_MEMORY_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/ios-simulator.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/foonathan-memory.cmake" \
-G Xcode
cmake --build "$CUR_MEMORY_BUILD" --config Release --target install -j $JOBS -- -sdk "iphonesimulator"

# Build Fast-CDR
info2 "Building Fast-CDR for arm64 on iOS Simulator"
cmake -S$CDR_SRC_DIR -B"$CUR_CDR_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/ios-simulator.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/Fast-CDR.cmake" \
-G Xcode
cmake --build "$CUR_CDR_BUILD" --config Release --target install -j $JOBS -- -sdk "iphonesimulator"

# Build Fast-DDS
info2 "Building Fast-DDS for arm64 on iOS Simulator"
cmake -S$DDS_SRC_DIR -B"$CUR_DDS_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D Asio_DIR="$CUR_INSTALL/lib/cmake/asio" \
-D TINYXML2_LIBRARY="$CUR_INSTALL" \
-D OpenSSL_DIR="$CUR_INSTALL/lib/cmake/OpenSSL" \
-D OPENSSL_ROOT_DIR="$CUR_INSTALL" \
-D OPENSSL_INCLUDE_DIR="$CUR_INSTALL/include" \
-D OPENSSL_SSL_LIBRARY="$CUR_INSTALL/lib" \
-D OPENSSL_CRYPTO_LIBRARY="$CUR_INSTALL/lib" \
-D foonathan_memory_DIR="$CUR_INSTALL/lib/foonathan_memory/cmake" \
-D fastcdr_DIR="$CUR_INSTALL/lib/cmake/fastcdr" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/ios-simulator.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/Fast-DDS.cmake" \
-D CMAKE_CXX_FLAGS="-Wno-shorten-64-to-32" \
-D SHM_TRANSPORT_DEFAULT=OFF \
-G Xcode
cmake --build "$CUR_DDS_BUILD" --config Release --target install -j $JOBS -- -sdk "iphonesimulator"

pushd "$CUR_INSTALL/lib" > /dev/null
libtool -static -D -o libfastdds-prebuild.a libssl.a libcrypto.a libAsio.a libfoonathan_memory-0.7.3.a libfastcdr.a libfastdds.a 
popd > /dev/null

if [[ $VISION_OS == 0 ]]; then
# VisionOS Build
info "Building for VisionOS..."
PLATFORM=xros
CUR_SSL_BUILD=$SSL_BUILD_DIR/$PLATFORM
CUR_ASIO_BUILD=$ASIO_BUILD_DIR/$PLATFORM
CUR_MEMORY_BUILD=$MEMORY_BUILD_DIR/$PLATFORM
CUR_CDR_BUILD=$CDR_BUILD_DIR/$PLATFORM
CUR_DDS_BUILD=$DDS_BUILD_DIR/$PLATFORM
CUR_INSTALL=$INSTALL_DIR/$PLATFORM
mkdir -p $CUR_SSL_BUILD $CUR_ASIO_BUILD $CUR_MEMORY_BUILD $CUR_CDR_BUILD $CUR_DDS_BUILD $CUR_INSTALL

# Build OpenSSL
info2 "Building OpenSSL for arm64 on VisionOS"
cmake -S$SSL_SRC_DIR -B"$CUR_SSL_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/visionos.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/openssl.cmake" \
-G Xcode
cmake --build "$CUR_SSL_BUILD" --config Release --target install -j $JOBS -- -sdk "xros"

# Build Asio
info2 "Building Asio for arm64 on VisionOS"
cmake -S"$ASIO_SRC_DIR/asio" -B"$CUR_ASIO_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D OpenSSL_DIR="$CUR_INSTALL/lib/cmake/OpenSSL" \
-D OPENSSL_ROOT_DIR="$CUR_INSTALL" \
-D OPENSSL_INCLUDE_DIR="$CUR_INSTALL/include" \
-D OPENSSL_SSL_LIBRARY="$CUR_INSTALL/lib" \
-D OPENSSL_CRYPTO_LIBRARY="$CUR_INSTALL/lib" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/visionos.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/asio.cmake" \
-G Xcode
cmake --build "$CUR_ASIO_BUILD" --config Release --target install -j $JOBS -- -sdk "xros"

# Build foonathan memory
info2 "Building foonathan memory for arm64 on VisionOS"
cmake -S$MEMORY_SRC_DIR -B"$CUR_MEMORY_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/visionos.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/foonathan-memory.cmake" \
-G Xcode
cmake --build "$CUR_MEMORY_BUILD" --config Release --target install -j $JOBS -- -sdk "xros"

# Build Fast-CDR
info2 "Building Fast-CDR for arm64 on VisionOS"
cmake -S$CDR_SRC_DIR -B"$CUR_CDR_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/visionos.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/Fast-CDR.cmake" \
-G Xcode
cmake --build "$CUR_CDR_BUILD" --config Release --target install -j $JOBS -- -sdk "xros"

# Build Fast-DDS
info2 "Building Fast-DDS for arm64 on VisionOS"
cmake -S$DDS_SRC_DIR -B"$CUR_DDS_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D Asio_DIR="$CUR_INSTALL/lib/cmake/asio" \
-D TINYXML2_LIBRARY="$CUR_INSTALL" \
-D OpenSSL_DIR="$CUR_INSTALL/lib/cmake/OpenSSL" \
-D OPENSSL_ROOT_DIR="$CUR_INSTALL" \
-D OPENSSL_INCLUDE_DIR="$CUR_INSTALL/include" \
-D OPENSSL_SSL_LIBRARY="$CUR_INSTALL/lib" \
-D OPENSSL_CRYPTO_LIBRARY="$CUR_INSTALL/lib" \
-D foonathan_memory_DIR="$CUR_INSTALL/lib/foonathan_memory/cmake" \
-D fastcdr_DIR="$CUR_INSTALL/lib/cmake/fastcdr" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/visionos.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/Fast-DDS.cmake" \
-D CMAKE_CXX_FLAGS="-Wno-shorten-64-to-32" \
-D SHM_TRANSPORT_DEFAULT=OFF \
-G Xcode
cmake --build "$CUR_DDS_BUILD" --config Release --target install -j $JOBS -- -sdk "xros"

pushd "$CUR_INSTALL/lib" > /dev/null
libtool -static -D -o libfastdds-prebuild.a libssl.a libcrypto.a libAsio.a libfoonathan_memory-0.7.3.a libfastcdr.a libfastdds.a 
popd > /dev/null


# VisionOS Simulator Build
info "Building for VisionOS Simulator..."
PLATFORM=xrsimulator
CUR_SSL_BUILD=$SSL_BUILD_DIR/$PLATFORM
CUR_ASIO_BUILD=$ASIO_BUILD_DIR/$PLATFORM
CUR_MEMORY_BUILD=$MEMORY_BUILD_DIR/$PLATFORM
CUR_CDR_BUILD=$CDR_BUILD_DIR/$PLATFORM
CUR_DDS_BUILD=$DDS_BUILD_DIR/$PLATFORM
CUR_INSTALL=$INSTALL_DIR/$PLATFORM
mkdir -p $CUR_SSL_BUILD $CUR_ASIO_BUILD $CUR_MEMORY_BUILD $CUR_CDR_BUILD $CUR_DDS_BUILD $CUR_INSTALL

# Build OpenSSL
info2 "Building OpenSSL for arm64 on VisionOS Simulator"
cmake -S$SSL_SRC_DIR -B"$CUR_SSL_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/visionos-simulator.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/openssl.cmake" \
-G Xcode
cmake --build "$CUR_SSL_BUILD" --config Release --target install -j $JOBS -- -sdk "xrsimulator"

# Build Asio
info2 "Building Asio for arm64 on VisionOS Simulator"
cmake -S"$ASIO_SRC_DIR/asio" -B"$CUR_ASIO_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D OpenSSL_DIR="$CUR_INSTALL/lib/cmake/OpenSSL" \
-D OPENSSL_ROOT_DIR="$CUR_INSTALL" \
-D OPENSSL_INCLUDE_DIR="$CUR_INSTALL/include" \
-D OPENSSL_SSL_LIBRARY="$CUR_INSTALL/lib" \
-D OPENSSL_CRYPTO_LIBRARY="$CUR_INSTALL/lib" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/visionos-simulator.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/asio.cmake" \
-G Xcode
cmake --build "$CUR_ASIO_BUILD" --config Release --target install -j $JOBS -- -sdk "xrsimulator"

# Build foonathan memory
info2 "Building foonathan memory for arm64 on VisionOS Simulator"
cmake -S$MEMORY_SRC_DIR -B"$CUR_MEMORY_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/visionos-simulator.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/foonathan-memory.cmake" \
-G Xcode
cmake --build "$CUR_MEMORY_BUILD" --config Release --target install -j $JOBS -- -sdk "xrsimulator"

# Build Fast-CDR
info2 "Building Fast-CDR for arm64 on VisionOS Simulator"
cmake -S$CDR_SRC_DIR -B"$CUR_CDR_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/visionos-simulator.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/Fast-CDR.cmake" \
-G Xcode
cmake --build "$CUR_CDR_BUILD" --config Release --target install -j $JOBS -- -sdk "xrsimulator"

# Build Asio
info2 "Building Asio for arm64 on VisionOS Simulator"
cmake -S"$ASIO_SRC_DIR/asio" -B"$CUR_ASIO_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/visionos-simulator.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/asio.cmake" \
-G Xcode
cmake --build "$CUR_ASIO_BUILD" --config Release --target install -j $JOBS

# Build Fast-DDS
info2 "Building Fast-DDS for arm64 on VisionOS Simulator"
cmake -S$DDS_SRC_DIR -B"$CUR_DDS_BUILD" \
-D CMAKE_INSTALL_PREFIX="$CUR_INSTALL" \
-D Asio_DIR="$CUR_INSTALL/lib/cmake/asio" \
-D TINYXML2_LIBRARY="$CUR_INSTALL" \
-D OpenSSL_DIR="$CUR_INSTALL/lib/cmake/OpenSSL" \
-D OPENSSL_ROOT_DIR="$CUR_INSTALL" \
-D OPENSSL_INCLUDE_DIR="$CUR_INSTALL/include" \
-D OPENSSL_SSL_LIBRARY="$CUR_INSTALL/lib" \
-D OPENSSL_CRYPTO_LIBRARY="$CUR_INSTALL/lib" \
-D foonathan_memory_DIR="$CUR_INSTALL/lib/foonathan_memory/cmake" \
-D fastcdr_DIR="$CUR_INSTALL/lib/cmake/fastcdr" \
-D CMAKE_TOOLCHAIN_FILE="$CMAKE_DIR/visionos-simulator.toolchain.cmake" \
-D CMAKE_PROJECT_INCLUDE="$CMAKE_DIR/Fast-DDS.cmake" \
-D CMAKE_CXX_FLAGS="-Wno-shorten-64-to-32" \
-D SHM_TRANSPORT_DEFAULT=OFF \
-G Xcode
cmake --build "$CUR_DDS_BUILD" --config Release --target install -j $JOBS -- -sdk "xrsimulator"

pushd "$CUR_INSTALL/lib" > /dev/null
libtool -static -D -o libfastdds-prebuild.a libssl.a libcrypto.a libAsio.a libfoonathan_memory-0.7.3.a libfastcdr.a libfastdds.a 
popd > /dev/null
fi


info "Packaging into an XCFramework..."
xcodebuild -create-xcframework \
-library $INSTALL_DIR/macosx/lib/libfastdds-prebuild.a \
-headers $INSTALL_DIR/macosx/include \
-library $INSTALL_DIR/iphoneos/lib/libfastdds-prebuild.a \
-headers $INSTALL_DIR/iphoneos/include \
-library $INSTALL_DIR/iphonesimulator/lib/libfastdds-prebuild.a \
-headers $INSTALL_DIR/iphonesimulator/include \
-library $INSTALL_DIR/xros/lib/libfastdds-prebuild.a \
-headers $INSTALL_DIR/xros/include \
-output $REPO_DIR/Fast-DDS.xcframework

#-library $INSTALL_DIR/xrsimulator/lib/libfastdds-prebuild.a \
#-headers $INSTALL_DIR/xrsimulator/include \

info "Built $TAG at $REPO_DIR/Fast-DDS.xcframework"
