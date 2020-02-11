#!/bin/bash

fail() {
    if [[ $1 == 130 ]]; then
        echo "Interrupted by the user; exiting."
    else
        echo "sp has encountered a fatal error (subcommand exit status $1)."
        echo "Please see the files in ${logdir} for more information."
    fi
    exit $1
}

sources="$SPM_TREE/sources"
build="$SPM_TREE/build"
install="$SPM_TREE/install"
packages="$SPM_TREE/packages"
logs="$SPM_TREE/logs"

mkdir -p $sources $build $install $packages

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

    # Always build even if target already exists
    -f|--force|--rebuild)
        rebuild=1 exec $0 ${@:2}
        ;;
    
    # Assume build dependencies are already installed
    --ignore-builddeps)
        ignore_builddeps=1 exec $0 ${@:2}
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
        stdout="/dev/stdout" exec $0 ${@:2}
        ;;

    # Download source even if it already exists locally
    --redownload)
        redownload=1 exec $0 ${@:2}
        ;;

    -*)
        echo "sp: warning: unrecognized flag $1"
        exec $0 ${@:2}
        ;;
esac

[ ! $jobs ] && jobs=$(nproc)
[ $max_jobs ] && [ $jobs -gt $max_jobs ] && jobs=$max_jobs

do_build() (
    name="$1"

    source "$SPM_TREE/recipes/${name}.sh"
    tag="${name}-${version}"

    if [ -f "${packages}/${tag}.spm.*" ] && [ ! $rebuild ]; then
        echo "Package ${tag} already built, skipping ..."
    fi

    if [ ! $ignore_builddeps ] && [ ! -z "$builddeps" ]; then
        $SPM_ROOT/install.sh $builddeps || exit $?
    fi

    srcdir="${sources}/${tag}"
    builddir="${build}/${tag}"
    [ -z "${installdir}" ] && installdir="${install}/${tag}" || custom_install=1

    logdir="${logs}/${tag}"
    mkdir -p ${logdir}
    [ -z "${stdout}" ] && stdout="/dev/null"

    srcpkg="${sources}/$(basename ${srcurl})"

    if [ -f ${srcpkg} ] && [ $redownload ]; then
        echo "Removing existing source package ${srcpkg} ..."
        rm ${srcpkg}
    fi

    if [ -d ${srcdir} ]; then
        echo "Removing existing source directory ${srcdir} ..."
        rm -rf ${srcdir}
    fi
    if [[ $(type -t getsrc) == "function" ]]; then
        echo "Downloading source from ${srcurl} ..."
        getsrc || fail $?
    else
        if [ ! -f ${srcpkg} ]; then
            echo "Downloading source package from ${srcurl} ..."
            wget -q --show-progress ${srcurl} -P ${sources} || fail $?
        fi
        echo "Extracting ${srcpkg} ..."
        tar -C ${sources} -xaf ${srcpkg}
    fi

    if [ -d ${builddir} ]; then
        echo "Removing existing build directory ${builddir} ..."
        rm -rf ${builddir}
    fi
    mkdir -p ${builddir}
    cd ${builddir}
    echo "Configuring ${tag} ..."
    configure 2>&1 | tee ${logdir}/configure.log >${stdout} || fail $?
    echo "Building ${tag} ..." 
    build 2>&1 | tee ${logdir}/build.log >${stdout} || fail $?

    if [ ! ${custom_install} ] && [ -d ${installdir} ]; then
        echo "Removing existing install directory ${installdir} ..."
        rm -rf ${installdir}
    fi
    mkdir -p ${installdir}
    echo "Installing ${tag} into ${installdir}"
    install 2>&1 | tee ${logdir}/install.log >${stdout} || fail $?

    if [ ! ${custom_install} ]; then
        pkgfile="${packages}/${tag}.spm.tar.xz"
        echo "Packaging $pkgfile ..."
        tar -C $installdir \
            --owner=root \
            --group=root \
            --numeric-owner \
            --xattrs-include='*.*'
            -cJpf $pkgfile .
    else
        touch "${tag}.spm.stub"
    fi

    echo "Final build directory size: $(du -s -BK ${builddir} | grep -o '^[0-9]*') KiB"
    echo "Final install directory size: $(du -s -BK ${installdir} | grep -o '^[0-9]*') KiB"
    [ ! -z "${pkgfile}" ] \
        && echo "Compressed package size: $(du -s -BK ${pkgfile} | grep -o '^[0-9]*') KiB"

    echo "Removing temporary directories ..."
    rm -rf ${srcdir} ${builddir} ${installdir}
)

if [ ${recursive} ]; then
    source "$SPM_ROOT/lib/dependencies.sh"
    all_packages=$(collect_deps "$@")
else
    all_packages="$@"
fi

echo "Going to build: $all_packages"
echo -n "Is this okay? [Y/n] "
read -n 1 okay
if [[ $okay == "n" ]]; then
    echo -e "\nUser refused permission; aborting."
    exit 1
fi

for pkg in $all_packages; do
    do_build $pkg
done
