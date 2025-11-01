[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/ddev/ddev-redis/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/ddev/ddev-redis/actions/workflows/tests.yml?query=branch%3Amain)
[![last commit](https://img.shields.io/github/last-commit/ddev/ddev-redis)](https://github.com/ddev/ddev-redis/commits)
[![release](https://img.shields.io/github/v/release/ddev/ddev-redis)](https://github.com/ddev/ddev-redis/releases/latest)

## DDEV Redis

> [!NOTE]
> This add-on has absorbed functionality from `ddev/ddev-redis-7`, see [Advanced Customization](#advanced-customization).

## Overview

[Redis](https://redis.io/) is an in-memory key–value database, used as a distributed cache and message broker, with optional durability.

This add-on integrates Redis into your [DDEV](https://ddev.com/) project with Redis persistence enabled by default.

## Installation

```bash
ddev add-on get ddev/ddev-redis
ddev restart
```

After installation, make sure to commit the `.ddev` directory to version control.

## Usage

| Command | Description |
| ------- | ----------- |
| `ddev redis-backend` | Use a different key-value store for Redis |
| `ddev redis-cli` | Run `redis-cli` inside the Redis container |
| `ddev redis` | Alias for `ddev redis-cli` |
| `ddev redis-flush` | Flush all cache inside the Redis container |
| `ddev describe` | View service status and used ports for Redis |
| `ddev logs -s redis` | Check Redis logs |

Redis is available inside Docker containers with `redis:6379`.

## What makes the optimized config different?

The default config only uses the [redis.conf](./redis/redis.conf) file.

The optimized config uses all `*.conf` files in the [redis](./redis) directory except `redis.conf`.

It uses *hardened* settings ready for production, like enabling Redis credentials.

You can read each config file to see the exact differences.

## Redis Credentials

By default, there is no authentication.

If you have the optimized config enabled, the credentials are:

| Field    | Value   |
|----------|---------|
| Username | `redis` |
| Password | `redis` |

For more information about ACLs, see the [Redis documentation](https://redis.io/docs/latest/operate/oss_and_stack/management/security/acl/).

### Swappable Redis backends

Use the `ddev redis-backend` command to swap between Redis backends:

| Command | Docker Image |
|--------------------------------------|-----------------------------------------------|
| `ddev redis-backend redis`           | `redis:7`                                     |
| `ddev redis-backend redis-alpine`    | `redis:7-alpine`                              |
| `ddev redis-backend valkey`          | `valkey/valkey:8`                             |
| `ddev redis-backend valkey-alpine`   | `valkey/valkey:8-alpine`                      |
| `ddev redis-backend <image>`         | `<image>` (specify your custom Redis image)   |

> [!TIP]
> Add `optimize` or `optimized` after the command to enable optimized Redis configuration.
>
> Example: `ddev redis-backend redis optimize`

## Advanced Customization

To apply an optimized configuration from `ddev/ddev-redis-7`:

```bash
ddev dotenv set .ddev/.env.redis --redis-optimized=true
ddev add-on get ddev/ddev-redis

# (optional) if you have an existing Redis volume, delete it to avoid problems with Redis:
ddev stop
docker volume rm ddev-$(ddev status -j | docker run -i --rm ddev/ddev-utilities jq -r '.raw.name')_redis

ddev restart
```

Make sure to commit the `.ddev/.env.redis` file to version control.

To change the used Docker image:

```bash
ddev dotenv set .ddev/.env.redis --redis-docker-image=redis:7
ddev add-on get ddev/ddev-redis

# (optional) if you have an existing Redis volume, delete it to avoid problems with Redis:
ddev stop
docker volume rm ddev-$(ddev status -j | docker run -i --rm ddev/ddev-utilities jq -r '.raw.name')_redis

ddev restart
```

Make sure to commit the `.ddev/.env.redis` file to version control.

All customization options (use with caution):

| Variable | Flag | Default |
| -------- | ---- | ------- |
| `REDIS_DOCKER_IMAGE` | `--redis-docker-image` | `redis:7` |
| `REDIS_HOSTNAME` | `--redis-hostname` | `redis` |
| `REDIS_OPTIMIZED` | `--redis-optimized` | `false` (`true`/`false`) |

## Credits

**Contributed by [@hussainweb](https://github.com/hussainweb) based on the original [ddev-contrib recipe](https://github.com/ddev/ddev-contrib/tree/master/docker-compose-services/redis) by [@gormus](https://github.com/gormus)**

**Optimized config from `ddev/ddev-redis-7` contributed by [@seebeen](https://github.com/seebeen)**

**Maintained by the [DDEV team](https://ddev.com/support-ddev/)**
