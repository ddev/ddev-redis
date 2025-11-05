#!/usr/bin/env bash
#ddev-generated
set -e

script_file="${DDEV_APPROOT}/.ddev/redis/scripts/setup-redis-optimized-config.sh"
extra_docker_file="${DDEV_APPROOT}/.ddev/docker-compose.redis_extra.yaml"

if [[ $(ddev dotenv get .ddev/.env.redis --redis-optimized 2>/dev/null) != "true" ]]; then
  for file in advanced append general io memory network security snapshots; do
    if grep -q '#ddev-generated' "${DDEV_APPROOT}/.ddev/redis/${file}.conf" 2>/dev/null; then
      rm -f "${DDEV_APPROOT}/.ddev/redis/${file}.conf"
    fi
  done

  for file in "${extra_docker_file}" "${script_file}"; do
    if grep -q "#ddev-generated" "${file}" 2>/dev/null; then
      echo "Removing ${file}"
      rm -f "${file}"
    fi
  done
  exit 0
fi

if grep -q '#ddev-generated' "${DDEV_APPROOT}/.ddev/redis/redis.conf"; then
  cat >"${DDEV_APPROOT}/.ddev/redis/redis.conf" <<EOF
# #ddev-generated
################################## INCLUDES ###################################

# Network
include /etc/redis/conf/network.conf

# General
include /etc/redis/conf/general.conf

# Snapshots
include /etc/redis/conf/snapshots.conf

# Security
include /etc/redis/conf/security.conf

# Memory management
include /etc/redis/conf/memory.conf

# CPU management
include /etc/redis/conf/io.conf

# Append mode
include /etc/redis/conf/append.conf

# Advanced config
include /etc/redis/conf/advanced.conf
EOF
fi

if [ ! -f "${extra_docker_file}" ] || grep -q '#ddev-generated' "${extra_docker_file}"; then
  cat >"${extra_docker_file}" <<EOF
#ddev-generated
services:
  redis:
    deploy:
      resources:
        limits:
          cpus: "2.5"
          memory: "768M"
        reservations:
          cpus: "1.5"
          memory: "512M"
    x-ddev:
      describe-info: |
        User: redis
        Pass: redis
EOF
fi

echo "Change the redis dump filename if applicable"
docker run -e DDEV_SITENAME -v "$(pwd)"/redis:/redis -i --rm ddev/ddev-utilities bash -c "sed -i 's/REPLACE_ME/$DDEV_SITENAME/g' /redis/snapshots.conf"

if grep -q "#ddev-generated" "${script_file}" 2>/dev/null; then
  echo "Removing ${script_file}"
  rm -f "${script_file}"
fi
