#!/bin/sh
set -xe
VERSION=${VERSION:=66}
TARGET_CPU=${TARGET_CPU:=x64}
echo TARGET_CPU=${TARGET_CPU} TYPE=${TYPE} VERSION=${VERSION} OUTPUT=${OUTPUT}
make TARGET_CPU=${TARGET_CPU} TYPE=${TYPE} VERSION=${VERSION}
COMMIT=$(git -C webrtc/src rev-parse --short HEAD)
ARCH=${TARGET_CPU}
if [ "${ARCH}" = "x64" ]; then ARCH=amd64; fi
checkinstall \
    -y \
    --install=no \
    --fstrans=yes \
    --maintainer=otamachan@gmail.com \
    --arch=${ARCH} \
    --pkgname=libwebrtc$(if [ "${TYPE}" = "Debug" ]; then echo _debug; fi)-dev \
    --pkgversion=$VERSION.0.0-${COMMIT} \
    --pkglicense=BSD \
    --requires="libx11-dev" \
    --deldesc=yes \
    --backup=no make install TARGET_CPU=${TARGET_CPU} TYPE=${TYPE} VERSION=${VERSION}
rm -rf description* doc-pak
if [ -n "${OUTPUT}" ]; then
    cp *.deb ${OUTPUT}
fi
ls ${OUTPUT}
