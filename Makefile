GPDB_6_VERSIONS = 6.27.1
TAG_GPDB_6 ?= 6.27.1
GPDB_7_VERSIONS = 7.1.0
TAG_GPDB_7 ?= 7.1.0
GREENGAGE_6_VERSIONS = 6.31.0
TAG_GREENGAGE_6 ?= 6.31.0
GREENGAGE_7_VERSIONS = 7.4.1
TAG_GREENGAGE_7 ?= 7.4.1
WAREHOUSEPG_6_VERSIONS = 6.27.5-WHPG
TAG_WAREHOUSEPG_6 ?= 6.27.5-WHPG
WAREHOUSEPG_7_VERSIONS = 7.4.1-WHPG
TAG_WAREHOUSEPG_7 ?= 7.4.1-WHPG
OPENGPDB_6_VERSIONS = 6.29.8
TAG_OPENGPDB_6 ?= 6.29.8
UBUNTU_OS_VERSION = ubuntu22.04
OL_OS_VERSION = oraclelinux8
UID := $(shell id -u)
GID := $(shell id -g)

all: $(GPDB_6_VERSIONS) $(GPDB_7_VERSIONS)

.PHONY: $(GPDB_6_VERSIONS)
$(GPDB_6_VERSIONS):
	$(call build_image,6,$@,$(UBUNTU_OS_VERSION))

.PHONY: $(GPDB_7_VERSIONS)
$(GPDB_7_VERSIONS):
	$(call build_image,7,$@,$(UBUNTU_OS_VERSION))

.PHONY: build_gpdb_6_ubuntu
build_gpdb_6_ubuntu:
	$(call build_image_with_tag,6,$(TAG_GPDB_6),$(UBUNTU_OS_VERSION))

.PHONY: build_gpdb_7_ubuntu
build_gpdb_7_ubuntu:
	$(call build_image_with_tag,7,$(TAG_GPDB_7),$(UBUNTU_OS_VERSION))

.PHONY: build_gpdb_6_oraclelinux
build_gpdb_6_oraclelinux:
	$(call build_image_with_tag,6,$(TAG_GPDB_6),$(OL_OS_VERSION))
	
.PHONY: build_gpdb_7_oraclelinux
build_gpdb_7_oraclelinux:
	$(call build_image_with_tag,7,$(TAG_GPDB_7),$(OL_OS_VERSION))

.PHONY: build_greengage_6_ubuntu
build_greengage_6_ubuntu:
	$(call build_greengage_image_with_tag,6,$(TAG_GREENGAGE_6),$(UBUNTU_OS_VERSION))

.PHONY: build_greengage_6_oraclelinux
build_greengage_6_oraclelinux:
	$(call build_greengage_image_with_tag,6,$(TAG_GREENGAGE_6),$(OL_OS_VERSION))

.PHONY: build_greengage_7_ubuntu
build_greengage_7_ubuntu:
	$(call build_greengage_image_with_tag,7,$(TAG_GREENGAGE_7),$(UBUNTU_OS_VERSION))

.PHONY: build_greengage_7_oraclelinux
build_greengage_7_oraclelinux:
	$(call build_greengage_image_with_tag,7,$(TAG_GREENGAGE_7),$(OL_OS_VERSION))

.PHONY: build_warehousepg_6_ubuntu
build_warehousepg_6_ubuntu:
	$(call build_warehousepg_image_with_tag,6,$(TAG_WAREHOUSEPG_6),$(UBUNTU_OS_VERSION))

.PHONY: build_warehousepg_6_oraclelinux
build_warehousepg_6_oraclelinux:
	$(call build_warehousepg_image_with_tag,6,$(TAG_WAREHOUSEPG_6),$(OL_OS_VERSION))

.PHONY: build_warehousepg_7_ubuntu
build_warehousepg_7_ubuntu:
	$(call build_warehousepg_image_with_tag,7,$(TAG_WAREHOUSEPG_7),$(UBUNTU_OS_VERSION))

.PHONY: build_warehousepg_7_oraclelinux
build_warehousepg_7_oraclelinux:
	$(call build_warehousepg_image_with_tag,7,$(TAG_WAREHOUSEPG_7),$(OL_OS_VERSION))

.PHONY: build_opengpdb_6_ubuntu
build_opengpdb_6_ubuntu:
	$(call build_opengpdb_image_with_tag,6,$(TAG_OPENGPDB_6),$(UBUNTU_OS_VERSION))

.PHONY: test-e2e
test-e2e:
	$(MAKE) -C e2e-tests test-e2e

.PHONY: test-e2e-walg
test-e2e-walg:
	$(MAKE) -C e2e-tests test-e2e-walg

.PHONY: test-e2e-standby-coordinator
test-e2e-standby-coordinator:
	$(MAKE) -C e2e-tests test-e2e-standby-coordinator

.PHONY: test-e2e-yezzey
test-e2e-yezzey:
	$(MAKE) -C e2e-tests test-e2e-yezzey

define build_image
	@echo "Build GPDB $(1):$(2) $(3) docker image"
	docker buildx build -f docker/greenplum/$(3)/$(1)/Dockerfile --build-arg GPDB_VERSION=$(2) -t greenplum:$(2) .
endef

define build_image_with_tag
	@echo "Build GPDB $(1):$(2) $(3) docker image"
	docker buildx build -f docker/greenplum/$(3)/$(1)/Dockerfile --build-arg GPDB_VERSION=$(2) -t greenplum:$(2)-$(3) .
endef

define build_greengage_image_with_tag
	@echo "Build Greengage $(1):$(2) $(3) docker image"
	docker buildx build -f docker/greengage/$(3)/$(1)/Dockerfile --build-arg GPDB_VERSION=$(2) -t greengage:$(2)-$(3) .
endef

define build_warehousepg_image_with_tag
	@echo "Build WarehousePG $(1):$(2) $(3) docker image"
	docker buildx build -f docker/warehousepg/$(3)/$(1)/Dockerfile --build-arg GPDB_VERSION=$(2) -t warehousepg:$(2)-$(3) .
endef

define build_opengpdb_image_with_tag
	@echo "Build OpenGPDB $(1):$(2) $(3) docker image"
	docker buildx build -f docker/opengpdb/$(3)/$(1)/Dockerfile --build-arg GPDB_VERSION=$(2) -t opengpdb:$(2)-$(3) .
endef
