#!/bin/bash

sources="${SP_ROOT}/sources"
build="${SP_ROOT}/build"
install="${SP_ROOT}/install"
packages="${SP_ROOT}/packages"
logs="${SP_ROOT}/logs"

mkdir -p ${sources} ${build} ${install} ${packages}

case $1 in
    # Build dependencies as well
    -r|--recursive)
        recursive=1 exec $0 ${@:2}
        ;;

    # Install into directory instead of packaging
    -R|--root-dir)
        installdir="$2" exec $0 ${@:3}
        ;;
    --root-dir=*)
        installdir=$(echo $1 | cut -c 12-) exec $0 ${@:2}
        ;;
    
    # Assume build dependencies are already installed
    -B|--bootstrap)
        bootstrap=1 exec $0 ${@:2}
        ;;

    # Number of parallel jobs for build systems (defaults to nCPUs)
    -j|--jobs)
        jobs="$2" exec $0 ${@:3}
        ;;
    --jobs=*)
        jobs=$(echo $1 | cut -c 8-) exec $0 ${@:2}
        ;;

    # Maximum number of parallel jobs (use only if > nCPUs)
    -J|--max-jobs)
        max_jobs="$2" exec $0 ${@:3}
        ;;
    --max-jobs=*)
        max_jobs=$(echo $1 | cut -c 8-) exec $0 ${@:2}
        ;;

    # Print output of subcommands to stdout
    -v|--verbose)
        stdout="&1" exec $0 ${@:2}
        ;;

    # Build a package and all its dependencies into a single binary tarball
    # (useful for building an entire system from source)
    # implies --recursive
    --vendored)
        vendored=1 exec $0 ${@:2}
        ;;

    -*)
        echo "sp: warning: unrecognized flag $1"
        exec $0 ${@:2}
        ;;
esac

if [ $vendored ]; then
    if [ -z "$2" ]; then
        echo "$0: error: --vendor should be used with a single package argument"
        exit 2
    fi

    tag="$1-vendored-$(date +'%Y%m%d')"
    installdir="${install}/${tag}"
    recursive=1 $0 $1 || exit $?
    tar -C ${installdir} -cJf ${packages}/${tag}.sp.tar.xz .
    exit 0
fi

if [ ! -z "$2" ]; then
    for package in "$@"; do
        $0 ${package}
    done
fi

[ ! $jobs ] && jobs=$(nproc)
[ $max_jobs ] && [ $jobs -gt $max_jobs ] && jobs=${max_jobs}

name="$1"

source "recipes/${name}.sh"

if [ ! ${bootstrap} ] && [ ! -z "${builddeps}" ]; then
    $SP_ROOT/install.sh ${builddeps} || exit $?
fi

tag="${name}-${version}"
srcdir="${sources}/${tag}"
builddir="${build}/${tag}"
[ -z "${installdir}" ] && installdir="${install}/${tag}" || custom_install=1

logdir="${logs}/${tag}"
mkdir -p ${logdir}
[ -z "${stdout}" ] && stdout="/dev/null"

if [ -d ${srcdir} ]; then
    echo "Removing existing source directory ${srcdir} ..."
    rm -rf ${srcdir}
fi
echo "Downloading source package from ${srcurl} ..."
getsrc || exit $?

if [ -d ${builddir} ]; then
    echo "Removing existing build directory ${builddir} ..."
    rm -rf ${builddir}
fi
mkdir -p ${builddir}
cd ${builddir}
echo "Configuring ${tag} ..."
configure 2>&1 | tee ${logdir}/configure.log >${stdout} || exit $?
echo "Building ${tag} ..." 
build 2>&1 | tee ${logdir}/build.log >${stdout} || exit $?

if [ ! $custom_install ] && [ -d ${installdir} ]; then
    echo "Removing existing install directory ${installdir} ..."
    rm -rf ${installdir}
fi
mkdir -p ${installdir}
echo "Installing ${tag} into ${installdir}"
install 2>&1 | tee ${logdir}/install.log >${stdout} || exit $?

if [ ! $custom_install ]; then
    pkgfile="${packages}/${tag}.sp.tar.xz"
    echo "Packaging ${pkgfile} ..."
    tar -C ${installdir} -cJf ${pkgfile} .
fi