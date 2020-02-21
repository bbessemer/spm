#!/bin/bash

version="9.2.0"
builddeps="gcc make gmp mpfr mpc"
dependencies="binutils"
srcurl="https://ftp.gnu.org/gnu/gcc/gcc-${version}/gcc-${version}.tar.xz"

configure() {
    ${srcdir}/configure \
        --prefix=${stagedir}/usr \
        --disable-bootstrap \
        --disable-multilib \
        x86_64-linux-gnu
}

build() {
    make -j${jobs}
}

stage() {
    make install
}