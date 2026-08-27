IMAGE_NAME := "zachomedia/cert-manager-webhook-pdns"
IMAGE_TAG := "latest"

CONTAINER_ENGINE ?= $(shell command -v docker 2>/dev/null || command -v podman 2>/dev/null)
ifeq ($(CONTAINER_ENGINE),)
$(error Neither podman nor docker was found in PATH)
endif
ENGINE_NAME := $(notdir $(CONTAINER_ENGINE))

OUT := $(shell pwd)/_out

$(shell mkdir -p "$(OUT)")

info:
	@echo "Using container engine: $(ENGINE_NAME) ($(CONTAINER_ENGINE))"

setup:
	./scripts/fetch-test-binaries.sh
	./scripts/setup-tests.sh
	$(CONTAINER_ENGINE) compose -f docker-compose.test.yaml up --build -d

clean:
	rm -rf _out/
	$(CONTAINER_ENGINE) compose -f docker-compose.test.yaml down -v
	go clean
	go clean -testcache

verify:
	TEST_ASSET_ETCD=_out/controller-tools/envtest/etcd TEST_ASSET_KUBE_APISERVER=_out/controller-tools/envtest/kube-apiserver TEST_ASSET_KUBECTL=_out/controller-tools/envtest/kubectl TEST_DNS_SERVER="127.0.0.1:53" TEST_ZONE_NAME=example.ca. HTTP_PROXY="127.0.0.1:3128" HTTPS_PROXY="127.0.0.1:3128" NO_PROXY="proxy.golang.org" go test -v -run "TestIsAllowedZones"
	TEST_ASSET_ETCD=_out/controller-tools/envtest/etcd TEST_ASSET_KUBE_APISERVER=_out/controller-tools/envtest/kube-apiserver TEST_ASSET_KUBECTL=_out/controller-tools/envtest/kubectl TEST_DNS_SERVER="127.0.0.1:53" TEST_ZONE_NAME=example.ca. go test -v -run "^TestNoProxy.*"
	TEST_ASSET_ETCD=_out/controller-tools/envtest/etcd TEST_ASSET_KUBE_APISERVER=_out/controller-tools/envtest/kube-apiserver TEST_ASSET_KUBECTL=_out/controller-tools/envtest/kubectl TEST_DNS_SERVER="127.0.0.1:53" TEST_ZONE_NAME=example.ca. HTTP_PROXY="127.0.0.1:3128" HTTPS_PROXY="127.0.0.1:3128" NO_PROXY="proxy.golang.org" go test -v -run "^TestProxy.*"
	TEST_ASSET_ETCD=_out/controller-tools/envtest/etcd TEST_ASSET_KUBE_APISERVER=_out/controller-tools/envtest/kube-apiserver TEST_ASSET_KUBECTL=_out/controller-tools/envtest/kubectl TEST_DNS_SERVER="127.0.0.1:53" TEST_ZONE_NAME=example.ca. HTTP_PROXY="127.0.0.1:3128" HTTPS_PROXY="127.0.0.1:3128" NO_PROXY="proxy.golang.org" go test -v -run "^TestProxy.*"

test: verify

build:
	docker build -t "$(IMAGE_NAME):$(IMAGE_TAG)" .

rendered-manifest.yaml:
	helm template \
        --set image.repository=$(IMAGE_NAME) \
        --set image.tag=$(IMAGE_TAG) \
	      cert-manager-webhook-pdns \
        deploy/cert-manager-webhook-pdns > "$(OUT)/rendered-manifest.yaml"

.PHONY: rendered-manifest.yaml build verify test setup clean
