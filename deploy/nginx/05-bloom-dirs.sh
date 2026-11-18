#!/bin/sh
# Creates the writable config folder on the /tmp tmpfs before the image's
# 20-envsubst-on-templates.sh renders the templates into it.
set -eu
mkdir -p /tmp/nginx/conf.d
