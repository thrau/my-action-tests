.PHONY: docker-build-base

docker-build-base:
	docker build --squash -t tests/myimage:latest -f bin/Dockerfile.base
