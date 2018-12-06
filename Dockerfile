FROM ubuntu:16.04
RUN apt-get update \
    && apt-get install -y \
       build-essential \
       gcc-aarch64-linux-gnu \
       gcc-arm-linux-gnueabihf \
       checkinstall \
       gettext \
       git \
       pkg-config \
       python-minimal \
       wget \
    && rm -rf /var/lib/apt/lists/*
ADD build.sh /root
ADD Makefile /root
ADD patches /root/patches
ADD libwebrtc.pc.in /root
WORKDIR /root
CMD ["/root/build.sh"]