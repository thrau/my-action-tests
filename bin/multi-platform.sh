#!/bin/bash

set -e

function platform() {
	case `uname` in
		("Linux") echo "linux" ;;
		("*_NT*") echo "win32" ;; # works for github actions runners
		("Darwin") echo "darwin" ;;
		(*) echo "unknown" ;;
	esac
}

repo_url=https://github.com/localstack/localstack-packaged-cli
src_dir=python_packages/localstack-packaged-cli
vendor_dir=vendor/$(platform)/localstack-packaged-cli

mkdir -p ${src_dir}
mkdir -p ${vendor_dir}

test -d ${src_dir}/.git || git clone ${repo_url} ${src_dir}
(
	cd ${src_dir}
	make build
)
cp -r ${src_dir}/dist/localstack ${vendor_dir}

ls ${vendor_dir}/localstack
