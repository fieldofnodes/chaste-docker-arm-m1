help:
	@cat Makefile

CHASTE_IMAGE?=fieldofnodes/chaste-docker-arm-m1
BASE?=focal
TAG?=2021.1
GIT_TAG?="${TAG}"
# GIT_TAG?=$(git describe --abbrev=0)
CHASTE_DIR?="/home/chaste"
DOCKER_FILE?=Dockerfile
CHASTE_DATA_VOLUME?=chaste_data
CMAKE_BUILD_TYPE?="Release"
Chaste_ERROR_ON_WARNING?="OFF"
Chaste_UPDATE_PROVENANCE?="OFF"
# PROJECTS?="${HOME}/projects"
# TEST_OUTPUT?="${HOME}/testoutput"
TEST_SUITE?="Continuous"
# SRC?=$(shell dirname `pwd`)

all: base release

.PHONY: all build base release fresh latest master develop clean stats pull push run test info verbose

# BUILD_ARGS := --build-arg BASE=$(BASE)
# IMAGE_NAMES := -t $(CHASTE_IMAGE):$(TAG)
# base release: TARGET = $@
# release: BUILD_ARGS += --build-arg CHASTE_DIR=$(CHASTE_DIR) --build-arg TAG=$(GIT_TAG)
# release: IMAGE_NAMES += -t $(CHASTE_IMAGE):$(BASE)-$(TAG)
# base: BUILD_ARGS += --target $@
# base: CHASTE_IMAGE = chaste/base
# base: IMAGE_NAMES = $(CHASTE_IMAGE):$(BASE)
# base release: build
# 	for NAME in $(IMAGE_NAMES) ; do \
# 		push $$(NAME) ; \
# 	done
# build:
# 	docker build $(BUILD_ARGS) $(IMAGE_NAMES) -f $(DOCKER_FILE) .
# 	# docker push $(IMAGE_NAMES)

TARGET?=
#stub: TARGET = --target base
# Do not declare volume for base (or stub - deprecated) so that subsequent layers may modify the contents of /home/chaste
# NOTE: When a container is started which creates a new volume, the contents of the mount point is copied to the volume
base stub: TARGET = --target base
base stub:
	docker buildx build --platform linux/amd64 \
				-t chaste/$@:$(BASE) \
				--build-arg BASE=$(BASE) \
				--build-arg CHASTE_DIR=$(CHASTE_DIR) \
				$(TARGET) \
				-f $(DOCKER_FILE) .
	docker push chaste/$@:$(BASE)


	 

EXTRA_ARGS?=
build:
	docker buildx build --platform linux/amd64 \
				 -t $(CHASTE_IMAGE):$(TAG) \
				 -t $(CHASTE_IMAGE):$(BASE)-$(TAG) \
				 --build-arg BASE=$(BASE) \
				 --build-arg CHASTE_DIR=$(CHASTE_DIR) \
				 --build-arg TAG=$(GIT_TAG) \
				 --build-arg CMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE) \
				 --build-arg Chaste_ERROR_ON_WARNING=$(Chaste_ERROR_ON_WARNING) \
				 --build-arg Chaste_UPDATE_PROVENANCE=$(Chaste_UPDATE_PROVENANCE) \
				 -f $(DOCKER_FILE) $(EXTRA_ARGS) .

fresh latest: EXTRA_ARGS += --no-cache
latest: GIT_TAG=master
fresh latest: build

#develop: CHASTE_IMAGE=chaste/develop
#	docker build -t $(CHASTE_IMAGE):$@ \

master develop: CMAKE_BUILD_TYPE="Debug" Chaste_ERROR_ON_WARNING="ON" Chaste_UPDATE_PROVENANCE="OFF"
master develop:
	docker buildx build --platform linux/amd64 \
	  			 -t chaste/$@ \
				 --build-arg BASE=$(BASE) \
				 --build-arg CHASTE_DIR=$(CHASTE_DIR) \
				 --build-arg TAG=$@ \
                                 --build-arg CMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE) \
                                 --build-arg Chaste_ERROR_ON_WARNING=$(Chaste_ERROR_ON_WARNING) \
                                 --build-arg Chaste_UPDATE_PROVENANCE=$(Chaste_UPDATE_PROVENANCE) \
				 -f $(DOCKER_FILE) .

clean:
	docker system prune

stats:
	docker stats

pull:
	docker pull $(CHASTE_IMAGE):$(TAG)

push:
	docker push $(CHASTE_IMAGE):$(TAG)
	docker push $(CHASTE_IMAGE):$(BASE)-$(TAG)

MOUNTS = -v $(CHASTE_DATA_VOLUME):$(CHASTE_DIR)
ifdef PROJECTS
MOUNTS += -v $(PROJECTS):$(CHASTE_DIR)/projects
endif
ifdef TEST_OUTPUT
MOUNTS += -v $(TEST_OUTPUT):$(CHASTE_DIR)/testoutput
endif

run: build
	docker run -it --init --rm $(MOUNTS) $(CHASTE_IMAGE):$(TAG)

test: build
	docker run -it --init --rm --env CMAKE_BUILD_TYPE=Debug \
				$(CHASTE_IMAGE):$(TAG) test.sh $(TEST_SUITE)

release: CHASTE_IMAGE=chaste/release
release: build test push

build-info: TEST_SUITE=TestChasteBuildInfo
build-info: test

info:
	@echo "Mounts: $(MOUNTS)"
	lsb_release -a
	docker -v

verbose: info
	docker system info
