ARG PHP_DOCKER_IMAGE_VERSION
ARG PHP_INSTALL_XDEBUG

FROM php:${PHP_DOCKER_IMAGE_VERSION}

ARG PHP_INSTALL_DEPENDENCIES
RUN echo ${PHP_INSTALL_DEPENDENCIES}

# Install dependencies
RUN apt-get update && apt-get install -y ${PHP_INSTALL_DEPENDENCIES}

# Install PHP extensions
# RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
ARG PHP_INSTALL_EXTENSIONS
RUN docker-php-ext-install ${PHP_INSTALL_EXTENSIONS}

# Enable Redis, PHP sockets, and other common Magento extensions
RUN pecl install redis && docker-php-ext-enable redis
RUN docker-php-ext-install sockets

# Set memory limits and timezones (optional but recommended)
COPY php.ini /usr/local/etc/php/

# Ensure the container runs as non-root user (optional)
RUN usermod -u 1000 www-data

