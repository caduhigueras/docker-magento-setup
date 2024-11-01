ARG PHP_DOCKER_IMAGE_VERSION

FROM php:${PHP_DOCKER_IMAGE_VERSION}

ARG PHP_INSTALL_DEPENDENCIES
RUN echo ${PHP_INSTALL_DEPENDENCIES}

# Install dependencies
RUN apt-get update && apt-get install -y ${PHP_INSTALL_DEPENDENCIES}

# Install PHP extensions
ARG PHP_INSTALL_EXTENSIONS
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install ${PHP_INSTALL_EXTENSIONS}

# Enable Redis, PHP sockets, and other common Magento extensions
RUN pecl install redis && docker-php-ext-enable redis
RUN docker-php-ext-install sockets

ARG PHP_INSTALL_XDEBUG
#Install XDEBUG if enabled
RUN if [ "${PHP_INSTALL_XDEBUG}" = "true" ]; then \
    pecl install xdebug && \
    docker-php-ext-enable xdebug; \
fi

RUN if [ "${PHP_INSTALL_XDEBUG}" = "true" ]; then \ 
    echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.mode=debug" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.client_host=host.docker.internal" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.client_port=9003" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.log=/tmp/xdebug.log" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini; \
fi

# Set memory limits and timezones (optional but recommended)
COPY php.ini /usr/local/etc/php/

# Ensure the container runs as non-root user (optional)
RUN #usermod -u 1000 www-data

# Define user and group for the application
ARG SYSTEM_USER_NAME
ARG SYSTEM_USER_UID
ARG SYSTEM_USER_GID

# Install required packages and create user/group
RUN groupadd -g ${SYSTEM_USER_GID} ${SYSTEM_USER_NAME} && \
    useradd -u ${SYSTEM_USER_UID} -g ${SYSTEM_USER_NAME} -m ${SYSTEM_USER_NAME} && \
    usermod -a -G www-data ${SYSTEM_USER_NAME} && \
    chown -R ${SYSTEM_USER_NAME}:${SYSTEM_USER_NAME} /var/www

# Set the working directory to /var/www
WORKDIR /var/www/html

# Allow the magento user to run any sudo command without a password
RUN echo "${SYSTEM_USER_NAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to the non-root user
USER ${SYSTEM_USER_NAME}

# Install Composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
    && php composer-setup.php \
    && php -r "unlink('composer-setup.php');" \
    && sudo mv composer.phar /usr/local/bin/composer \
    && sudo chown -R ${USER_NAME}:root /usr/local/bin/composer \
    && sudo chown -R ${USER_NAME}:www-data /var/www/html

ARG MAGENTO_AUTH_CONSUMER
ARG MAGENTO_AUTH_KEY

RUN composer global config http-basic.repo.magento.com ${MAGENTO_AUTH_CONSUMER} ${MAGENTO_AUTH_KEY}

