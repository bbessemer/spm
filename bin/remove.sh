#!/bin/bash

case $1 in
    # Use directory as install root instead of /
    -R|--install-root)
        install_root="$2" exec $0 ${@:3}
        ;;
    --install-root=*)
        install_root=$(echo $1 | cut -d '=' -f 2-) exec $0 ${@:2}
        ;;

    # Print output of subcommands to stdout
    -v|--verbose)
        rmflags="--verbose" exec $0 ${@:2}
        ;;

    # Don't prompt the user for confirmation
    -y|--yes|--noninteractive)
        noninteractive=1 exec $0 ${@:2}
        ;;

    -*)
        echo "spm: warning: unrecognized flag $1"
        exec $0 ${@:2}
        ;;
esac

[ -z "$install_root" ] && install_root="/"

do_remove() (
    name="$1"

    if ! tag=$(grep -hFm 1 "$name" $install_root/$SPM_DATA/packages.list); then
        echo "${name} is not installed; cannot remove."
        exit 1
    fi

    fileslist_path="$SPM_DATA/$tag/files.list"
    echo "Removing ${tag} from ${install_root} ..."
    for file in $(cat "${install_root}/${fileslist_path}"); do
        rm -d $rmflags "${install_root}/${file}"
    done
)

all_packages="$@"

echo "Going to remove: $all_packages"
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
    do_remove $pkg || exit $?
done