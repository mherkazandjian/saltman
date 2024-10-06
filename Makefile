SHELL := /bin/bash
ROOT := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
WORKSPACE_DIR := $(shell grep -E '^\s*workdir\s*:' examples/clouddev01/conf.yml | awk -F':' '{gsub(/^[ \t]+|[ \t]+$$/, "", $$2); print $$2}')

include ${WORKSPACE_DIR}/env.sh
ANSIBLE_FLAGS = -i ${INVENTORY} --ssh-extra-args '-F ${SSH_CONFIG}'

.PHONY: nothing
nothing:

ifeq ($(debug),true)
    DEBUG_OPTS = -s --pdb
endif


docker-compose-build:
	docker compose --env-file examples/clouddev01/docker-compose-dot-env -f docker/docker-compose.yml build

#bootstrap:
#	pip install -r requirements.txt

docker-clean-containers:
	cd docker && docker-compose down -v || true
	docker rm \
		docker-saltman-minion01-1 \
		docker-saltman-master-1 \
	|| true

docker-clean-volumes:
	docker volume rm \
		docker_saltman_master \
		docker_saltman_minion01 \
	|| true

docker-full-clean: docker-clean-containers docker-clean-volumes
	cd docker && docker compose rm -fsv || true

docker-clean-images:
	docker rmi \
		saltman-minion01 \
		saltman-master \
	|| true

docker-deep-clean: docker-clean-containers docker-clean-images docker-clean-volume

docker-down:
	cd docker && docker-compose down


create_admin_ssh_key:
	ssh-keygen -t ed25519 -C 'admin key' -f ${WORKSPACE_DIR}/id_ed25519 -b 2048 -P '' -q

provision: docker-compose-build
	ADMIN_SSH_PUBLIC_KEY=`cat ${WORKSPACE_DIR}/id_ed25519.pub` \
		docker compose --env-file examples/clouddev01/docker-compose-dot-env -f docker/docker-compose.yml up

ping:
	@ansible ${ANSIBLE_FLAGS} all -o -m ansible.builtin.ping

ssh:
	ssh -F ${SSH_CONFIG} -t ${GATEWAYHOST}




docker-up:

	sleep 3
	docker exec -it docker-saltman-master-1 sed -i.bak 's/\#master\:\ salt/master\:\ master/g' /etc/salt/minion
	docker exec -it docker-saltman-minion01-1 sed -i.bak 's/\#master\:\ salt/master\:\ master/g' /etc/salt/minion
	docker exec -it docker-saltman-master-1 systemctl start salt-master
	docker exec -it docker-saltman-master-1 systemctl start salt-minion
	docker exec -it docker-saltman-minion01-1 systemctl start salt-minion
	sleep 3
	docker exec -it docker-saltman-master-1 salt-key -A -y
	sleep 10
	docker exec -it docker-saltman-master-1 salt '*' test.ping

salt-master:
	docker exec -it docker-saltman-master-1 bash

clean:
	@rm -fvr \
		\#* \
		*~ \
		*.exe \
		out \
		build \
		*.egg-info
	@find . -name "*__pycache__*" | xargs rm -fvr
	@find . -name "*.pyc*" | xargs rm -fvr
	@find . -name "*.pyo*" | xargs rm -fvr

help:
	@echo docker-build:
	@echo docker-clean-containers:
	@echo docker-clean-images:
	@echo docker-clean-volumes:
	@echo docker-deep-clean: docker-clean-containers docker-clean-images docker-clean-volume
	@echo docker-down:
	@echo docker-up:
	@echo salt-master:
