FROM php:8.2-apache

# Solo un MPM activo: quita todos y deja prefork (requerido por mod_php).
RUN rm -f /etc/apache2/mods-enabled/mpm_*.load /etc/apache2/mods-enabled/mpm_*.conf \
    && a2enmod mpm_prefork rewrite headers \
    && docker-php-ext-install mysqli \
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
