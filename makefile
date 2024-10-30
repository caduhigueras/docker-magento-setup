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
		bin/magento setup:install --base-url=https://${MAGENTO_URL} --db-host=mariadb --db-name=${MAGENTO_DB_NAME} --db-user=root --db-password=${MYSQL_ROOT_PASSWORD} --backend-frontname=${MAGENTO_BACKEND_FRONTNAME} --admin-firstname=${MAGENTO_ADMIN_NAME} --admin-lastname=${MAGENTO_ADMIN_LAST_NAME} --admin-email=${MAGENTO_ADMIN_EMAIL} --admin-user=${MAGENTO_ADMIN_USER} --admin-password=${MAGENTO_ADMIN_PASSWORD} --language=${MAGENTO_LANGUAGE} --currency=${MAGENTO_CURRENCY} --timezone=${MAGENTO_TIMEZONE} --use-rewrites=1 --search-engine=opensearch --opensearch-host=opensearch --opensearch-port=9200 --opensearch-index-prefix=${MAGENTO_DB_NAME}_ && \
		sudo find var generated vendor pub/static pub/media app/etc -type f -exec chmod g+w {} + && \
		sudo find var generated vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} + && \
		sudo chown -R ${SYSTEM_USER_NAME}:www-data . && \
		bin/magento deploy:mode:set developer && \
		bin/magento s:s:d -f && bin/magento s:d:c && bin/magento s:up --keep-generated && bin/magento c:f"
	@echo "✓ Magento installed correctly"


