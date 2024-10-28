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

# Install Composer todo add credentials auth.json!
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
    && php composer-setup.php \
    && php -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer

ARG MAGENTO_VERSION
ARG MAGENTO_ROOT
RUN composer create-project --repository=https://repo.magento.com/ magento/project-community-edition:${MAGENTO_VERSION} /var/www