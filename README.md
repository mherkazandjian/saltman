# saltman

## Development workflow

```bash
make down
make full-clean
make bootstrap-project infra=dev01
make set-current-env env=$HOME/workspaces/saltman/docker/dev01/env.sh
make docker-compose-build
make provision
make ping
make site
make salt-bootstrap
make salt-refresh

make saltman-snapshot-take name='foo'
make saltman-snapshot-restore name='foo'
make up
make site TAGS='--tags=salt-service'
```
