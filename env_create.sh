#!/bin/bash

# Prompt for database details
read -p "Please enter your MySQL root password: " MYSQL_ROOT_PASSWORD
read -p "Please enter your MySQL username: " MYSQL_USER
read -p "Please enter your MySQL password: " MYSQL_PASSWORD
read -p "Please enter your database name: " MYSQL_DATABASE
while true; do
    read -p "Please enter your app context (prod or dev): " APP_CONTEXT
    if [ "${APP_CONTEXT}" == "prod" ] || [ "${APP_CONTEXT}" == "dev" ]; then
        # If the context is valid, break the loop and continue with the rest of your script
        break
    else
        echo "Invalid app context. Please enter either the word prod or dev."
    fi
done

read -p "What Timezone to use? (default Europe/Paris) " TIMEZONE
if [ -z "${TIMEZONE}" ]
  then
    TIMEZONE=Europe/Paris
fi


while true; do
    read -p "Is there a proxy in your network ? (yes/no) " PROXY_ANSWER;
    if [ "${PROXY_ANSWER}" == "yes" ] || [ "${PROXY_ANSWER}" == "no" ]; then 
      break;
    else
        echo "Please answer yes or no";
    fi
done

if [ "${PROXY_ANSWER}" == "yes" ]
  then
    read -p "Please enter your proxy address(default will be 'http://10.0.0.1'): " PROXY_ADDRESS
      if [ -z "${PROXY_ADDRESS}" ]
        then
        PROXY_ADDRESS="http://10.0.0.1"
      fi
    read -p "Please enter your proxy port(default will be '80'): " PROXY_PORT
      if [ -z "${PROXY_PORT}" ]
        then
        PROXY_PORT="80"
      fi
    PROXY_ENV="      http_proxy: ${PROXY_ADDRESS}:${PROXY_PORT}"
    PROXY_DOCKERFILE="ENV http_proxy=\'${PROXY_ADDRESS}:${PROXY_PORT}\'"
    sed -i "3s|.*|$PROXY_DOCKERFILE|" docker/dockerfile/Dockerfile
fi

# Generate a new secret key
APP_SECRET=$(openssl rand -hex 16)

# Create docker-compose.override.yml file to use the good entrypoint
cat > docker-compose.override.yml <<EOL
version: '3.8'

services:
  webefnc:
    image: ghcr.io/polangres/efnc:main
    restart: unless-stopped 
    entrypoint: "./${APP_CONTEXT}-entrypoint.sh"
    environment:
${PROXY_ENV}
      APP_TIMEZONE: "${TIMEZONE}"
    volumes:
      - ./:/var/www
    labels:
      - traefik.enable=true
      - traefik.http.routers.webefnc.rule=PathPrefix(\`/efnc\`)
      - traefik.http.routers.webefnc.middlewares=strip-webefnc-prefix
      - traefik.http.middlewares.strip-webefnc-prefix.stripprefix.prefixes=/efnc
      - traefik.http.routers.webefnc.entrypoints=web
    depends_on:
      - database
    networks:
      vpcbr:
        ipv4_address: 172.22.0.4
EOL

# Change the src/Kernel.php to set the good timezone.
cat > src/Kernel.php <<EOL
<?php

namespace App;

use Symfony\Bundle\FrameworkBundle\Kernel\MicroKernelTrait;
use Symfony\Component\HttpKernel\Kernel as BaseKernel;

class Kernel extends BaseKernel
{
    use MicroKernelTrait;

    public function boot(): void
    {
        parent::boot();
        date_default_timezone_set("${TIMEZONE}");
    }
}
EOL

# Create .env file
cat > .env <<EOL
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=${MYSQL_DATABASE}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASSWORD}
HOSTNAME=${HOSTNAME}

###> symfony/framework-bundle ###
APP_ENV=${APP_CONTEXT}
APP_SECRET=${APP_SECRET}
###< symfony/framework-bundle ###

###> symfony/webapp-pack ###
MESSENGER_TRANSPORT_DSN=doctrine://default?auto_setup=0
###< symfony/webapp-pack ###

###> doctrine/doctrine-bundle ###
# Format described at https://www.doctrine-project.org/projects/doctrine-dbal/en/latest/reference/configuration.html#connecting-using-a-url
# IMPORTANT: You MUST configure your server version, either here or in config/packages/doctrine.yaml
#
# DATABASE_URL="sqlite:///%kernel.project_dir%/var/data.db"
# DATABASE_URL="mysql://app:!ChangeMe!@127.0.0.1:3306/app?serverVersion=8&charset=utf8mb4"

DATABASE_URL=mysql://root:\${MYSQL_ROOT_PASSWORD}@database/\${MYSQL_DATABASE}?serverVersion=MariaDB-10.11.4

###< doctrine/doctrine-bundle ###

###> symfony/messenger ###
# Choose one of the transports below
# MESSENGER_TRANSPORT_DSN=doctrine://default
# MESSENGER_TRANSPORT_DSN=amqp://guest:guest@localhost:5672/%2f/messages
# MESSENGER_TRANSPORT_DSN=redis://localhost:6379/messages
###< symfony/messenger ###

###> symfony/mailer ###
MAILER_DSN=smtp://smtp.corp.ponet:25?verify_peer=0
###< symfony/mailer ###
EOL


echo ".env file created successfully!"

if [ "${APP_CONTEXT}" == "prod" ]
  then

APP_CONTEXT="dev"
sed -i "s|^APP_ENV=prod.*|APP_ENV=dev|" .env
sed -i "s|^# MAILER_DSN=.*|MAILER_DSN=smtp://smtp.corp.ponet:25?verify_peer=0|" .env

# Create docker-compose.override.yml file to use the good entrypoint
cat > docker-compose.override.yml <<EOL
version: '3.8'

services:
  web:
    image: ghcr.io/polangres/efnc:main
    restart: unless-stopped 
    entrypoint: "./${APP_CONTEXT}-entrypoint.sh"
    environment:
${PROXY_ENV}
      APP_TIMEZONE: "${TIMEZONE}"
    volumes:
      - ./:/var/www
    labels:
      - traefik.enable=true
      - traefik.http.routers.webefnc.rule=PathPrefix(\`/efnc\`)
      - traefik.http.routers.webefnc.middlewares=strip-webefnc-prefix
      - traefik.http.middlewares.strip-webefnc-prefix.stripprefix.prefixes=/efnc
      - traefik.http.routers.webefnc.entrypoints=web
    depends_on:
      - database
    networks:
      vpcbr:
        ipv4_address: 172.22.0.4
EOL


sg docker -c "docker compose up --build -d"

sleep 90

sg docker -c "docker compose stop"

sleep 30

sed -i "s|^APP_ENV=dev.*|APP_ENV=prod|" .env
APP_CONTEXT="prod"


# Create docker-compose.override.yml file to use the good entrypoint
cat > docker-compose.override.yml <<EOL
version: '3.8'

services:
  web:
    image: ghcr.io/polangres/efnc:main
    restart: unless-stopped 
    entrypoint: "./${APP_CONTEXT}-entrypoint.sh"
    environment:
${PROXY_ENV}
      APP_TIMEZONE: "${TIMEZONE}"
    volumes:
      - ./:/var/www
    labels:
      - traefik.enable=true
      - traefik.http.routers.webefnc.rule=PathPrefix(\`/efnc\`)
      - traefik.http.routers.webefnc.middlewares=strip-webefnc-prefix
      - traefik.http.middlewares.strip-webefnc-prefix.stripprefix.prefixes=/efnc
      - traefik.http.routers.webefnc.entrypoints=web
    depends_on:
      - database
    networks:
      vpcbr:
        ipv4_address: 172.22.0.4
EOL

fi
