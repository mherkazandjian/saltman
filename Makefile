SHELL := /bin/bash
ROOT := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

CURRENT_ENV_EXISTS := $(shell test -f .current_env && printf yes)

ifeq "$(origin infra)" "command line"
INFRA = ${infra}
endif

ifeq (${CURRENT_ENV_EXISTS},yes)
include .current_env
ifeq "$(origin infra)" "command line"
INFRA = ${infra}
endif
else
$(info )
$(info WARNING:)
$(info |    .current_env does not exist or points to a dead symlink)
$(info |    set an environemt by pointing to a certain environment file)
$(info )
$(info examples:)
$(info )
$(info |    - make set-current-env env=~/workspaces/cluster_minimal/env.sh)
$(info |    - make set-default-env env=~/workspaces/cluster_minimal/env.sh)
endif


#include ${WORKSPACE_DIR}/env.sh
ANSIBLE_FLAGS = -i ${INVENTORY} --ssh-extra-args '-F ${SSH_CONFIG}'

.PHONY: nothing
nothing:

set-default-env:
	@ln -sf ${env} .default_env

set-current-env:
	@ln -sf ${env} .current_env

set-current-env-as-default:
	@ln -sf .current_env .default_env

use-default-env-as-current:
	@ln -sf .default_env .current_env

env:
	@[[ -f .current_env ]] && echo current_env: || true
	@[[ -f .current_env ]] && ls -l .current_env || true
	@[[ -f .default_env ]] && echo default_env || true
	@[[ -f .default_env ]] && ls -l .default_env || true
	@echo "current environment"
	@echo "-------------------"
	@echo "env vars"
	@echo "    WORKSPACE=${WORKSPACE}"
	@echo "    INVENTORY=${INVENTORY}"
	@echo "    SSH_CONFIG=${SSH_CONFIG}"
	@echo "    GATEWAYHOST=${GATEWAYHOST}"
	@echo "    SALTMASTER=${SALTMASTER}"
	@echo "    INFRA=${INFRA}"
	@echo "make vars"
	@echo "    ANSIBLE_FLAGS=${ANSIBLE_FLAGS}"

list-envs:
	@for confpath in `find projects -type f -name conf.yml -not -path "*template*"`; do \
		envpathbase=$$(grep workdir $${confpath} | awk '{print $$2}'); \
		envpath=$${envpathbase/#\~/$$HOME}/env.sh; \
		if [ -f $${envpath} ]; then \
			echo "make set-current-env env="$${envpath}; \
			echo "     " `grep "short_description:" $${confpath}`; \
		fi; \
	done

################
bootstrap-project:
	echo "bootstrap-project"
	python src/bootstrap_project.py projects/${INFRA}/conf.yml

docker-compose-build:
	echo "docker-compose-build"
	docker compose \
		--env-file ${WORKSPACE}/docker_compose_dot_env \
		--project-directory ${PWD}/docker \
		-f ${WORKSPACE}/docker-compose.yml \
		build


provision: docker-compose-build
	ADMIN_SSH_PUBLIC_KEY=`cat ${WORKSPACE}/id_ed25519.pub` \
		docker compose \
			--env-file ${WORKSPACE}/docker_compose_dot_env \
			--project-directory ${PWD}/docker \
			-f ${WORKSPACE}/docker-compose.yml \
			up

docker-compose:
	ADMIN_SSH_PUBLIC_KEY=`cat ${WORKSPACE}/id_ed25519.pub` \
		docker compose \
			--env-file ${WORKSPACE}/docker_compose_dot_env \
			--project-directory ${PWD}/docker \
			-f ${WORKSPACE}/docker-compose.yml \
			${args}

suspend: docker-compose-build
	docker compose \
		--env-file ${WORKSPACE}/docker_compose_dot_env \
		--project-directory ${PWD}/docker \
		-f ${WORKSPACE}/docker-compose.yml \
		pause

resume: docker-compose-build
	docker compose \
		--env-file ${WORKSPACE}/docker_compose_dot_env \
		--project-directory ${PWD}/docker \
		-f ${WORKSPACE}/docker-compose.yml \
		unpause


################
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

################
playbook:
	ansible-playbook ${ANSIBLE_FLAGS} ${PLAYBOOK} ${TAGS}

bootstrap:
	ansible-playbook ${ANSIBLE_FLAGS} ansible/site.yml ${TAGS}

ping:
	@ansible ${ANSIBLE_FLAGS} all -o -m ansible.builtin.ping

cmd:
	ansible ${ANSIBLE_FLAGS} all -u admin -b -m ansible.builtin.shell -a "${CMD}"

################
ssh:
	ssh -F ${SSH_CONFIG} -t ${GATEWAYHOST}

salt-master:
	docker exec -it docker-saltman-master-1 bash

salt-ssh-master:
	ssh -F ${SSH_CONFIG} -t ${SALTMASTER} "sudo su - root"
ssh-root: salt-ssh-master
ssh:
	ssh -F ${SSH_CONFIG} -t ${GATEWAYHOST}
ssh-to:
	ssh -F ${SSH_CONFIG} -t ${host}

################
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
	docker compose \
		--env-file ${WORKSPACE}/docker_compose_dot_env \
		--project-directory ${PWD}/docker \
		-f ${WORKSPACE}/docker-compose.yml \
		rm -fsv || true

docker-clean-images:
	docker rmi \
		saltman-minion01 \
		saltman-master \
	|| true

docker-deep-clean: docker-clean-containers docker-clean-images docker-clean-volume
################

docker-down:
	cd docker && docker-compose down
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
	@echo playbook: 'make playbook PLAYBOOK="../path/to/myplaybook.yml --check"'
