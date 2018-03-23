#!/bin/sh
VERSION=66
COMMIT=
if [ -d webrtc ]; then
    git -C webrtc/src reset --hard
    git -C webrtc/src clean -xdf
    git -C webrtc/src checkout branch-heads/$VERSION
    make sync all
fi
checkinstall \
    -y \
    --install=no \
    --fstrans=yes \
    --maintainer=otamachan@gmail.com \
    --pkgname=libwebrtc-dev \
    --pkgversion=$VERSION.0.0 \
    --pkglicense=BSD \
    --deldesc=yes \
    --backup=no make install TYPE=Release
checkinstall \
    -y \
    --install=no \
    --fstrans=yes \
    --maintainer=otamachan@gmail.com \
    --pkgname=libwebrtc-dev-dbg \
    --pkgversion=$VERSION.0.0 \
    --pkglicense=BSD \
    --deldesc=yes \
    --backup=no make install
rm -rf description* doc-pak
