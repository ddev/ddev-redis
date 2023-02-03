[![tests](https://github.com/ddev/ddev-redis/actions/workflows/tests.yml/badge.svg)](https://github.com/ddev/ddev-redis/actions/workflows/tests.yml) ![project is maintained](https://img.shields.io/maintenance/yes/2024.svg)

## What is this?

This repository allows you to quickly install redis into a [Ddev](https://ddev.readthedocs.io) project using just `ddev get ddev/ddev-redis`.

## Installation

1. `ddev get ddev/ddev-redis`
2. `ddev restart`

## Explanation

This redis recipe for [ddev](https://ddev.readthedocs.io) installs a [`.ddev/docker-compose.redis.yaml`](docker-compose.redis.yaml) using the `redis` docker image.

## Interacting with Redis

* The Redis instance will listen on TCP port 6379 (the redis default).
* Configure your application to access redis on the host:port `redis:6379`.
* To reach the redis CLI interface, run `ddev redis-cli` to begin a session. You can also run Redis CLI commands directly on the command-line, e.g., `ddev redis-cli INFO`.

**Contributed and maintained by [@hussainweb](https://github.com/hussainweb) based on the original [ddev-contrib recipe](https://github.com/ddev/ddev-contrib/tree/master/docker-compose-services/redis) by [@gormus](https://github.com/gormus)**
