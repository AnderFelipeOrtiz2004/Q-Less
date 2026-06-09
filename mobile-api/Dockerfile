FROM php:8.2-apache

RUN docker-php-ext-install mysqli \
    && a2dismod mpm_event mpm_worker 2>/dev/null || true \
    && a2enmod mpm_prefork rewrite headers \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf

WORKDIR /var/www/html
COPY . /var/www/html/

RUN mkdir -p storage/products storage/avatars \
    && chown -R www-data:www-data storage \
    && chmod -R 775 storage

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
