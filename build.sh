#!/bin/sh
VERSION=${VERSION:=66}
echo TYPE=${TYPE} VERSION=${VERSION} OUTPUT=${OUTPUT}
make TYPE=${TYPE} VERSION=${VERSION}
COMMIT=$(git -C webrtc/src rev-parse --short HEAD)
checkinstall \
    -y \
    --install=no \
    --fstrans=yes \
    --maintainer=otamachan@gmail.com \
    --pkgname=libwebrtc$(if [ "${TYPE}" = "Debug" ]; then echo _debug; fi)-dev \
    --pkgversion=$VERSION.0.0-${COMMIT} \
    --pkglicense=BSD \
    --deldesc=yes \
    --backup=no make install TYPE=${TYPE}
rm -rf description* doc-pak
if [ -n "${OUTPUT}" ]; then
    cp *.deb ${OUTPUT}
fi
ls ${OUTPUT}
