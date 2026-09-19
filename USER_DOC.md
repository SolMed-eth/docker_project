# User documentation

This document explains how to run and use the Inception stack.

## 0. Services provided

| Service     | What it does                                                   | Reachable from        |
|-------------|----------------------------------------------------------------|-----------------------|
| `nginx`     | Serves the website over HTTPS (TLS 1.2 / 1.3) on port 443      | the host, `https://mchafiki.42.fr` |
| `wordpress` | The WordPress application (php-fpm), executes the PHP pages    | nginx only, port 9000 |
| `mariadb`   | The database where WordPress stores posts, users and settings  | wordpress only, port 3306 |

Only nginx is exposed to the outside; the two other services are reachable
solely through the internal Docker network.

## 1. Before the first start

### Domain name

The website is served for the domain `mchafiki.42.fr`. Make it point to the
machine running Docker by adding this line to `/etc/hosts`:

```
127.0.0.1 mchafiki.42.fr
```

### Secrets

Passwords are not stored in the repository. Before starting the stack, create
the `secrets/` directory at the root of the project with the four files below,
each one containing a single line with the password:

```
secrets/
├── db_root_password.txt    MariaDB root password
├── db_password.txt         password of the MariaDB user used by WordPress
├── wp_admin_password.txt   password of the WordPress administrator
└── wp_user_password.txt    password of the second WordPress user
```

Example:

```
mkdir -p secrets
echo "my_root_password"  > secrets/db_root_password.txt
echo "my_db_password"    > secrets/db_password.txt
echo "my_admin_password" > secrets/wp_admin_password.txt
echo "my_user_password"  > secrets/wp_user_password.txt
```

### Environment file

The non-secret configuration is also kept out of git. Create `srcs/.env` with
the following content (adapt the values if needed):

```
DOMAIN_NAME=mchafiki.42.fr

MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser

WP_TITLE=Inception
WP_ADMIN_USER=mchafiki
WP_ADMIN_EMAIL=mchafiki@student.42.fr
WP_USER=guest
WP_USER_EMAIL=guest@mchafiki.42.fr
```

## 2. Starting and stopping

| Command        | Effect                                                     |
|----------------|------------------------------------------------------------|
| `make`         | Build the images and start everything in the background    |
| `make stop`    | Stop the containers, data is kept                          |
| `make start`   | Start them again                                           |
| `make restart` | Restart the containers                                     |
| `make down`    | Remove the containers and the network, data is kept        |
| `make fclean`  | Remove everything, including the data in `/home/mchafiki/data` |
| `make re`      | Full reset and rebuild                                     |

The first `make` takes a few minutes because the images have to be built and
WordPress has to be downloaded and installed. The following starts are fast.

## 3. Accessing the services

### Website

- `https://mchafiki.42.fr` — the WordPress site
- `https://mchafiki.42.fr/wp-admin` — the administration panel

The certificate is self-signed, so the browser shows a warning the first time.
Accept it to continue. Plain `http://` is not served, only HTTPS on port 443.

### Accounts

Two WordPress users are created automatically at the first start. Their names
and emails come from `srcs/.env`, their passwords from `secrets/`:

| Role          | Username   | Password file                   |
|---------------|------------|---------------------------------|
| Administrator | `mchafiki` | `secrets/wp_admin_password.txt` |
| Author        | `guest`    | `secrets/wp_user_password.txt`  |

### Database

The database is not exposed outside the Docker network. To open a MariaDB
shell inside the container:

```
docker exec -it mariadb mariadb -u wpuser -p wordpress
```

(the password is the one in `secrets/db_password.txt`). For the root account:

```
docker exec -it mariadb mariadb -u root -p
```

## 4. Checking that everything works

```
make ps                      # the three containers must be "Up"
make logs                    # follow the logs of all services
docker logs nginx            # logs of a single container
docker exec -it nginx sh     # open a shell in a container
```

Check the TLS version from the host:

```
openssl s_client -connect mchafiki.42.fr:443 -tls1_2 < /dev/null
openssl s_client -connect mchafiki.42.fr:443 -tls1_1 < /dev/null   # must fail
```

## 5. Where the data lives

| Data                   | Path on the host                    |
|------------------------|-------------------------------------|
| WordPress files        | `/home/mchafiki/data/wordpress`     |
| MariaDB database       | `/home/mchafiki/data/mariadb`       |

These directories are bind-mounted into the containers, so the site and the
database survive `make down`, container restarts and rebuilds. They are only
deleted by `make fclean` / `make re`.

## 6. Changing credentials

The startup scripts read passwords from secrets/ when the containers start. Database accounts and WordPress users are created during the initial installation. To apply new passwords through a fresh installation, update the secret files and reset the stack

```
make fclean
make
```

To change a password without losing the data, do it from inside the
application instead (the WordPress profile page for WordPress users, or
`ALTER USER` in a MariaDB shell for database users).

## 7. Troubleshooting

- **The site does not load** — check `make ps`; if a container keeps restarting,
  read its logs with `docker logs <name>`.
- **"Error establishing a database connection"** — the `mariadb` container is
  not ready or the password in `secrets/db_password.txt` changed after the
  first start. Restore the old password or run `make re`.
- **Browser cannot resolve the domain** — the `/etc/hosts` entry is missing.
- **`make` fails on the volumes** — `/home/mchafiki/data` must exist and be
  writable; `make` creates it, but the user running `make` must be allowed to.
