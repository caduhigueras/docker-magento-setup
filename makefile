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
	@echo ${MAGENTO_URL}
	@echo "Generating ssl certificates."
	@openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ssl/${MAGENTO_URL}.key -out ssl/${MAGENTO_URL}.crt -subj "/C=$(SSL_COUNTRY)/ST=$(SSL_STATE)/L=$(SSL_LOCATION)/O=$(SSL_ORGANIZATION)/CN=$(SSL_URL)"
	@echo "SSL certificates generated correctly"
	@echo "Preparing Varnish VCL file"
	@cp default.vcl.sample default.vcl
	@sed -ie 's/{{VCL_HOST_MASK}}/$(MAGENTO_URL)/g' default.vcl
endif
