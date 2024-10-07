# saltman

```bash
make bootstrap-project infra=dev01
make docker-compose-build
make provision
make ping
make ssh-root


# build the docker images
make docker-build

# start the docker containers and accept the salt minions
make docker-up
```
