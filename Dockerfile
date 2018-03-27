FROM ubuntu:16.04
RUN apt-get update \
    && apt-get install -y \
       build-essential \
       checkinstall \
       gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
       gettext \
       git \
       pkg-config \
       python-minimal \
       wget \
    && rm -rf /var/lib/apt/lists/*
ADD build.sh /root
ADD Makefile /root
ADD libwebrtc.pc.in /root
WORKDIR /root
CMD ["/root/build.sh"]