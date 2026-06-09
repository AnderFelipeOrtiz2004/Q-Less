FROM php:8.2-cli-bookworm

RUN docker-php-ext-install mysqli

WORKDIR /var/www/html
COPY . /var/www/html/

RUN mkdir -p storage/products storage/avatars \
    && chmod -R 775 storage

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["docker-entrypoint.sh"]
