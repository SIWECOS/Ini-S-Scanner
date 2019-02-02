FROM php:7.1-apache

# Install packages
RUN apt-get update && apt-get install -y \
      libicu-dev \
      libpq-dev \
      libmcrypt-dev \
      git \
      zip \
      unzip \
      mysql-client \
      zlib1g-dev \
    && rm -r /var/lib/apt/lists/* \
    && docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd \
    && docker-php-ext-install \
      intl \
      mbstring \
      mcrypt \
      pcntl \
      pdo_mysql \
      pdo_pgsql \
      pgsql \
      zip \
      opcache

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Set our application folder as an environment variable
ENV APP_HOME /var/www/html

# Change uid and gid of apache to docker user uid/gid
RUN usermod -u 1000 www-data && groupmod -g 1000 www-data

# Change the web_root to laravel /var/www/html/public folder
RUN sed -i -e "s/html/html\/public/g" /etc/apache2/sites-enabled/000-default.conf

# Enable apache module rewrite
RUN a2enmod rewrite

# Copy source files
COPY . $APP_HOME

# Copy environment file
COPY .env $APP_HOME/.env

ADD php.ini /usr/local/etc/php

WORKDIR ${APP_HOME}

RUN composer install

# Change ownership of our applications
RUN chown -R www-data:www-data $APP_HOME

# Restart web server
RUN service apache2 restart

EXPOSE 80
