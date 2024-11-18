FILE_PATH = ".env"
SAMPLE_FILE_PATH = ".sample/.env.sample"
DEFAULT_VCL_SAMPLE_FILE_PATH=".sample/default.vcl.sample"
DEFAULT_VCL_FILE_PATH="varnish/default.vcl"
PHP_ZZ_OVERRIDE_CONF_SAMPLE=".sample/zz-override.conf.sample"
PHP_ZZ_OVERRIDE_CONF="php/zz-override.conf"
NGINX_CONF_SAMPLE=".sample/nginx.conf.sample"
NGINX_CONF="nginx/nginx.conf"
SERVER_NGINX_CONF_SAMPLE=".sample/server.nginx.conf.sample"
MAGENTO_ENV_SAMPLE=".sample/magento.env.sample"
MARIA_DB_CNF_SAMPLE=".sample/mariadb.cnf.sample"
MARIA_DB_CNF="mariadb/my.cnf"

ifeq ($(wildcard .env), .env)
	include .env
endif

deploy_full:
	# EXECUTE MAGENTO COMMANDS INSIDE PHP-FPM CONTAINER
	@docker exec -it php-fpm bash -c "cd /var/www/html && \
	composer update -o --no-progress --prefer-dist && \
	rm -rf pub/static/frontend/* && rm -rf pub/static/adminhtml/* && \
	bin/magento s:s:d -f && rm -rf generated/* && bin/magento s:d:c && bin/magento s:up --keep-generated && bin/magento c:f"

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
	@cp $(DEFAULT_VCL_SAMPLE_FILE_PATH) $(DEFAULT_VCL_FILE_PATH)
	@echo "✓ VCL generated correctly"

	####### MARIA DB SETTINGS #######
	@echo "Preparing MariaDB CNF file"
	@mkdir -p mariadb
	@cp $(MARIA_DB_CNF_SAMPLE) $(MARIA_DB_CNF)
	@sed -i -e 's/{{INNODB_BUFFER_POOL_SIZE}}/${INNODB_BUFFER_POOL_SIZE}/g' ${MARIA_DB_CNF}
	@sed -i -e 's/{{INNODB_LOG_FILE_SIZE}}/${INNODB_LOG_FILE_SIZE}/g' ${MARIA_DB_CNF}
	@sed -i -e 's/{{INNODB_FLUSH_LOG_AT_TRX_COMMIT}}/${INNODB_FLUSH_LOG_AT_TRX_COMMIT}/g' ${MARIA_DB_CNF}
	@sed -i -e 's/{{INNODB_FILE_PER_TABLE}}/${INNODB_FILE_PER_TABLE}/g' ${MARIA_DB_CNF}
	@sed -i -e 's/{{MAX_CONNECTIONS}}/${MAX_CONNECTIONS}/g' ${MARIA_DB_CNF}
	@echo "✓ MariaDB CNF generated correctly"

	####### PHP WWW-CONF SETTINGS #######
	@echo "Preparing PHP-FPM WWW-CONF OVERRIDE file"
	@cp ${PHP_ZZ_OVERRIDE_CONF_SAMPLE} ${PHP_ZZ_OVERRIDE_CONF}
	@sed -i -e 's/{{PHP_PM}}/${PHP_PM}/g' ${PHP_ZZ_OVERRIDE_CONF}
	@sed -i -e 's/{{PHP_PM_MAX_CHILDREN}}/${PHP_PM_MAX_CHILDREN}/g' ${PHP_ZZ_OVERRIDE_CONF}
	@sed -i -e 's/{{PHP_PM_START_SERVERS}}/${PHP_PM_START_SERVERS}/g' ${PHP_ZZ_OVERRIDE_CONF}
	@sed -i -e 's/{{PHP_PM_MIN_SPARE_SERVERS}}/${PHP_PM_MIN_SPARE_SERVERS}/g' ${PHP_ZZ_OVERRIDE_CONF}
	@sed -i -e 's/{{PHP_PM_MAX_SPARE_SERVERS}}/${PHP_PM_MAX_SPARE_SERVERS}/g' ${PHP_ZZ_OVERRIDE_CONF}
	@sed -i -e 's/{{PHP_PM_PROCESS_IDLE_TIMEOUT}}/${PHP_PM_PROCESS_IDLE_TIMEOUT}/g' ${PHP_ZZ_OVERRIDE_CONF}
	@echo "✓ PHP-FPM WWW-CONF OVERRIDE file generated correctly"

	## Check if .env file contains MAGENTO_STORE_CODE_{SUFFIX} and MAGENTO_STORE_URL_{SUFFIX} pattern in order to define if map store code directive should be added and if will use dynamic server name generation for the nginx conf file
	@all_urls=""; \
	url_nginx_map=""; \
	while IFS='=' read -r key value; do \
		case "$$key" in \
			MAGENTO_STORE_URL_*) \
				url_value="$$value"; \
				code_var="MAGENTO_STORE_CODE_$${key#MAGENTO_STORE_URL_}"; \
				code_value=$$(grep "^$$code_var=" .env | cut -d= -f2); \
				all_urls="$$all_urls $$url_value"; \
				url_nginx_map="$$url_nginx_map    $$url_value $$code_value;\n"; \
				;; \
		esac; \
	done < .env ; \
	\
	######## NGINX CONFIG ######## \
	echo "Preparing Nginx Conf file"; \
	mkdir -p nginx; \
	mkdir -p nginx/conf.d; \
	cp ${NGINX_CONF_SAMPLE} ${NGINX_CONF}; \
	cp ${SERVER_NGINX_CONF_SAMPLE} nginx/conf.d/$(MAGENTO_URL).conf; \
	\
	# Add server name based on env \
	if [ -n "$$all_urls" ]; then \
		sed -i -e "s/{{MAGENTO_SERVER_NAME}}/$$all_urls/g" nginx/conf.d/$(MAGENTO_URL).conf; \
	else \
		sed -i -e 's/{{MAGENTO_SERVER_NAME}}/ $(MAGENTO_SERVER_NAME)/g' nginx/conf.d/$(MAGENTO_URL).conf; \
	fi; \
	sed -i -e 's/{{MAGENTO_URL}}/$(MAGENTO_URL)/g' nginx/conf.d/$(MAGENTO_URL).conf; \
	sed -i -e 's/{{NGINX_CONF_FILE}}/$(NGINX_CONF_FILE)/g' nginx/conf.d/$(MAGENTO_URL).conf; \
	\
	# Add map directive if required \
	if [ -n "$$url_nginx_map" ]; then \
		sed -i -e "s|{{MAP_DIRECTIVE}}|\nmap \$$http_host \$$MAGE_RUN_CODE {\n$$url_nginx_map}\n|g" nginx/conf.d/$(MAGENTO_URL).conf; \
	else \
		sed -i -e "s/{{MAP_DIRECTIVE}}//g" nginx/conf.d/$(MAGENTO_URL).conf; \
	fi; \
	echo "✓ Nginx File Conf generated correctly"
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
		rm -rf project-community-edition/* && \
		bin/magento setup:install --base-url=https://${MAGENTO_URL} --db-host=mariadb --db-name=${MAGENTO_DB_NAME} --db-user=root --db-password=${MYSQL_ROOT_PASSWORD} --backend-frontname=${MAGENTO_BACKEND_FRONTNAME} --admin-firstname=${MAGENTO_ADMIN_NAME} --admin-lastname=${MAGENTO_ADMIN_LAST_NAME} --admin-email=${MAGENTO_ADMIN_EMAIL} --admin-user=${MAGENTO_ADMIN_USER} --admin-password=${MAGENTO_ADMIN_PASSWORD} --language=${MAGENTO_LANGUAGE} --currency=${MAGENTO_CURRENCY} --timezone=${MAGENTO_TIMEZONE} --use-rewrites=1 --search-engine=opensearch --opensearch-host=opensearch --opensearch-port=9200 --opensearch-password=${OPENSEARCH_INITIAL_ADMIN_PASSWORD} --opensearch-index-prefix=${MAGENTO_DB_NAME}_ --cache-backend=redis --cache-backend-redis-server=${REDIS_HOST} --cache-backend-redis-port=${REDIS_PORT} --cache-backend-redis-db=${REDIS_FRONTEND_CACHE_DB} --page-cache=redis --page-cache-redis-server=${REDIS_HOST} --page-cache-redis-port=${REDIS_PORT} --page-cache-redis-db=${REDIS_PAGE_CACHE_DB} --session-save=redis --session-save-redis-host=${REDIS_HOST} --session-save-redis-port=${REDIS_PORT} --session-save-redis-log-level=4 --session-save-redis-db=${REDIS_SESSION_DATABASE} && \
		sudo find var generated vendor pub/static pub/media app/etc -type f -exec chmod g+w {} + && \
		sudo find var generated vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} + && \
		sudo chown -R ${SYSTEM_USER_NAME}:www-data . && \
		rm -rf generated/* && \
		bin/magento deploy:mode:set developer && \
		bin/magento s:s:d -f && bin/magento s:d:c && bin/magento s:up --keep-generated && bin/magento c:f"
	@echo "✓ Magento installed correctly"
	@echo "Configure MailCatcher"
	@docker exec -it php-fpm bash -c "cd /var/www/html && \
		bin/magento config:set system/smtp/transport smtp && \
		bin/magento config:set system/smtp/port 1025 && \
		bin/magento config:set system/smtp/host mailcatcher"
	@echo "✓ Mailcatcher configured correctly"
	@echo "Start Nginx Service"
	@docker compose up -d nginx
	@echo "✓ Nginx started correctly"

prepare_existing_magento:
	# IMPORT DATABASE DUMP
	@echo "Creating new database: ${MAGENTO_DB_NAME}"
	@mysql -u root -p${MYSQL_ROOT_PASSWORD} -h 0.0.0.0 -P 3306 -e "create database if not exists ${MAGENTO_DB_NAME}"
	@echo "✓ Database create correctly"
	@echo "Importing database from db/${DB_DUMP_NAME}"
	@pv db/${DB_DUMP_NAME} | mysql -f -u root -p${MYSQL_ROOT_PASSWORD} -h 0.0.0.0 -P 3306 ${MAGENTO_DB_NAME}
	#UPDATE OPENSEARCH DATA STRAIGHT ON THE DATABASE
	@mysql -u root -p${MYSQL_ROOT_PASSWORD} -h 0.0.0.0 -P 3306 ${MAGENTO_DB_NAME} -e "INSERT INTO core_config_data (scope, scope_id, path, value) VALUES ('default', 0, 'catalog/search/engine', 'opensearch') ON DUPLICATE KEY UPDATE value = 'opensearch';"
	@mysql -u root -p${MYSQL_ROOT_PASSWORD} -h 0.0.0.0 -P 3306 ${MAGENTO_DB_NAME} -e "INSERT INTO core_config_data (scope, scope_id, path, value) VALUES ('default', 0, 'catalog/search/opensearch_password', '${OPENSEARCH_INITIAL_ADMIN_PASSWORD}') ON DUPLICATE KEY UPDATE value = '${OPENSEARCH_INITIAL_ADMIN_PASSWORD}';"
	@mysql -u root -p${MYSQL_ROOT_PASSWORD} -h 0.0.0.0 -P 3306 ${MAGENTO_DB_NAME} -e "INSERT INTO core_config_data (scope, scope_id, path, value) VALUES ('default', 0, 'catalog/search/opensearch_server_port', '${OPENSEARCH_PORT}') ON DUPLICATE KEY UPDATE value = '${OPENSEARCH_PORT}';"
	@mysql -u root -p${MYSQL_ROOT_PASSWORD} -h 0.0.0.0 -P 3306 ${MAGENTO_DB_NAME} -e "INSERT INTO core_config_data (scope, scope_id, path, value) VALUES ('default', 0, 'catalog/search/opensearch_server_hostname', '${OPENSEARCH_HOSTNAME}') ON DUPLICATE KEY UPDATE value = '${OPENSEARCH_HOSTNAME}';"
	@git clone ${REPO_TO_CLONE} ${REPO_ROOT}

	# CLONE REPO AND APPLY PERMISSIONS
	@cd ${REPO_ROOT} && git checkout -f ${GIT_BRANCH}
	@docker exec -it php-fpm bash -c "cd /var/www/html && \
	sudo find var generated vendor pub/static pub/media app/etc -type f -exec chmod g+w {} + && \
	sudo find var generated vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} + && \
	sudo chown -R ${SYSTEM_USER_NAME}:www-data . "

	# PREPARE MAGENTO ENV FILE
	@cp ${MAGENTO_ENV_SAMPLE} ${REPO_ROOT}/app/etc/env.php
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
		bin/magento s:s:d -f && rm -rf generated/* && bin/magento s:d:c && bin/magento s:up --keep-generated && bin/magento c:f && bin/magento deploy:mode:set developer && \
		bin/magento config:set system/smtp/transport smtp && \
        bin/magento config:set system/smtp/port 1025 && \
        bin/magento config:set system/smtp/host mailcatcher"

	# START NGINX
	@echo "Start Nginx Service"
	@docker compose up -d nginx
	@echo "✓ Nginx started correctly"

deploy:
	# EXECUTE MAGENTO COMMANDS INSIDE PHP-FPM CONTAINER
	@docker exec -it php-fpm bash -c "cd /var/www/html && \
	rm -rf pub/static/frontend/* && rm -rf pub/static/adminhtml/* && \
	bin/magento s:s:d -f && rm -rf generated/* && bin/magento s:d:c && bin/magento s:up --keep-generated && bin/magento c:f"

front_static_deploy:
	# EXECUTE MAGENTO COMMANDS INSIDE PHP-FPM CONTAINER
	# Usage: make theme=Onedirect/blank front_static_deploy
	@docker exec -it php-fpm bash -c "cd /var/www/html && \
	rm -rf pub/static/frontend/* && bin/magento s:s:d -f -a frontend -t $(theme) && bin/magento c:f"

admin_static_deploy:
	# EXECUTE MAGENTO COMMANDS INSIDE PHP-FPM CONTAINER
	@docker exec -it php-fpm bash -c "cd /var/www/html && \
	rm -rf pub/static/adminhtml/* && \
	bin/magento s:s:d -f -a adminhtml && bin/magento c:f"

di_deploy:
	# EXECUTE MAGENTO COMMANDS INSIDE PHP-FPM CONTAINER
	@docker exec -it php-fpm bash -c "cd /var/www/html && \
	rm -rf generated/* && bin/magento s:d:c && bin/magento c:f"

db_deploy:
	# EXECUTE MAGENTO COMMANDS INSIDE PHP-FPM CONTAINER
	@docker exec -it php-fpm bash -c "cd /var/www/html && \
	bin/magento s:up --keep-generated && bin/magento c:f"

clean_cache:
	@docker exec -it php-fpm bash -c "cd /var/www/html && \
	bin/magento c:c"

flush_cache:
	@docker exec -it php-fpm bash -c "cd /var/www/html && \
	bin/magento c:f"

up:
	@docker compose up -d

down:
	@docker compose down

restart:
	@docker compose restart

db-import:
	@pv db/${DB_DUMP_NAME} | mysql -f -u root -p${MYSQL_ROOT_PASSWORD} -h 0.0.0.0 -P 3306 ${MAGENTO_DB_NAME}

db-export:
	@mkdir -p db
	@mysqldump -f -u root -p${MYSQL_ROOT_PASSWORD} -h 0.0.0.0 -P 3306 ${MAGENTO_DB_NAME} > db/${MAGENTO_DB_NAME}.sql