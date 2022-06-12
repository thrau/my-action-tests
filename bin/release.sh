#!/bin/bash

set -e

VERSION_FILE=${VERSION_FILE-*/__init__.py}
DEPENDENCY_FILE=${DEPENDENCY_FILE-setup.cfg}
RELEASE_ENV_FILE=${RELEASE_ENV_FILE-.release.env}

function usage() {
    echo "A set of commands that facilitate release automation"
    echo ""
    echo "USAGE"
    echo "  release <command> [<patch|minor|major>]"
    echo ""
    echo "Commands:"
    echo "  github-outputs  print version number outputs for github actions"
    echo "  save-env        computes release versions and saves them into ${RELEASE_ENV_FILE}"
    echo "  explain-steps   print a list of steps that will be executed"
    echo "  perform         performs the release"
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
            release_ver=$(get_current_version | remove_ver_suffix)
            ;;
        "minor")
            release_ver=$(get_current_version | remove_ver_suffix)
            ;;
        "major")
            release_ver=$(get_current_version | increment_major)
            ;;
        *)
            echo "unknown release type '$1'"
            exit 1
            ;;
    esac

    develop_ver=$(echo ${release_ver} | increment_patch | add_dev_suffix)
    boundary_ver=$(echo ${develop_ver} | increment_patch)

    export CURRENT_VER=$(get_current_version)
    export RELEASE_VER=${release_ver}
    export DEVELOP_VER=${develop_ver}
    export BOUNDARY_VER=${boundary_ver}

    echo ${CURRENT_VER} | verify_valid_version
    echo ${RELEASE_VER} | verify_valid_version
    echo ${DEVELOP_VER} | verify_valid_version
    echo ${BOUNDARY_VER} | verify_valid_version
}

function release_env_load() {
    if [ -f ${RELEASE_ENV_FILE} ]; then
        release_env_read
    else
        release_env_compute $1
    fi
}

function release_env_read() {
    [[ -f ${RELEASE_ENV_FILE} ]] || { echo "no release file ${RELEASE_ENV_FILE}"; exit 1; }
    source ${RELEASE_ENV_FILE}
}

function release_env_save() {
    tee ${RELEASE_ENV_FILE} <<EOF
CURRENT_VER=${CURRENT_VER}
RELEASE_VER=${RELEASE_VER}
DEVELOP_VER=${DEVELOP_VER}
BOUNDARY_VER=${BOUNDARY_VER}
EOF
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
    echo "  - git push"
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

function print_env_exports() {
    echo "export CURRENT_VER=${CURRENT_VER}"
    echo "export RELEASE_VER=${RELEASE_VER}"
    echo "export DEVELOP_VER=${DEVELOP_VER}"
    echo "export BOUNDARY_VER=${BOUNDARY_VER}"
}

function set_version() {
    echo $1 | verify_valid_version
    sed -i -r "s/^__version__ = \"(.*)\"/__version__ = \"${1}\"/" ${VERSION_FILE}
}

function set_dependencies() {
    echo $1 | verify_valid_version
    sed -i -r "s/^__version__ = \"(.*)\"/__version__ = \"${1}\"/" ${VERSION_FILE}
}

function perform() {
    # update version number
    set_version ${RELEASE_VER}

    # git add ${VERSION_FILE} ${DEPENDENCY_FILE}
    # git commit -m "Release version ${RELEASE_VER}"
    # make dist
    # git tag -a "v${RELEASE_VER}" -m "Release version ${RELEASE_VER}"
    # # git push

}

function main() {
    [[ $# -lt 1 ]] && { usage; exit 1; }

    cmd=$1
    shift

    [[ $cmd == "help" ]] && { usage; exit 0; }

    release_env_load $1
    release_env_validate

    case $cmd in
        "help")             usage ;;
        "github-outputs")   print_github_outputs ;;
        "explain-steps")    explain_release_steps ;;
        "save-env")         release_env_save ;;
        "perform")          perform ;;
        *)                  usage && exit 1 ;;
    esac
}

main "$@"
