FROM ubuntu:bionic as stage0

RUN apt-get update \
    && apt-get install -y \
        build-essential \
        bash \
        git \
        libgmp-dev \
        libmpfr-dev \
        libmpc-dev \
        wget \
        xz-utils

WORKDIR /usr/share
COPY . spm/
RUN ln -s /usr/share/spm/spm /usr/bin/spm

RUN mkdir -p /new \
    && spm install \
            --noninteractive \
            --verbose \
            --source \
            --install-root=/new \
            --ignore-builddeps \
        busybox \
        gcc \
        binutils


FROM scratch as stage1

COPY --from=stage0 /new /