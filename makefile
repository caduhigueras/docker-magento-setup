FILE_PATH = ".env"
SAMPLE_FILE_PATH = ".env.sample"
ifeq ($(wildcard .env), .env)
	include .env
endif
setup:
ifneq ($(wildcard ssl/), ssl/)
	@mkdir ssl
endif
ifneq ($(wildcard .env), .env)
	@echo "$(FILE_PATH) does not exist. Copying from .env.sample"
	@cp $(SAMPLE_FILE_PATH) $(FILE_PATH)
	@echo "Please run make one more time to setup your environment."
else
	# echo $(wildcard ssl/)
	# @echo ${MAGENTO_URL}

	@mkdir -p db

	######## SSL CONFIG ########
	@echo "Generating ssl certificates."
	@mkdir -p ssl
	@openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ssl/${MAGENTO_URL}.key -out ssl/${MAGENTO_URL}.crt -subj "/C=$(SSL_COUNTRY)/ST=$(SSL_STATE)/L=$(SSL_LOCATION)/O=$(SSL_ORGANIZATION)/CN=$(SSL_URL)"
	@echo "✓ SSL certificates generated correctly"

	####### VARNISH SETTINGS #######
	@echo "Preparing Varnish VCL file"
	@mkdir -p varnish
	@cp default.vcl.sample varnish/default.vcl
	@echo "✓ VCL generated correctly"

	####### NGINX CONFIG ########
	@echo "Preparing Nginx Conf file"
	@mkdir -p nginx
	@mkdir -p nginx/conf.d
	@cp nginx.conf.sample nginx/nginx.conf
	@cp server.nginx.conf.sample nginx/conf.d/$(MAGENTO_URL).conf
	@sed -i -e 's/{{MAGENTO_SERVER_NAME}}/$(MAGENTO_SERVER_NAME)/g' nginx/conf.d/$(MAGENTO_URL).conf
	@sed -i -e 's/{{MAGENTO_URL}}/$(MAGENTO_URL)/g' nginx/conf.d/$(MAGENTO_URL).conf
	@sed -i -e 's/{{NGINX_CONF_FILE}}/$(NGINX_CONF_FILE)/g' nginx/conf.d/$(MAGENTO_URL).conf
	@echo "✓ Nginx File Conf generated correctly"
endif

install_magento:
	@echo "Creating new database: ${MAGENTO_DB_NAME}"
	@mysql -u root -p${MYSQL_ROOT_PASSWORD} -h 0.0.0.0 -P 3306 -e "create database if not exists ${MAGENTO_DB_NAME}"
	@echo "✓ Database create correctly"
	@echo "Executing install commands"
	@docker exec -it php-fpm bash -c "cd /var/www/html && \
		composer global config http-basic.repo.magento.com ${MAGENTO_AUTH_CONSUMER} ${MAGENTO_AUTH_KEY} && \
		composer create-project --repository=https://repo.magento.com/ magento/project-community-edition:${MAGENTO_VERSION} && \
		mv project-community-edition/* ../html/ && \
		sudo chown -R ${SYSTEM_USER_NAME}:www-data . && \
		bin/magento setup:install --base-url=https://${MAGENTO_URL} --db-host=mariadb --db-name=${MAGENTO_DB_NAME} --db-user=root --db-password=${MYSQL_ROOT_PASSWORD} --backend-frontname=${MAGENTO_BACKEND_FRONTNAME} --admin-firstname=${MAGENTO_ADMIN_NAME} --admin-lastname=${MAGENTO_ADMIN_LAST_NAME} --admin-email=${MAGENTO_ADMIN_EMAIL} --admin-user=${MAGENTO_ADMIN_USER} --admin-password=${MAGENTO_ADMIN_PASSWORD} --language=${MAGENTO_LANGUAGE} --currency=${MAGENTO_CURRENCY} --timezone=${MAGENTO_TIMEZONE} --use-rewrites=1 --search-engine=opensearch --opensearch-host=opensearch --opensearch-port=9200 --opensearch-password=${OPENSEARCH_INITIAL_ADMIN_PASSWORD} --opensearch-index-prefix=${MAGENTO_DB_NAME}_ && \
		sudo find var generated vendor pub/static pub/media app/etc -type f -exec chmod g+w {} + && \
		sudo find var generated vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} + && \
		sudo chown -R ${SYSTEM_USER_NAME}:www-data . && \
		bin/magento deploy:mode:set developer && \
		bin/magento setup:config:set --cache-backend=redis --cache-backend-redis-server=${REDIS_HOST} --cache-backend-redis-port=${REDIS_PORT} --cache-backend-redis-db=${REDIS_FRONTEND_CACHE_DB} && \
		bin/magento setup:config:set --page-cache=redis --page-cache-redis-server=${REDIS_HOST} --page-cache-redis-port=${REDIS_PORT} --page-cache-redis-db=${REDIS_PAGE_CACHE_DB}
		bin/magento setup:config:set --session-save=redis --session-save-redis-host=${REDIS_HOST} --session-save-redis-port=${REDIS_PORT} --session-save-redis-log-level=4 --session-save-redis-db=${REDIS_SESSION_DATABASE}
		bin/magento s:s:d -f && bin/magento s:d:c && bin/magento s:up --keep-generated && bin/magento c:f"
	@echo "✓ Magento installed correctly"

prepare_existing_magento:
	# IMPORT DATABASE DUMP
	@echo "Creating new database: ${MAGENTO_DB_NAME}"
	@mysql -u root -p${MYSQL_ROOT_PASSWORD} -h 0.0.0.0 -P 3306 -e "create database if not exists ${MAGENTO_DB_NAME}"
	@echo "✓ Database create correctly"
	@echo "Importing database from db/${DB_DUMP_NAME}"
	@pv db/${DB_DUMP_NAME} | mysql -f -u root -p${MYSQL_ROOT_PASSWORD} -h 0.0.0.0 -P 3306 ${MAGENTO_DB_NAME} < db/${DB_DUMP_NAME}
	@git clone ${REPO_TO_CLONE} ${REPO_ROOT}

	# CLONE REPO AND APPLY PERMISSIONS
	@cd ${REPO_ROOT} && git checkout -f ${GIT_BRANCH}
	@docker exec -it php-fpm bash -c "cd /var/www/html && \
	sudo find var generated vendor pub/static pub/media app/etc -type f -exec chmod g+w {} + && \
	sudo find var generated vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} + && \
	sudo chown -R ${SYSTEM_USER_NAME}:www-data . "

	# PREPARE MAGENTO ENV FILE
	@cp magento.env.sample ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{MAGENTO_ADMIN_NAME}}/$(MAGENTO_ADMIN_NAME)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{MAGENTO_DB_NAME}}/$(MAGENTO_DB_NAME)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{MAGENTO_DB_PASSWORD}}/$(MYSQL_ROOT_PASSWORD)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{CRYPT_KEY}}/$(CRYPT_KEY)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_HOST}}/$(REDIS_HOST)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_PORT}}/$(REDIS_PORT)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_PASSWORD}}/$({REDIS_PASSWORD})/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_TIMEOUT}}/$(REDIS_TIMEOUT)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_PERSISTENT_IDENTIFIER}}/$(REDIS_PERSISTENT_IDENTIFIER)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_SESSION_DATABASE}}/$(REDIS_SESSION_DATABASE)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_COMPRESSION_TRESHOLD}}/$(REDIS_COMPRESSION_TRESHOLD)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_COMPRESSION_LIBRARY}}/$(REDIS_COMPRESSION_LIBRARY)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_LOG_LEVEL}}/$(REDIS_LOG_LEVEL)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_MAX_CONCURRENCY}}/$(REDIS_MAX_CONCURRENCY)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_BREAK_AFTER_FRONTEND}}/$(REDIS_BREAK_AFTER_FRONTEND)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_BREAK_AFTER_ADMINHTML}}/$(REDIS_BREAK_AFTER_ADMINHTML)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_FIRST_LIFETIME}}/$(REDIS_FIRST_LIFETIME)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_BOT_FIRST_LIFETIME}}/$(REDIS_BOT_FIRST_LIFETIME)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_BOT_LIFETIME}}/$(REDIS_BOT_LIFETIME)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_DISABLE_LOCKING}}/$(REDIS_DISABLE_LOCKING)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_MIN_LIFETIME}}/$(REDIS_MIN_LIFETIME)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_MAX_LIFETIME}}/$(REDIS_MAX_LIFETIME)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_SENTINEL_MASTER}}/$(REDIS_SENTINEL_MASTER)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_SENTINEL_SERVERS}}/$(REDIS_SENTINEL_SERVERS)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_SENTINEL_CONNECT_RETRIES}}/$(REDIS_SENTINEL_CONNECT_RETRIES)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_SENTINEL_VERIFY_MASTER}}/$(REDIS_SENTINEL_VERIFY_MASTER)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_FRONTEND_CACHE_ID_PREFIX}}/$(REDIS_FRONTEND_CACHE_ID_PREFIX)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_FRONTEND_CACHE_DB}}/$(REDIS_FRONTEND_CACHE_DB)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_FRONTEND_COMPRESS_DATA}}/$(REDIS_FRONTEND_COMPRESS_DATA)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_FRONTEND_COMPRESS_LIB}}/$(REDIS_FRONTEND_COMPRESS_LIB)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_PAGE_CACHE_ID_PREFIX}}/$(REDIS_PAGE_CACHE_ID_PREFIX)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_PAGE_CACHE_DB}}/$(REDIS_PAGE_CACHE_DB)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_PAGE_CACHE_COMPRESS_DATA}}/$(REDIS_PAGE_CACHE_COMPRESS_DATA)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{REDIS_PAGE_CACHE_COMPRESS_LIB}}/$(REDIS_PAGE_CACHE_COMPRESS_LIB)/g' ${REPO_ROOT}/app/etc/env.php
	@sed -i -e 's/{{CACHE_ALLOW_PARALLEL_GENERATION}}/$(CACHE_ALLOW_PARALLEL_GENERATION)/g' ${REPO_ROOT}/app/etc/env.php

	# EXECUTE MAGENTO COMMANDS INSIDE PHP-FPM CONTAINER
	@docker exec -it php-fpm bash -c "cd /var/www/html && \
	composer install -o --no-progress --prefer-dist && \
	bin/magento s:s:d -f && bin/magento s:d:c && bin/magento s:up --keep-generated && bin/magento c:f && bin/magento deploy:mode:set developer"
