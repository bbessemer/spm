#!/bin/bash

version="1.31.1"
builddeps="gcc make"
srcurl="https://busybox.net/downloads/busybox-${version}.tar.bz2"

configure() {
    make \
        KBUILD_SRC="${srcdir}" \
        -f ${srcdir}/Makefile \
        defconfig
}

build() {
    make -j${jobs}
}

stage() {
    make CONFIG_PREFIX=${stagedir} install
}