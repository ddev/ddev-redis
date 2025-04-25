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
| `ddev redis-cli` | Run `redis-cli` inside the Redis container |
| `ddev redis` | Alias for `ddev redis-cli` |
| `ddev redis-flush` | Flush all cache inside the Redis container |
| `ddev describe` | View service status and used ports for Redis |
| `ddev logs -s redis` | Check Redis logs |

Redis is available inside Docker containers with `redis:6379`.

## Redis Credentials

| Field    | Value                 |
|----------|-----------------------|
| Username | `redis`               |
| Password | `` (empty by default) |

## Advanced Customization

To apply an optimized configuration from `ddev/ddev-redis-7`:

```bash
ddev dotenv set .ddev/.env.redis --redis-optimized=true
ddev add-on get ddev/ddev-redis
ddev restart
```

Make sure to commit the `.ddev/.env.redis` file to version control.

To change the used Docker image:

```bash
ddev dotenv set .ddev/.env.redis --redis-docker-image=redis:7
ddev add-on get ddev/ddev-redis
ddev restart
```

Make sure to commit the `.ddev/.env.redis` file to version control.

All customization options (use with caution):

| Variable | Flag | Default |
| -------- | ---- | ------- |
| `REDIS_DOCKER_IMAGE` | `--redis-docker-image` | `redis:7` |
| `REDIS_OPTIMIZED` | `--redis-optimized` | `false` (`true`/`false`) |

## Credits

**Contributed by [@hussainweb](https://github.com/hussainweb) based on the original [ddev-contrib recipe](https://github.com/ddev/ddev-contrib/tree/master/docker-compose-services/redis) by [@gormus](https://github.com/gormus)**

**Maintained by the [DDEV team](https://ddev.com/support-ddev/)**
