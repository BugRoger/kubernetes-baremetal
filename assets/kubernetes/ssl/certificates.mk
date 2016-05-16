REQUIRED_ENV := ENV_KUBERNETES_DNS_DOMAIN ENV_NETWORK_SUBNET_SERVICES \
								ENV_NETWORK_SUBNET_INTERNAL ENV_NETWORK_SUBNET_EXTERNAL

KUBERNETES_SERVICE_ADDRESS  ?= $(shell echo $(NETWORK_SUBNET_SERVICES) | cut -d . -f -3).1
KUBERNETES_INTERNAL_ADDRESS ?= $(shell echo $(NETWORK_SUBNET_INTERNAL) | cut -d . -f -3).16
KUBERNETES_EXTERNAL_ADDRESS ?= $(shell echo $(NETWORK_SUBNET_EXTERNAL) | cut -d . -f -3).1
KUBERNETES_MASTER_ADDRESSES ?= $(patsubst %,$(shell echo $(NETWORK_SUBNET_INTERNAL) | cut -d . -f -3).%, $(shell seq 17 19))
KUBERNETES_NODE_ADDRESSES   ?= $(patsubst %,$(shell echo $(NETWORK_SUBNET_INTERNAL) | cut -d . -f -3).%, $(shell seq 17 32))
KEYPAIRS                    ?= controller-manager scheduler proxy \
																$(patsubst %,apiserver-%,$(KUBERNETES_MASTER_ADDRESSES)) \
																$(patsubst %,kubelet-%,$(KUBERNETES_NODE_ADDRESSES))

define OPENSSL_CONF 
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
endef


.PHONY: all 
all: $(REQUIRED_ENV) ca.pem ca-key.pem $(KEYPAIRS:=.pem) $(KEYPAIRS:=-key.pem) 

%.pem:           EXPIRY=-days 365 

%.csr:           SUBJECT=-subj "/CN=$*/O=ConvergedCloud/OU=$(KUBERNETES_DNS_DOMAIN)" 
ca.pem:          SUBJECT=-subj "/CN=$(KUBERNETES_DNS_DOMAIN)/O=ConvergedCloud/OU=$(KUBERNETES_DNS_DOMAIN)"
kubelet-%.csr:   SUBJECT=-subj "/CN=kubelet/O=ConvergedCloud/OU=$(KUBERNETES_DNS_DOMAIN)"
apiserver-%.csr: SUBJECT=-subj "/CN=apiserver/O=ConvergedCloud/OU=$(KUBERNETES_DNS_DOMAIN)"

apiserver-%.csr: CONFIG=-config $*.cfg
kubelet-%.csr:   CONFIG=-config $*.cfg

apiserver-%.pem: EXTENSIONS=-extensions v3_req -extfile $*.cfg
kubelet-%.pem:   EXTENSIONS=-extensions v3_req -extfile $*.cfg 

apiserver-%.cfg: export SANS=IP.1=$(patsubst apiserver-%,%,$*) \
									         	 IP.2=$(KUBERNETES_SERVICE_ADDRESS) \
														 IP.3=$(KUBERNETES_INTERNAL_ADDRESS) \
														 IP.4=$(KUBERNETES_EXTERNAL_ADDRESS) \
												 	   DNS.1=kubernetes \
													 	 DNS.2=kubernetes.default \
													   DNS.3=kubernetes.default.svc \
													   DNS.4=kubernetes.default.$(KUBERNETES_DNS_DOMAIN) \
													   DNS.5=kubernetes.default.svc.$(KUBERNETES_DNS_DOMAIN) \
													   DNS.6=$(KUBERNETES_EXTERNAL_DNS_NAME)
kubelet-%.cfg: export SANS=IP.1=$(patsubst kubelet-%,%,$*)

%-key.pem:
	openssl genrsa -out $@ 2048

%.csr: %-key.pem %.cfg 
	openssl req -new -key $< -out $@ $(SUBJECT) $(CONFIG) 

ca.pem: ca-key.pem 
	openssl req -x509 -sha256 -new -nodes -key $< -out $@ $(EXPIRY) $(SUBJECT)

%.pem: %.csr %.cfg ca-key.pem ca.pem  
	openssl x509 -req -sha256 -CA ca.pem -CAkey ca-key.pem -CAcreateserial -in $*.csr -out $*.pem $(EXPIRY) $(EXTENSIONS)

%.cfg: export _OPENSSL_CONF=$(OPENSSL_CONF)
%.cfg: export _SANS=$(SANS)
%.cfg: 
	@echo "$$_OPENSSL_CONF" > $@
	@echo "$$_SANS" | tr " " "\n" >> $@

.PHONY: $(REQUIRED_ENV)  
$(REQUIRED_ENV): ENV_%:
	@ if [ "${${*}}" == "" ]; then \
		echo "$* must be set"; \
		exit 1; \
	fi

.PHONY: 
clean: 	
	$(RM) $(KEYPAIRS:=.pem) $(KEYPAIRS:=-key.pem) 
	$(RM) *.csr
	$(RM) *.cfg
