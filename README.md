# saltman

## Quick start

- clone the salman repository

```bash
    git clone https://github.com/mherkazandjian/saltman
```

- create a new project from the template

```bash
    cd saltman
    cp -fvr projects/templates/template01 projects/dev01
```

- edit the conf file `projects/dev01/conf/project.conf` and set the project name and the workspace directory.

make setup-and-start infra=dev02
make ping

## Development workflow

```bash
make down
make full-clean
# if needed delete the project dir as root

make setup-and-start infra=dev01
make ping
make site
make salt-bootstrap
make salt-refresh


# more detailed procedure
make bootstrap
make provision
make set-current-env env=$HOME/workspaces/saltman/docker/dev01/env.sh
make docker-compose-build
make provision
make ping
make site
make salt-bootstrap
make salt-refresh

make saltman-snapshot-take name='vanilla'
make saltman-snapshot-restore name='vanilla'
make up
make site TAGS='--tags=salt-service'

# salt
salt node01 state.apply linux.packages.repos test=true
salt node01 state.apply irods.psql test=true
```
