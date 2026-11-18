# Packages a prebuilt Bloom web app and the mobile downloads into nginx.
# Nothing is compiled here: CI runs `flutter build web` and the mobile builds
# first. The build context needs:
#   build/web/                Flutter web build
#   downloads/                bloom.apk, bloom-unsigned.ipa, manifest.json
#
# Runtime: listens on 8080 as an unprivileged user, works with a read-only
# root filesystem when /tmp is a tmpfs, and reads these from the environment:
#   OPENROUTER_API_KEY        empty disables the AI proxy
#   BLOOM_SHARE_UPSTREAM      the report-share Edge Function URL
#   BLOOM_SHARE_PROXY_SECRET  shared with that function; empty disables sharing

FROM nginxinc/nginx-unprivileged:1.30.6-alpine3.24

# Render only these variables into the config template, and leave nginx's own
# $variables alone. 06-bloom-env.envsh defaults the Bloom variables to empty.
ENV NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1 \
    NGINX_ENVSUBST_FILTER="^(OPENROUTER_API_KEY|BLOOM_SHARE_UPSTREAM|BLOOM_SHARE_PROXY_SECRET|NGINX_LOCAL_RESOLVERS)$" \
    NGINX_ENVSUBST_OUTPUT_DIR=/tmp/nginx/conf.d

# No RUN steps, so a cross-architecture build needs no emulation. The image's
# conf.d/default.conf stays on disk but isn't included by our nginx.conf.
COPY deploy/nginx/nginx.conf /etc/nginx/nginx.conf
COPY deploy/nginx/security-headers.conf /etc/nginx/snippets/
COPY deploy/nginx/templates/ /etc/nginx/templates/
COPY deploy/nginx/05-bloom-dirs.sh /docker-entrypoint.d/05-bloom-dirs.sh
COPY deploy/nginx/06-bloom-env.envsh /docker-entrypoint.d/06-bloom-env.envsh
COPY build/web/ /usr/share/nginx/html/
COPY downloads/ /usr/share/nginx/html/downloads/

EXPOSE 8080
STOPSIGNAL SIGQUIT
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
