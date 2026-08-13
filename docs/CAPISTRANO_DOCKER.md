# Deploy con Capistrano desde Docker

Correr `cap production deploy` **desde un contenedor**, sin instalar Ruby ni Capistrano en el Mac. El contenedor solo orquesta por SSH; el VPS clona GitHub y ahí hace `bundle`, `yarn` y `assets:precompile`.

No hace falta tener la app compilada en local ni levantar MariaDB/Redis/`web`.

## Qué hace falta

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (o Docker Engine + Compose v2)
- Acceso SSH al VPS como usuario `dev`
- El código **pusheado** a GitHub en el branch de `config/deploy.rb` (hoy: `master`, repo `picocastillo/cateringsolutions`)

Capistrano lee `config/deploy.rb` **en este contenedor** (tu working copy montada) y en el servidor clona el branch remoto. Si el commit no está en GitHub, no entra al release.

## 1. SSH: alias `rosa`

Capistrano usa el host **`rosa`** (`set :domain, 'rosa'`). En `~/.ssh/config` del Mac:

```text
Host rosa
  HostName IP_O_HOSTNAME_DEL_VPS
  User dev
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
```

Esa clave es **la tuya hacia el VPS**. La deploy key de GitHub vive en el servidor (usuario `dev`), no en Docker.

Comprobá **afuera** de Docker:

```bash
ssh rosa 'whoami && ruby -v'
# whoami → dev
# ruby → 3.4.8 (asdf)
```

Si es la primera conexión, aceptá el host key (queda en `~/.ssh/known_hosts`, que el contenedor también monta).

## 2. Build de la imagen

```bash
docker compose --profile deploy build deploy
```

Repetilo si cambió el `Dockerfile` o el `Gemfile`.

## 3. Probar SSH desde el contenedor

```bash
docker compose --profile deploy run --rm --entrypoint ssh deploy -T rosa
```

Deberías entrar como `dev` sin pedir password.

## 4. Deploy

```bash
# En el Mac, el branch ya tiene que estar en GitHub:
git push origin master

docker compose --profile deploy run --rm deploy
```

Eso corre `bundle exec cap production deploy`. Otros comandos:

```bash
docker compose --profile deploy run --rm deploy bundle exec cap production deploy:rollback
docker compose --profile deploy run --rm deploy bundle exec cap production daemons:status
docker compose --profile deploy run --rm deploy bundle exec cap production daemons:restart
```

Shell dentro del contenedor:

```bash
docker compose --profile deploy run --rm --entrypoint bash deploy
```

## Qué corre dónde

| Dónde | Qué |
|---|---|
| Contenedor `deploy` | Capistrano + SSH a `rosa` |
| GitHub | Código del branch (`master`) |
| VPS | clone, `bundle install`, `yarn`, `assets:precompile`, migrate, restart Puma y Delayed Job |

El profile `app` (`web` / `worker` / MariaDB) **no** hace falta para desplegar.

## Troubleshooting

| Síntoma | Qué hacer |
|---|---|
| `Host key verification failed` | En el Mac: `ssh-keyscan -H IP_DEL_VPS >> ~/.ssh/known_hosts` y reintentá |
| `Permission denied (publickey)` | `ssh rosa` tiene que andar en el Mac primero. Revisá `IdentityFile` y que la pública esté en `~dev/.ssh/authorized_keys` del VPS |
| `Bad owner or permissions on /root/.ssh/...` | En Docker Desktop (Mac) suele ignorarse; si falla, copiá la key a un archivo `chmod 600` y montala aparte |
| Capistrano clona el repo viejo | Confirmá `set :repository` y `set :branch` en `config/deploy.rb`. En el VPS, como `dev`: `rm -rf /var/www/kiosk/shared/cached-copy` |
| El release no tiene tu commit | Hiciste push? El VPS baja GitHub, no el working tree local |
| `ssh: Could not resolve hostname rosa` | El contenedor monta `~/.ssh`; el `Host rosa` tiene que estar en `~/.ssh/config` del Mac |

### Agent forwarding (opcional)

Por defecto se monta `~/.ssh` en `/root/.ssh` (solo lectura). Si preferís el agent del Mac (Docker Desktop):

```yaml
# extra en el servicio deploy, docker-compose.yml
environment:
  SSH_AUTH_SOCK: /ssh-agent
volumes:
  - /run/host-services/ssh-auth.sock:/ssh-agent
```

En Linux usá `${SSH_AUTH_SOCK}:/ssh-agent` en vez de esa ruta. En el Mac: `ssh-add -l` y, si hace falta, `ssh-add ~/.ssh/id_ed25519`.

## Relacionado

- [DEPLOY.md](./DEPLOY.md) — operación en el VPS (Puma, Delayed Job, layout Capistrano)
- [scripts/migrate/README.md](../scripts/migrate/README.md) — bootstrap / restore al armar un VPS nuevo
- [DOCKER.md](./DOCKER.md) — app local (MariaDB, Redis, Rails)



RUN

 docker compose --profile deploy run --rm deploy