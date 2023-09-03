FROM php:8.1-apache

# Install PHP extensions and PECL modules.
RUN buildDeps=" \
        libbz2-dev \
        libmariadb-dev \
        libcurl4-gnutls-dev \
    " \
    runtimeDeps=" \
        apt-utils \
        libfreetype6-dev \
        libicu-dev \
        libjpeg-dev \
        libmcrypt-dev \
        libpng-dev \
        libpq-dev \
        libonig-dev \
        default-mysql-client \
        libzip-dev \
        unzip \
        vim \
        nano \
    " \
    && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y $buildDeps $runtimeDeps

RUN apt-get install -y libmagickwand-dev --no-install-recommends
RUN docker-php-ext-install bz2 calendar iconv intl mysqli pdo_pgsql  pgsql pdo pdo_mysql curl mbstring xml dom bcmath zip
RUN docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/  \
    && docker-php-ext-install gd

RUN printf "\n" | pecl install imagick \
    && docker-php-ext-enable imagick \
    && pecl install mcrypt-1.0.5 \
    && docker-php-ext-enable mcrypt

RUN ln -s /usr/bin/mysqldump /usr/local/bin/mysqldump \
    && apt-get purge -y --auto-remove $buildDeps \
    && apt-get clean -y \
    && rm -r /var/lib/apt/lists/*

RUN a2enmod rewrite \
    && a2enmod headers \
    && a2enmod ssl \
    && service apache2 restart

# Install Composer (optionnal)
ENV COMPOSER_HOME /root/composer 
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
ENV PATH $COMPOSER_HOME/vendor/bin:$PATH

# Npm Setup
RUN apt-get update && \
    apt-get install -y npm && \
    npm install -g n && \
    n stable && \
    ln -sf /usr/local/bin/node /usr/bin/nodejs

## Copy php.ini over
COPY ./config/php.ini /usr/local/etc/php/php.ini
COPY ./config/apache2.conf /etc/apache2/apache2.conf
COPY ./config/dir.conf /etc/apache2/mods-available/dir.conf
COPY ./config/live/ /etc/letsencrypt/live/
COPY ./config/options-ssl-apache.conf /etc/letsencrypt/options-ssl-apache.conf
COPY ./config/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf
COPY ./config/default-ssl.conf /etc/apache2/sites-enabled/default-ssl.conf


EXPOSE 30001
EXPOSE 30002

# Create new user for web for html folder access only
RUN useradd -ms /bin/bash web
RUN chown -R web:web /var/www/html \
    && chmod -R 777 /var/www/html \
    && mkdir /var/www/backup

## Cleanup
RUN rm -rf /tmp/*