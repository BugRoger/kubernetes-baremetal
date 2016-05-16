SHELL       := /bin/sh
REPOSITORY  := bugroger/bootcfg
TAG         ?= latest
IMAGE       := $(REPOSITORY):$(TAG)

### Executables
DOCKER      = docker

# -------------------------
#  all
# -------------------------
.PHONY: all
all: ssl 

ssl: assets/kubernetes/ssl/Makefile assets/kubernetes/ssl/certificates.mk
	@$(MAKE) -C assets/kubernetes/ssl/

# ----------------------------------------------------------------------------------
#   image 
# ----------------------------------------------------------------------------------
image: build
	echo $(IMAGE) > image

# ----------------------------------------------------------------------------------
#   build 
# ----------------------------------------------------------------------------------
#
# Build and tags an image from a Dockerfile.
build: ssl
	$(DOCKER) pull $(REPOSITORY):build.latest || true
	$(DOCKER) build -f Dockerfile -t $(IMAGE) --rm . 
	echo $(IMAGE) > build

# ----------------------------------------------------------------------------------
#   clean 
# ----------------------------------------------------------------------------------
#
# Kill and remove all containers. Remove intermediate files. 
#
.PHONY: 
clean: 	
	$(RM) image build 
	@$(MAKE) -C assets/kubernetes/ssl clean
