*This project has been created as part of the 42 curriculum by mchafiki.*

# Inception

## Description

This project is a Docker-based system administration exercise designed to deploy a small web infrastructure inside a virtual machine.

The stack includes:

- NGINX with TLSv1.2 or TLSv1.3 on port 443
- WordPress with PHP-FPM
- MariaDB
- A dedicated Docker network
- Two persistent volumes

Each service runs in its own container and is built using a custom Dockerfile.

### Docker use in the project

Docker is used to separate each service into its own environment:

- NGINX handles HTTPS traffic
- WordPress + PHP-FPM runs the website
- MariaDB stores the WordPress database
- Docker volumes preserve persistent data
- A Docker network allows the containers to communicate

### Virtual Machines vs Docker

A virtual machine runs a complete operating system with its own kernel.

Docker containers share the host kernel, which makes them lighter and faster to start.

In this project, Docker runs inside a Linux virtual machine.

### Secrets vs Environment Variables

Environment variables are used for non-sensitive configuration such as the domain name, database name and usernames.

Sensitive information such as passwords is stored separately using secret files and must not be hardcoded inside Dockerfiles.

### Docker Network vs Host Network

A dedicated Docker network allows containers to communicate using their service names while keeping internal services isolated.

Only NGINX is exposed to the host on port 443.

### Docker Volumes vs Bind Mounts

Persistent storage is required because container data can disappear when a container is removed.

The project keeps the WordPress files and MariaDB database data under:

```text
/home/mchafiki/data/wordpress
/home/mchafiki/data/mariadb
```

## Instructions

### Prerequisites

Before running the project, make sure the following are available:

- Docker
- Docker Compose
- A Linux virtual machine
- Make
- A local host entry for the domain name

Example:

```bash
sudo nano /etc/hosts
```

Add:

```text
127.0.0.1 mchafiki.42.fr
```

### Build and run

From the project root:

```bash
make
```

This command creates the required directories, builds the Docker images and starts the containers.

Useful commands:

```bash
make
make up
make down
make clean
make re
```

The stack can also be started directly with:

```bash
docker compose -f srcs/docker-compose.yml up -d --build
```

The website is available at:

```text
https://mchafiki.42.fr
```

The WordPress administration panel is available at:

```text
https://mchafiki.42.fr/wp-admin
```

### Data persistence

Persistent data is stored in:

```text
/home/mchafiki/data/wordpress
/home/mchafiki/data/mariadb
```

This allows the WordPress files and database data to remain available when containers are restarted or recreated.

## Resources

### References

- Docker documentation: https://docs.docker.com/
- Docker Compose documentation: https://docs.docker.com/compose/
- NGINX documentation: https://nginx.org/en/docs/
- WordPress documentation: https://wordpress.org/documentation/
- MariaDB documentation: https://mariadb.com/kb/en/documentation/

### AI usage

AI tools were used to help clarify Docker concepts, review configuration choices, assist with debugging and improve the project documentation.

All suggestions were reviewed and tested before being used in the project.

## Conclusion

This project demonstrates how a web infrastructure can be deployed using Docker with isolated services, HTTPS, networking and persistent storage.