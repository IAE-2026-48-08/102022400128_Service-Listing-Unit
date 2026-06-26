FROM php:8.2-cli

RUN apt-get update \
    && apt-get install -y --no-install-recommends git unzip libzip-dev libicu-dev default-mysql-client \
    && docker-php-ext-install pdo_mysql zip intl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY composer.json composer.lock ./
RUN composer install --no-interaction --prefer-dist --no-dev --optimize-autoloader --no-scripts

COPY . .

# Create .env from .env.example so Laravel can read configuration
# Pre-copy static openapi.json as fallback for Swagger UI
RUN cp .env.example .env \
    && composer dump-autoload --optimize \
    && mkdir -p storage/api-docs storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache \
    && cp docs/openapi.json storage/api-docs/api-docs.json

EXPOSE 8001

CMD ["sh", "-c", "if [ \"$DB_CONNECTION\" = \"mysql\" ]; then count=0; while ! mysqladmin ping -h \"$DB_HOST\" -u\"$DB_USERNAME\" -p\"$DB_PASSWORD\" --silent; do if [ $count -ge 30 ]; then echo 'Database not ready, proceeding anyway...'; break; fi; echo 'Waiting for database...'; sleep 1; count=$((count + 1)); done; fi && php artisan l5-swagger:generate || true && php artisan migrate --seed --force && php artisan serve --host=0.0.0.0 --port=8001"]
