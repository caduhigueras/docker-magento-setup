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

#CMD ["varnishd", "-a", ":6081", "-T", "localhost:6082", "-f", "/etc/varnish/default.vcl", "-S", "/etc/varnish/secret", "-s", "malloc,8G", "-p", "http_resp_hdr_len=8192"]