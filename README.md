# saltman

## Development workflow

```bash
make bootstrap-project infra=dev01
make set-current-env env=/home/mher/workspaces/saltman/docker/dev01/env.sh
make docker-compose-build
make provision
make ping
make site
make salt-bootstrap
make salt-refresh
```
