ROOT := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

.PHONY: nothing
nothing:

ifeq ($(debug),true)
    DEBUG_OPTS = -s --pdb
endif

docker-build:
	cd docker && docker-compose build

docker-clean-containers:
	cd docker && docker-compose down -v || true
	docker rm \
		docker-saltman-minion01-1 \
		docker-saltman-master-1 \
	|| true

docker-clean-images:
	docker rmi \
		saltman-minion01 \
		saltman-master \
	|| true

docker-clean-volumes:
	docker volume rm \
		docker_saltman_master \
		docker_saltman_minion01 \
	|| true

docker-deep-clean: docker-clean-containers docker-clean-images docker-clean-volume

docker-down:
	cd docker && docker-compose down

docker-up:
	cd docker && docker-compose up -d
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

help:
	@echo "no help info"

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
#