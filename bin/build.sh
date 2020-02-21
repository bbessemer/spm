#!/bin/bash -e

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
stage="$SPM_TREE/stage"
packages="$SPM_TREE/packages"
logs="$SPM_TREE/logs"

mkdir -p $sources $build $stage $packages

case $1 in
    # Build dependencies as well
    -r|--recursive)
        recursive=1 exec $0 ${@:2}
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
        jobs=$(echo $1 | cut -d '=' -f 2-) exec $0 ${@:2}
        ;;

    # Maximum number of parallel jobs (use only if < nCPUs)
    -J|--max-jobs)
        max_jobs="$2" exec $0 ${@:3}
        ;;
    --max-jobs=*)
        max_jobs=$(echo $1 | cut -d '=' -f 2-) exec $0 ${@:2}
        ;;

    # Print output of subcommands to stdout
    -v|--verbose)
        stdout="/dev/stdout" exec $0 ${@:2}
        ;;

    # Download source even if it already exists locally
    --redownload)
        redownload=1 exec $0 ${@:2}
        ;;

    # Don't prompt the user for confirmation
    -y|--yes|--noninteractive)
        noninteractive=1 exec $0 ${@:2}
        ;;

    -*)
        passthru_flags="$passthru_flags $1" exec $0 ${@:2}
        ;;
esac

[ ! $jobs ] && jobs=$(nproc)
[ $max_jobs ] && [ $jobs -gt $max_jobs ] && jobs=$max_jobs

do_build() (
    set -e

    name="$1"

    source "$SPM_TREE/recipes/${name}.sh"
    tag="${name}-${version}"

    if [ -f "${packages}/${tag}.spm.*" ] && [ ! $rebuild ]; then
        echo "Package ${tag} already built, skipping ..."
    fi

    if [ ! $ignore_builddeps ] && [ ! -z "$builddeps" ]; then
        $SPM_ROOT/bin/install.sh $builddeps
    fi

    srcdir="${sources}/${tag}"
    builddir="${build}/${tag}"
    [ -z "${stagedir}" ] && stagedir="${stage}/${tag}" || custom_stage=1

    logdir="${logs}/${tag}"
    mkdir -p ${logdir}
    [ -z "${stdout}" ] && stdout="/dev/null"

    if [ -d ${srcdir} ]; then
        echo "Removing existing source directory ${srcdir} ..."
        rm -rf ${srcdir}
    fi
    if [[ $(type -t getsrc) == "function" ]]; then
        echo "Downloading source from ${srcurl} ..."
        getsrc
    elif [ ! -z "${srcurl}" ]; then
        srcpkg="${sources}/$(basename ${srcurl})"

        if [ -f ${srcpkg} ] && [ $redownload ]; then
            echo "Removing existing source package ${srcpkg} ..."
            rm ${srcpkg}
        fi
        if [ ! -f ${srcpkg} ]; then
            echo "Downloading source package from ${srcurl} ..."
            wget -q --show-progress ${srcurl} -P ${sources}
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
    configure 2>&1 | tee ${logdir}/configure.log >${stdout}
    echo "Building ${tag} ..." 
    build 2>&1 | tee ${logdir}/build.log >${stdout}

    if [ -d ${stagedir} ]; then
        echo "Removing existing stage directory ${stagedir} ..."
        rm -rf ${stagedir}
    fi
    mkdir -p ${stagedir}
    echo "Staging ${tag} into ${stagedir}"
    stage 2>&1 | tee ${logdir}/stage.log >${stdout}

    pkgfile="${packages}/${tag}.spm.tar.xz"
    echo "Packaging $pkgfile ..."
    tar -C $stagedir \
        --owner=root \
        --group=root \
        --numeric-owner \
        -cJpf $pkgfile .

    echo "Final build directory size: $(du -s -BK ${builddir} | grep -o '^[0-9]*') KiB"
    echo "Final stage directory size: $(du -s -BK ${stagedir} | grep -o '^[0-9]*') KiB"
    [ ! -z "${pkgfile}" ] \
        && echo "Compressed package size: $(du -s -BK ${pkgfile} | grep -o '^[0-9]*') KiB"

    echo "Removing temporary directories ..."
    rm -rf ${srcdir} ${builddir} ${stagedir}
)

if [ ${recursive} ]; then
    source "$SPM_ROOT/lib/dependencies.sh"
    all_packages=$(collect_deps "$@")
else
    all_packages="$@"
fi

echo "Going to build: $all_packages"
while [ ! $noninteractive ]; do
echo -n "Is this okay? [y/N] "
    read -n 1 okay
    echo
    case $okay in
        n|N|"")
            echo "User refused permission; aborting."
            exit 1
            ;;
        y|Y)
            break
            ;;
        *)
            echo "Please enter 'y' or 'n'."
    esac
done

for pkg in $all_packages; do
    do_build $pkg || exit $?
done
