#!/bin/bash

case $1 in
    # Build dependencies as well
    -R|--install-root)
        install_root="$2" exec $0 ${@:3}
        ;;
    --install-root=*)
        install_root=$(echo $1 | cut -d '=' -f 2-) exec $0 ${@:2}
        ;;

    # Print output of subcommands to stdout
    -v|--verbose)
        stdout="/dev/stdout" exec $0 ${@:2}
        ;;

    # Don't prompt the user for confirmation
    -y|--yes|--noninteractive)
        noninteractive=1 exec $0 ${@:2}
        ;;

    # Build from source even if a binary is available
    -s|--source)
        source=1 exec $0 ${@:2}
        ;;


    -*)
        passthru_flags="$passthru_flags $1" exec $0 ${@:2}
        ;;
esac

[ -z "$install_root" ] && install_root="/"

do_install() (
    name="$1"

    source "$SPM_ROOT/recipes/${name}.sh"
    tag="${name}-${version}"
    pkgfile="$SPM_ROOT/packages/${tag}.spm.tar.xz"

    if [ $source ]; then
        noninteractive=1 $SPM_ROOT/bin/build.sh $passthru_flags $name
    fi

    if [ ! -f $pkgfile ]; then
        if [ $binurl ]; then
            echo "Downloading binary package from $binurl ..."
            wget -q --show-progress $binurl -P $packages || fail $?
        else
            noninteractive=1 $SPM_ROOT/bin/build.sh $passthru_flags $name
        fi
    fi

    infodir="$SPM_DATA/$tag"
    fileslist_path="$infodir/files.list"

    echo "Installing ${tag} into ${install_root} ..."
    mkdir -p "${install_root}/${infodir}"
    fileslist=$(tar -C $install_root -xvJpf $pkgfile \
                --numeric-owner \
                --xattrs-include='*.*')
    true > "${install_root}/${fileslist_path}"
    for file in $fileslist; do
        if [ -f "${install_root}/${file}" ]; then
            echo $file | sed 's/^\.//' >> "${install_root}/${fileslist_path}"
        fi
    done
    echo $fileslist_path >> "${install_root}/${fileslist_path}"
    echo $(dirname $fileslist_path) >> "${install_root}/${fileslist_path}"

    echo "$tag" >> "${install_root}/$SPM_DATA/packages.list"
)

source "$SPM_ROOT/lib/dependencies.sh"
all_packages=$(collect_deps "$@")

echo "Going to install: $all_packages"
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
    do_install $pkg || exit $?
done