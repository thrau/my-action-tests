#!/bin/bash

set -e

VERSION_FILE=${VERSION_FILE-*/__init__.py}
DEPENDENCY_FILE=${DEPENDENCY_FILE-setup.cfg}

function usage() {
    echo "A set of commands that facilitate release automation"
    echo ""
    echo "USAGE"
    echo "  release-helper <command> [<patch|minor|major>]"
    echo ""
    echo "Commands:"
    echo "  github-outputs  print version number outputs for github actions"
    echo "  explain-steps   print a list of steps that should be executed for the release type"
    echo "  help            show this message"
}

function get_current_version() {
    egrep "^__version__ = " ${VERSION_FILE} | sed -r 's/^__version__ = "(.*)"/\1/g'
}

function remove_ver_suffix() {
    awk -F. '{ print $1 "." $2 "." $3 }'
}

function increment_dev() {
    awk -F. -v time="$(date -u +%Y%m%d%H%M%S)" '{ print $1 "." $2 "." $3 ".dev" time }'
}

function add_dev_suffix() {
    awk -F. '{ print $1 "." $2 "." $3 ".dev" }'
}

function increment_patch() {
    awk -F. '{ print $1 "." $2 "." $3 + 1 }'
}

function increment_minor() {
    awk -F. '{ print $1 "." $2 + 1 "." 0 }'
}

function increment_major() {
    awk -F. '{ print $1 + 1 "." 0 "." 0 }'
}

function verify_valid_version() {
    read ver
    echo $ver | egrep "^([0-9]+)\.([0-9]+)\.([0-9]+)" > /dev/null || { echo "invalid version string '$ver'"; exit 1; }
}

function release_env_compute() {
    case $1 in
        "patch")
            RELEASE_VER=$(get_current_version | remove_ver_suffix)
            ;;
        "minor")
            RELEASE_VER=$(get_current_version | increment_minor)
            ;;
        "major")
            RELEASE_VER=$(get_current_version | increment_major)
            ;;
        *)
            echo "unknown release type '$1'"
            exit 1
            ;;
    esac

    export CURRENT_VER=$(get_current_version)
    export RELEASE_VER=${RELEASE_VER}
    export DEVELOP_VER=$(echo ${release_ver} | increment_patch | add_dev_suffix)
    export BOUNDARY_VER=$(echo ${develop_ver} | increment_patch)

    release_env_validate
}

function release_env_validate() {
    echo ${CURRENT_VER} | verify_valid_version
    echo ${RELEASE_VER} | verify_valid_version
    echo ${DEVELOP_VER} | verify_valid_version
    echo ${BOUNDARY_VER} | verify_valid_version
}

function explain_release_steps() {
    echo "- bump __version__: ${CURRENT_VER} -> ${RELEASE_VER}"
    echo "- set synced dependencies to ==${RELEASE_VER}"
    echo "- perform release"
    echo "  - git commit -a -m 'Release version ${RELEASE_VER}'"
    echo "  - make publish"
    echo "  - git tag -a 'v${RELEASE_VER}' -m 'Release version ${RELEASE_VER}'"
    echo "  - git push && git push --tags"
    echo "- bump __version__: ${RELEASE_VER} -> ${DEVELOP_VER}"
    echo "- set synced dependencies to >=${DEVELOP_VER},<${BOUNDARY_VER}"
    echo "- prepare development iteration"
    echo "  - git commit -a -m 'Prepare next development iteration'"
    echo "  - git push"
}

function print_github_outputs() {
    echo "::set-output name=current::${CURRENT_VER}"
    echo "::set-output name=release::${RELEASE_VER}"
    echo "::set-output name=develop::${DEVELOP_VER}"
    echo "::set-output name=boundary::${BOUNDARY_VER}"
}

function main() {
    [[ $# -lt 1 ]] && { usage; exit 1; }

    cmd=$1
    shift

    [[ $cmd == "help" ]] && { usage; exit 0; }

    release_env_compute $1
    release_env_validate

    case $cmd in
        "help")             usage ;;
        "github-outputs")   print_github_outputs ;;
        "explain-steps")    explain_release_steps ;;
        *)                  usage && exit 1 ;;
    esac
}

main "$@"
