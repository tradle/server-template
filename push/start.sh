#!/bin/bash

# TODO: use docker-compose, don't use named container for pushd

# This nginx container will get a configuration generated by the docker-gen instance and act as a reverse-proxy
echo "Starting nginx instance..."
source .env
docker run -d -p 80:80 -p 443:443 \
    --name nginx \
    -v /etc/nginx/conf.d  \
    -v /etc/nginx/vhost.d \
    -v /usr/share/nginx/html \
    -v /var/proxy/certs:/etc/nginx/certs:ro \
    nginx

# This nginx-gen container using the docker-gen image will generate a 'default.conf' file from the 'nginx.tmpl' located in volumes/proxy/templates.
echo "Starting docker-gen instance..."
docker run -d \
    --name nginx-gen \
    --volumes-from nginx \
    -v $(pwd)/nginx.tmpl:/etc/docker-gen/templates/nginx.tmpl:ro \
    -v /var/run/docker.sock:/tmp/docker.sock:ro \
    jwilder/docker-gen \
    -notify-sighup nginx -watch -only-exposed -wait 5s:30s /etc/docker-gen/templates/nginx.tmpl /etc/nginx/conf.d/default.conf

echo "Starting redis..."
docker run -d \
    --name redis
    -p 6379
    redis

echo "Starting pushd server..."
docker run -d \
    --name pushd \
    -v $(pwd)/settings:/opt/settings \
    -v $(pwd)/apns:/opt/apns \
    -e REDIS_PORT=6379 \
    -e REDIS_HOST=redis \
    # -e REDIS_PASSWORD="..."
    -e GCM_KEY="${GCM_KEY}"
    -e APNS_CERT="/opt/apns/apns-cert.pem" \
    -e APNS_KEY="/opt/apns/apns-key.pem" \
    -e PUSHD_LOGGING_LEVEL=silly \
    amsdard/pushd:latest

echo "Starting tradle push server"
docker run -d \
    --name tradle-push \
    -p 80 \
    -p 443 \
    -e PUSHD_TCP_PORT=8081 \
    -e "VIRTUAL_HOST=${TRADLE_SERVER_URL}" \
    # -e VIRTUAL_NETWORK=nginx-proxy
    -e VIRTUAL_PORT=80 \
    -e "LETSENCRYPT_HOST=${TRADLE_SERVER_URL}" \
    -e "LETSENCRYPT_EMAIL=${DEV_EMAIL}" \
    tradle/push-server
