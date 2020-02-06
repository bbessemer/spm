#!/bin/bash

version="1.31.1"
builddeps="gcc make"

getsrc() {
    wget "https://busybox.net/downloads/busybox-${version}.tar.bz2" -O - | tar -xj
}

configure() {
    make \
        KBUILD_SRC="${srcdir}" \
        -f ${srcdir}/Makefile \
        defconfig
}

build() {
    make -j${jobs}
}

install() {
    make CONFIG_PREFIX=${installdir} install
}