# Developer documentation

This document describes how the stack is built and how to work on it.

## 1. Architecture

```
                      HTTPS :443
                          │
                          ▼
                  ┌───────────────┐
                  │     nginx     │  TLS 1.2 / 1.3, self-signed cert
                  └───────┬───────┘
                          │ FastCGI :9000
                          ▼
                  ┌───────────────┐
                  │   wordpress   │  php-fpm 8.2 + wp-cli
                  └───────┬───────┘
                          │ MySQL :3306
                          ▼
                  ┌───────────────┐
                  │    mariadb    │  MariaDB 10.11
                  └───────────────┘

   network:  inception (bridge)
   volumes:  wordpress_data  → /home/mchafiki/data/wordpress
             mariadb_data    → /home/mchafiki/data/mariadb
```

- `nginx` is the only container with a published port (`443`). It serves the
  static files of WordPress directly from the shared volume and forwards
  `.php` requests to `wordpress:9000`.
- `wordpress` runs php-fpm in the foreground. At the first start it downloads
  WordPress with wp-cli, generates `wp-config.php`, installs the site and
  creates the two users.
- `mariadb` runs `mariadbd` in the foreground. At the first start it
  initialises the data directory, sets the root password and creates the
  WordPress database and user.

All three images are built from `debian:bookworm`, the penultimate stable
release of Debian. Each container runs exactly one process as PID 1 (`nginx`,
`php-fpm8.2`, `mariadbd`), started with `exec` from the entrypoint script so
signals are handled correctly and the container stops cleanly.

## 2. Setting up the environment from scratch

1. Install Docker Engine and Docker Compose v2 on a Debian virtual machine
   (from Docker's official apt repository, packages `docker-ce`,
   `docker-ce-cli`, `containerd.io`, `docker-compose-plugin`), plus `make` and
   `git`. Add your user to the `docker` group and log in again.
2. Make the domain resolve locally:
   `echo "127.0.0.1 mchafiki.42.fr" | sudo tee -a /etc/hosts`.
3. Clone the repository.
4. Create `srcs/.env` (content in `USER_DOC.md`, section 1).
5. Create `secrets/` with `db_root_password.txt`, `db_password.txt`,
   `wp_admin_password.txt` and `wp_user_password.txt`, one password per file.
6. Run `make`. The Makefile creates `/home/mchafiki/data/{mariadb,wordpress}`,
   builds the images with `docker compose build` and starts the stack with
   `docker compose up -d`.

## 3. Repository layout

```
Makefile                         wrapper around docker compose
srcs/.env                        non-secret configuration, ignored by git
srcs/docker-compose.yml          services, network, volumes, secrets
srcs/requirements/<service>/
    Dockerfile                   image definition
    conf/                        configuration files copied into the image
    tools/setup.sh               entrypoint script
secrets/*.txt                    passwords, ignored by git
```

## 4. Configuration

### Environment variables (`srcs/.env`)

| Variable         | Used by             | Description                        |
|------------------|---------------------|------------------------------------|
| `DOMAIN_NAME`    | nginx, wordpress    | Domain of the site                 |
| `MYSQL_DATABASE` | mariadb, wordpress  | Name of the WordPress database     |
| `MYSQL_USER`     | mariadb, wordpress  | Database user used by WordPress    |
| `WP_TITLE`       | wordpress           | Site title                         |
| `WP_ADMIN_USER`  | wordpress           | Administrator username             |
| `WP_ADMIN_EMAIL` | wordpress           | Administrator email                |
| `WP_USER`        | wordpress           | Second user (author role)          |
| `WP_USER_EMAIL`  | wordpress           | Second user email                  |

The file is passed to every service with `env_file`, so the variables are
available inside the containers at runtime. It is listed in `.gitignore`
together with `secrets/`; `USER_DOC.md` shows its expected content.

### Secrets

Passwords are declared in the `secrets:` section of `docker-compose.yml` and
mounted by Docker as files under `/run/secrets/` in the containers that need
them. The scripts read them with `cat` at startup:

| Secret              | File                            | Mounted in          |
|---------------------|---------------------------------|---------------------|
| `db_root_password`  | `secrets/db_root_password.txt`  | mariadb             |
| `db_password`       | `secrets/db_password.txt`       | mariadb, wordpress  |
| `wp_admin_password` | `secrets/wp_admin_password.txt` | wordpress           |
| `wp_user_password`  | `secrets/wp_user_password.txt`  | wordpress           |

The `secrets/` directory is listed in `.gitignore`.

## 5. Services in detail

### mariadb

- `Dockerfile`: installs `mariadb-server`, copies the server config and the
  entrypoint, creates `/run/mysqld` for the socket and pid file.
- `conf/50-server.cnf`: replaces the Debian default so the server listens on
  `0.0.0.0:3306` (the default binds to `127.0.0.1` only) and uses `utf8mb4`.
- `tools/setup.sh`:
  1. reads the two passwords from `/run/secrets/`;
  2. if `/var/lib/mysql/mysql` does not exist (first start on an empty
     volume), runs `mariadb-install-db` and then `mariadbd --bootstrap` with
     the SQL that sets the root password, creates the database and the user;
  3. `exec mariadbd --user=mysql` in the foreground.

Because the volume is mounted over `/var/lib/mysql`, the check in step 2 makes
the initialisation run only once; on later starts the existing data is reused.

### wordpress

- `Dockerfile`: installs php-fpm 8.2 with the extensions WordPress needs
  (`mysql`, `curl`, `gd`, `mbstring`, `xml`, `zip`), `php-cli` for wp-cli,
  `mariadb-client` for the readiness check, and downloads `wp-cli.phar` to
  `/usr/local/bin/wp`.
- `conf/www.conf`: php-fpm pool listening on TCP `0.0.0.0:9000` instead of the
  default unix socket, so nginx can reach it over the network.
- `tools/setup.sh`:
  1. reads the passwords from `/run/secrets/`;
  2. waits until a `SELECT 1` succeeds against `mariadb` (the database can take
     a few seconds to accept connections after its container starts);
  3. if `wp-load.php` is missing, downloads WordPress;
  4. if `wp-config.php` is missing, creates it, installs the site with
     `wp core install` and creates the second user with `wp user create`;
  5. `exec php-fpm8.2 -F` in the foreground.

`--allow-root` is required because the script runs as root; the files are
chowned to `www-data` afterwards, which is the user php-fpm workers run as.

### nginx

- `Dockerfile`: installs `nginx` and `openssl`, removes the Debian default site
  (which listens on port 80), copies the server block into `conf.d/`.
- `conf/nginx.conf`: one `server` block on `443 ssl` with `ssl_protocols
  TLSv1.2 TLSv1.3`, root on the shared volume, `try_files` for pretty
  permalinks, and a `location ~ \.php$` that passes requests to
  `wordpress:9000` with `SCRIPT_FILENAME` set.
- `tools/setup.sh`: generates a self-signed certificate for `$DOMAIN_NAME` in
  `/etc/nginx/ssl/` if none exists, then `exec nginx -g "daemon off;"`.

## 6. Networking and storage

- `inception` is a user-defined bridge network. Docker's embedded DNS lets the
  containers reach each other by service name (`mariadb`, `wordpress`), which
  is what the nginx config and the scripts rely on.
- The two volumes are declared with the `local` driver and bind options so
  that Docker manages them as named volumes while the data actually lives in
  `/home/mchafiki/data/<name>`. The directories must exist before
  `docker compose up`; the Makefile creates them.
- `wordpress_data` is mounted in both `wordpress` (read/write, php) and `nginx`
  (static files).

## 7. Working on the project

### Rebuild a single service

```
docker compose -f srcs/docker-compose.yml --env-file srcs/.env up -d --build nginx
```

### Re-run the initialisation scripts

The scripts only initialise on an empty volume. To trigger them again:

```
make fclean
make
```

### Manage containers and volumes

```
docker compose -f srcs/docker-compose.yml --env-file srcs/.env ps
docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs -f mariadb
docker compose -f srcs/docker-compose.yml --env-file srcs/.env restart wordpress
docker volume ls
docker volume inspect srcs_mariadb_data      # shows the device under /home/mchafiki/data
docker volume rm srcs_wordpress_data         # only after `make down`
```

### Inspect a container

```
docker exec -it wordpress sh
docker exec -it mariadb mariadb -u root -p
docker inspect nginx
docker network inspect srcs_inception
```

### Adding a service

1. Create `srcs/requirements/<name>/` with a `Dockerfile`, a `conf/` directory
   and a `tools/setup.sh` entrypoint that ends with `exec <daemon>`.
2. Add the service to `docker-compose.yml` with `build`, `image: <name>`,
   `container_name: <name>`, `networks: [inception]` and
   `restart: unless-stopped`.
3. Add any configuration to `srcs/.env` and any password to `secrets/` plus
   the `secrets:` section of the compose file.
4. If it needs persistence, add a volume bound to `/home/mchafiki/data/<name>`
   and the matching `mkdir -p` in the Makefile.

## 8. Constraints followed

- No `latest` tag, base image pinned to `debian:bookworm`.
- No password in any Dockerfile; all secrets go through Docker secrets.
- No `network: host`, `links:` or `--link`.
- No infinite loop, `tail -f`, `sleep infinity` or similar to keep containers
  alive: every entrypoint ends with `exec` of the real daemon in the
  foreground.
- Only port 443 is published; TLS 1.0 / 1.1 are refused.
- The WordPress administrator username does not contain `admin`.
