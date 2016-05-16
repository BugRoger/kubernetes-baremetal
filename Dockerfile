FROM quay.io/coreos/bootcfg:4ac6d07509cf6a46eaa42bf72dd6194085e009cd

RUN apk add --update bash curl gnupg && rm -rf /var/cache/apk/*

COPY scripts/ /usr/local/bin
RUN get-coreos stable 899.17.0
RUN get-kubernetes v1.2.4

COPY assets/     /assets/
COPY cloud/      /data/cloud
COPY ignition/   /data/ignition
COPY specs/      /data/specs
COPY config.yaml /data/config.yaml
