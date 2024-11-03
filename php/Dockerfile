ARG PHP_DOCKER_IMAGE_VERSION

FROM php:${PHP_DOCKER_IMAGE_VERSION}

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

ARG PHP_INSTALL_DEPENDENCIES
RUN echo ${PHP_INSTALL_DEPENDENCIES}

# Install dependencies
RUN apt-get update && apt-get install -y ${PHP_INSTALL_DEPENDENCIES}

# Required for Mailcacther to work
RUN apt-get update && apt-get install -y msmtp

# Install PHP extensions
ARG PHP_INSTALL_EXTENSIONS
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install ${PHP_INSTALL_EXTENSIONS}

# Enable Redis, PHP sockets, and other common Magento extensions
RUN pecl install redis && docker-php-ext-enable redis

ARG PHP_INSTALL_XDEBUG
#Install XDEBUG if enabled
RUN if [ "${PHP_INSTALL_XDEBUG}" = "true" ]; then \
    pecl install xdebug && \
    docker-php-ext-enable xdebug; \
fi

RUN if [ "${PHP_INSTALL_XDEBUG}" = "true" ]; then \ 
    echo "xdebug.mode=debug" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.client_host=host.docker.internal" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.client_port=9003" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.log=/tmp/xdebug.log" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    sudo touch /tmp/xdebug.log && \
    sudo chown ${SYSTEM_USER_NAME}:root /tmp/xdebug.log; \
fi

# Add OPCACHE Config Settings
ARG PHP_OPCACHE_MEMORY_CONSUMPTION
ARG PHP_OPCACHE_MAX_ACCELERATED_FILES
ARG PHP_OPCACHE_CONSISTENCY_CHECKS
ARG PHP_OPCACHE_VALIDATE_TIMESTAMPS
ARG PHP_OPCACHE_ENABLE_CLI
ARG PHP_OPCACHE_SAVE_COMMENTS
ARG PHP_OPCACHE_FILE_OVERRIDE
ARG PHP_OPCACHE_INTERNED_STRINGS
RUN echo "opcache.memory_consumption=${PHP_OPCACHE_MEMORY_CONSUMPTION}" >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini && \
echo "opcache.max_accelerated_files=${PHP_OPCACHE_MAX_ACCELERATED_FILES}" >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini && \
echo "opcache.consistency_checks=${PHP_OPCACHE_CONSISTENCY_CHECKS}" >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini && \
echo "opcache.validate_timestamps=${PHP_OPCACHE_VALIDATE_TIMESTAMPS}" >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini && \
echo "opcache.enable_cli=${PHP_OPCACHE_ENABLE_CLI}" >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini && \
echo "opcache.save_comments=${PHP_OPCACHE_SAVE_COMMENTS}" >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini && \
echo "opcache.enable_file_override=${PHP_OPCACHE_FILE_OVERRIDE}" >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini && \
echo "opcache.interned_strings_buffer=${PHP_OPCACHE_INTERNED_STRINGS}" >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

# Set memory limits and timezones (optional but recommended)
ARG PHP_REALPATH_CACHE_SIZE
ARG PHP_REALPATH_CACHE_TTL

COPY php.ini /usr/local/etc/php/

# TODO: review this
RUN echo "realpath_cache_size=${PHP_REALPATH_CACHE_SIZE}" >> /usr/local/etc/php/php.ini && \
    echo "realpath_cache_ttl=${PHP_REALPATH_CACHE_TTL}" >> /usr/local/etc/php/php.ini

# Install and configure blackfire
RUN version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION.(PHP_ZTS ? '-zts' : '');") \
&& architecture=$(uname -m) \
&& curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/linux/$architecture/$version \
&& mkdir -p /tmp/blackfire \
&& tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp/blackfire \
&& mv /tmp/blackfire/blackfire-*.so $(php -r "echo ini_get ('extension_dir');")/blackfire.so \
&& printf "extension=blackfire.so\nblackfire.agent_socket=tcp://blackfire:8307\n" > /usr/local/etc/php/conf.d/blackfire.ini \
&& rm -rf /tmp/blackfire /tmp/blackfire-probe.tar.gz

# Allow the magento user to run any sudo command without a password
RUN echo "${SYSTEM_USER_NAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install n98-magerun
ARG INSTALL_N98
RUN if [ "${INSTALL_N98}" = "true" ]; then \ 
   curl -L https://files.magerun.net/n98-magerun2.phar -o /usr/local/bin/n98 && \
    chmod +x /usr/local/bin/n98 && \
    sudo chown -R ${SYSTEM_USER_NAME}:www-data /usr/local/bin/n98; \
fi

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

