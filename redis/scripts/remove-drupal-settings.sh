#!/usr/bin/env bash
#ddev-generated
set -e
set -x

REDIS_SETTINGS_FILE_NAME="${DDEV_APPROOT}/${DDEV_DOCROOT}/sites/default/settings.ddev.redis.php"

echo "Settings file name: ${REDIS_SETTINGS_FILE_NAME}"
rm -f ${REDIS_SETTINGS_FILE_NAME}

# Don't attempt to edit the settings.php as it might be complex
