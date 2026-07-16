# Build-only image providing QNAP's QDK (qbuild) to package the .qpkg.
# Nothing from this image runs on the NAS; it only assembles the .qpkg file.
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    git build-essential fakeroot gawk sed grep coreutils \
    file gzip tar util-linux ca-certificates rsync \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 https://github.com/qnap-dev/QDK /opt/QDK \
    && cd /opt/QDK && (yes | ./InstallToUbuntu.sh install || true)
# qbuild installs to /usr/share/QDK/bin/qbuild
RUN test -x /usr/share/QDK/bin/qbuild
ENV PATH="/usr/share/QDK/bin:${PATH}"
WORKDIR /build
CMD ["/bin/bash"]
