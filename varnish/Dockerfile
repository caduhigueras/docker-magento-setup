ARG VARNISH_DOCKER_IMAGE_VERSION
# Base Varnish image
FROM varnish:${VARNISH_DOCKER_IMAGE_VERSION}

# Temporarily switch to root user to install sudo
USER root

# Install sudo
RUN apt-get update && apt-get install -y sudo net-tools procps

# Create a new user and give them sudo access
RUN echo "varnish ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set up the user to be used
USER varnish

ARG VARNISH_HTTP_PORT
ARG VARNISH_BACKEND_PORT
ARG VARNISH_MEMORY_ALLOCATION
ARG VARNISH_HTTP_RESP_HDR_LEN
ARG VARNISH_HTTP_RESP_SIZE
ARG VARNISH_HTTP_WORKSPACE_BACKEND
ARG VARNISH_THREAD_POOLS
ARG VARNISH_THREAD_POOL_MIN
ARG VARNISH_THREAD_POOL_MAX

CMD varnishd -a ":${VARNISH_HTTP_PORT}" \
             -T "localhost:${VARNISH_BACKEND_PORT}" \
             -F \
             -f "/etc/varnish/default.vcl" \
             -s "malloc,${VARNISH_MEMORY_ALLOCATION}" \
             -p "http_resp_hdr_len=${VARNISH_HTTP_RESP_HDR_LEN}" \
             -p "http_resp_size=${VARNISH_HTTP_RESP_SIZE}" \
             -p "workspace_backend=${VARNISH_HTTP_WORKSPACE_BACKEND}" \
             -p "thread_pools=${VARNISH_THREAD_POOLS}" \
             -p "thread_pool_min=${VARNISH_THREAD_POOL_MIN}" \
             -p "thread_pool_max=${VARNISH_THREAD_POOL_MAX}"