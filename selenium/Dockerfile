FROM selenium/standalone-chrome:latest

USER root

# Install NSS tools
RUN apt-get update && apt-get install -y libnss3-tools && rm -rf /var/lib/apt/lists/*

# Add local CA
COPY ssl/ca/localCA.crt /usr/local/share/ca-certificates/localCA.crt
RUN update-ca-certificates

# Import CA into Chrome NSS DB
RUN mkdir -p /home/seluser/.pki/nssdb && \
    chown -R seluser:seluser /home/seluser/.pki && \
    runuser -u seluser -- certutil -d sql:/home/seluser/.pki/nssdb -N --empty-password && \
    runuser -u seluser -- certutil -d sql:/home/seluser/.pki/nssdb \
      -A -t "C,," -n "LocalDev-CA" -i /usr/local/share/ca-certificates/localCA.crt

USER seluser

