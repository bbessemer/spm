#!/bin/bash

version="1.31.1"

getsrc() {
    wget "https://busybox.net/downloads/busybox-${version}.tar.bz2" -O - | tar -xvj
}

configure() {
    make \
        KBUILD_SRC="${srcdir}" \
        -f ${srcdir}/Makefile
        defconfig
}

build() {
    make -j${jobs}
}

install() {
    make CONFIG_PREFIX=${installdir} install
}