#!/bin/bash

version="2.34"
builddeps="gcc"
srcurl="https://ftp.gnu.org/gnu/binutils/binutils-${version}.tar.xz"

configure() {
    ${srcdir}/configure --prefix=${stagedir}/usr
}

build() {
    make -j${jobs}
}

stage() {
    make install
}