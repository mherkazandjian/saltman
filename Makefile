SHELL := /bin/bash
ROOT := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

CONFIGS_DIR ?= projects
CURRENT_ENV_EXISTS := $(shell test -f .current_env && printf yes)

ifeq "$(origin infra)" "command line"
INFRA = ${infra}
endif

ifeq "$(origin ansible_opts)" "command line"
ANSIBLE_OPTS = ${ansible_opts}
endif

ifeq (${CURRENT_ENV_EXISTS},yes)
    ifndef SALTMAN_INFRA
        #$(info CURRENT_ENV_EXISTS is "yes" and SALTMAN_INFRA is not set)
        include .current_env
        ifeq "$(origin infra)" "command line"
            INFRA = ${infra}
        endif
    else
        #$(info SALTMAN_INFRA is set; skipping .current_env inclusion)
        envpathbase := $(shell grep workdir ${CONFIGS_DIR}/${SALTMAN_INFRA}/conf.yml | awk '{print $$2}')
        #$(info ${envpathbase})
        # if the path exists include it otherwise print an error message
        ifneq (,$(wildcard ${envpathbase}/env.sh))
            include ${envpathbase}/env.sh
        else
            $(info )
            $(info WARNING:)
            $(info |    ${envpathbase}/env.sh does not exist)
            $(info |    set an environemt by pointing to a certain environment file)
            $(info )
        endif
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
	@echo "    ANSIBLE_CONFIG=${ANSIBLE_CONFIG}"
	@echo "    GATEWAYHOST=${GATEWAYHOST}"
	@echo "    SALTMASTER=${SALTMASTER}"
	@echo "    INFRA=${INFRA}"
	@echo "make vars"
	@echo "    ANSIBLE_FLAGS=${ANSIBLE_FLAGS}"
	@echo "ansible --version"
	@ansible --version

list-envs:
	@for confpath in `find ${CONFIGS_DIR} -type f -name conf.yml -not -path "*template*" | sort`; do \
		envpathbase=$$(grep workdir $${confpath} | awk '{print $$2}'); \
		envpath=$${envpathbase/#\~/$$HOME}/env.sh; \
		if [ -f $${envpath} ]; then \
			echo "make set-current-env env="$${envpath}; \
			echo "     " `grep "short_description:" $${confpath}`; \
		fi; \
	done

################
bootstrap-project:
	@echo "bootstrap-project"
	python src/bootstrap_project.py ${CONFIGS_DIR}/${INFRA}/conf.yml

DOCKER_COMPOSE_BUILD_OPTS ?=
docker-compose-build:
	echo "docker-compose-build"
	docker compose \
		--env-file ${WORKSPACE}/docker_compose_dot_env \
		--project-directory ${PWD}/docker \
		--project-name ${INFRA} \
		-f ${WORKSPACE}/docker-compose.yml \
		build ${DOCKER_COMPOSE_BUILD_OPTS}


provision: docker-compose-build
	ADMIN_SSH_PUBLIC_KEY=`cat ${WORKSPACE}/id_ed25519.pub` \
		docker compose \
			--env-file ${WORKSPACE}/docker_compose_dot_env \
			--project-directory ${PWD}/docker \
			--project-name ${INFRA} \
			-f ${WORKSPACE}/docker-compose.yml \
			up -d

start: provision
up: provision

docker-compose:
	ADMIN_SSH_PUBLIC_KEY=`cat ${WORKSPACE}/id_ed25519.pub` \
		docker compose \
			--env-file ${WORKSPACE}/docker_compose_dot_env \
			--project-directory ${PWD}/docker \
			--project-name ${INFRA} \
			-f ${WORKSPACE}/docker-compose.yml \
			${args}

docker-compose-log:
	make docker-compose args="logs --follow"

suspend: docker-compose-build
	docker compose \
		--env-file ${WORKSPACE}/docker_compose_dot_env \
		--project-directory ${PWD}/docker \
		--project-name ${INFRA} \
		-f ${WORKSPACE}/docker-compose.yml \
		pause

resume: docker-compose-build
	docker compose \
		--env-file ${WORKSPACE}/docker_compose_dot_env \
		--project-directory ${PWD}/docker \
		--project-name ${INFRA} \
		-f ${WORKSPACE}/docker-compose.yml \
		unpause


snapshot-take: saltman-snapshot-take
saltman-snapshot-take:
	@echo "take a snapshot of the containers."
	python src/snapshots.py \
		-f ${WORKSPACE}/docker-compose.yml \
		--project-name ${INFRA} \
		--action take \
		--name ${INFRA}-${name}-`git rev-parse --short HEAD`-`date +%Y%m%d%H%M%S`

snapshot-restore: saltman-snapshot-restore
saltman-snapshot-restore:
	@echo "restore the state of the container from snapshots."
	python src/snapshots.py \
		-f ${WORKSPACE}/docker-compose.yml \
		--action restore \
		--name ${INFRA}-${name}

snapshot-list: saltman-snapshot-list
saltman-snapshot-list:
	@echo "list the snapshots."
	docker images | grep saltman | grep ${INFRA}

################
ANSIBLE_OPTS=
ANSIBLE_SITE=${HOME}/projects/surf/dms-salt-researchcloud/ansible
ansible-site-syntax:
	ansible-playbook ${ANSIBLE_FLAGS} --become ${ANSIBLE_SITE}/site.yml ${TAGS} --syntax-check ${ANSIBLE_OPTS}

site:
	ansible-playbook ${ANSIBLE_FLAGS} --become ${ANSIBLE_SITE}/site.yml ${TAGS} ${ANSIBLE_OPTS}

playbook:
	ansible-playbook ${ANSIBLE_FLAGS} ${PLAYBOOK} ${TAGS} ${ANSIBLE_OPTS}

bootstrap:
	ansible-playbook ${ANSIBLE_FLAGS} ${ANSIBLE_SITE}/site.yml ${TAGS} ${ANSIBLE_OPTS}

ping:
	ansible ${ANSIBLE_FLAGS} all -o -m ansible.builtin.ping ${ANSIBLE_OPTS}

cmd:
	ansible ${ANSIBLE_FLAGS} all -u admin -b -m ansible.builtin.shell -a "${CMD}" ${ANSIBLE_OPTS}

################
ssh:
	ssh -F ${SSH_CONFIG} -t ${GATEWAYHOST}

salt-master:
	docker exec -it docker-saltman-salt-master-1 /bin/bash

ssh-salt-master:
	ssh -F ${SSH_CONFIG} -t ${SALTMASTER} "sudo su - root"
ssh-root: ssh-salt-master
ssh-to:
	ssh -F ${SSH_CONFIG} -t ${host} "sudo su - root"

################
salt-ping:
	ssh -F ${SSH_CONFIG} ${SALTMASTER} "sudo salt '*' test.ping -t 120"
salt-bootstrap:
	ssh -F ${SSH_CONFIG} ${SALTMASTER} "sudo salt ${SALTMASTER} state.apply linux.salt -t 120"
	ansible ${ANSIBLE_FLAGS} ${SALTMASTER} -u admin -b -m ansible.builtin.shell -a "systemctl restart salt-master"
	ansible ${ANSIBLE_FLAGS} all -u admin -b -m ansible.builtin.shell -a "systemctl restart salt-minion"

salt-sync-states:
	ssh -F ${SSH_CONFIG} ${SALTMASTER} "sudo salt '*' saltutil.sync_states -t 120"

salt-refresh-pillars:
	ssh -F ${SSH_CONFIG} ${SALTMASTER} "sudo salt '*' saltutil.refresh_pillar -t 120"

salt-sync:
	ssh -F ${SSH_CONFIG} ${SALTMASTER} "sudo salt '*' saltutil.sync_all -t 120"
	ssh -F ${SSH_CONFIG} ${SALTMASTER} "sudo salt '*' saltutil.sync_states -t 120"
	ssh -F ${SSH_CONFIG} ${SALTMASTER} "sudo salt '*' saltutil.refresh_pillar -t 120"
	ssh -F ${SSH_CONFIG} ${SALTMASTER} "sudo salt '*' saltutil.sync_all -t 120"

salt-clear-cache:
	ssh -F ${SSH_CONFIG} ${SALTMASTER} "sudo salt '*' saltutil.clear_cache -t 120"

salt-refresh: | env salt-clear-cache salt-sync

salt-apply:
	ssh -F ${SSH_CONFIG} ${SALTMASTER} "sudo salt '*' state.apply -t 120"
################
down:
	docker compose \
		--env-file ${WORKSPACE}/docker_compose_dot_env \
		--project-directory ${PWD}/docker \
		--project-name ${INFRA} \
		-f ${WORKSPACE}/docker-compose.yml \
		down -v || true
stop: down   # alias for stop

docker-clean-containers: stop
	docker rm \
		docker-saltman-minion01-1 \
		docker-saltman-master-1 \
	|| true

docker-clean-volumes: stop
	docker volume rm \
		docker_saltman_master \
		docker_saltman_minion01 \
	|| true

full-clean: docker-clean-containers docker-clean-volumes
	docker compose \
		--env-file ${WORKSPACE}/docker_compose_dot_env \
		--project-directory ${PWD}/docker \
		--project-name ${INFRA} \
		-f ${WORKSPACE}/docker-compose.yml \
		rm -fsv || true
	rm -fvr ${WORKSPACE}

deep-clean:
	docker rmi \
		saltman-minion01 \
		saltman-master \
	|| true

docker-deep-clean: docker-clean-containers docker-clean-images docker-clean-volume
################

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
	@ echo '-=-=-=-=-=-=-=-=--=-=  env -=-=-=-=-=-=-=-=-=--=-='
	@echo set-default-env
	@echo set-current-env
	@echo set-current-env-as-default
	@echo use-default-env-as-current
	@echo env
	@echo list-envs
	@ echo '-=-=-=-=-=-=-=-=--=-=  project -=-=-=-=-=-=-=-=-=--=-='
	@echo bootstrap-project
	@echo bootstrap
	@echo provision
	@ echo '-=-=-=-=-=-=-=-=--=-=  docker -=-=-=-=-=-=-=-=-=--=-='
	@echo docker-build:
	@echo docker-clean-containers:
	@echo docker-clean-images:
	@echo docker-clean-volumes:
	@echo docker-deep-clean: docker-clean-containers docker-clean-images docker-clean-volume
	@echo docker-down:
	@echo docker-up:
	@echo docker-clean-containers
	@echo docker-clean-volumes
	@echo full-clean
	@echo deep-clean
	@echo docker-deep-clean
	@echo clean
	@echo docker-compose
	@echo docker-compose-log
	@echo salt-master
	@ echo '-=-=-=-=-=-=-=-=--=-=  ansible -=-=-=-=-=-=-=-=-=--=-='
	@echo playbook: 'make playbook PLAYBOOK="../path/to/myplaybook.yml --check"'
	@echo ansible-site-syntax
	@echo site
	@echo playbook
	@echo ping
	@echo cmd
	@echo ssh
	@echo ssh-root
	@echo ssh-to
	@ echo '-=-=-=-=-=-=-=-=--=-=  control -=-=-=-=-=-=-=-=-=--=-='
	@echo start
	@echo up
	@echo suspend
	@echo resume
	@echo snapshot-take
	@echo snapshot-restore
	@echo down
	@echo stop
	@ echo '-=-=-=-=-=-=-=-=--=-=  salt -=-=-=-=-=-=-=-=-=--=-='
	@echo ssh-salt-master
	@echo salt-ping
	@echo salt-bootstrap
	@echo salt-sync-states
	@echo -e "\033[0;32msalt-refresh\033[0m"
	@echo -e "\033[0;32msalt-refresh-pillars\033[0m"
	@echo salt-sync
	@echo salt-clear-cache
	@echo salt-apply
