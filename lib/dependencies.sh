#!/bin/bash

collect_deps() {
    for pkg in "$@"; do
        if ! echo $alldeps | grep -oF "$pkg" > /dev/null; then
            if source "$SPM_TREE/recipes/${pkg}.sh"; then
                alldeps="$alldeps $pkg"
                echo $pkg
                collect_deps $dependencies
            fi
        fi
    done
}