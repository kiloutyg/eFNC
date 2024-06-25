#!/bin/sh

# Install the app dependencies 
composer install;
yarn install;
composer clear-cache;

# Clear the cache
php bin/console cache:clear --no-warmup --env=dev;

# Warm up the cache
php bin/console cache:warmup --env=dev;


# Set the permissions
chmod -R 777 /var/www/var/cache/prod/pools
chown -R www-data:www-data /var/www/var/cache/dev/pools;

chmod 777 . -R;

# Remove old migrations folder and files
rm -rf migrations;

# Create the migrations directory
mkdir -p migrations;

# Create the database and run the migrations
php bin/console make:migration;
php bin/console doctrine:migrations:migrate;

# Build the assets and start the server
exec apache2-foreground &
yarn encore dev --watch
