# ============================================================
# SuiteCRM Docker Image
# Repo: https://github.com/1899nils/kw-suitecrm
# ============================================================
# Um die Version zu aktualisieren, nur SUITECRM_VERSION ändern
# und einen neuen Commit pushen – GitHub Actions baut automatisch.
# ============================================================

ARG SUITECRM_VERSION=8.7.1

FROM php:8.2-apache

ARG SUITECRM_VERSION
ENV SUITECRM_VERSION=${SUITECRM_VERSION}
ENV TZ=Europe/Berlin

LABEL org.opencontainers.image.source="https://github.com/1899nils/kw-suitecrm"
LABEL org.opencontainers.image.description="SuiteCRM ${SUITECRM_VERSION} auf PHP 8.2 Apache"
LABEL org.opencontainers.image.licenses="AGPL-3.0"

# Zeitzone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# System-Pakete
RUN apt-get update && apt-get install -y --no-install-recommends \
    cron \
    openssl \
    unzip \
    zip \
    curl \
    libicu-dev \
    libcurl4-openssl-dev \
    libmagickwand-dev \
    libpng-dev \
    libzip-dev \
    libxml2-dev \
    libbz2-dev \
    libonig-dev \
    libgmp-dev \
    libldap2-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    && rm -rf /var/lib/apt/lists/*

# PHP Extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
        pdo_mysql \
        mysqli \
        gd \
        curl \
        zip \
        xml \
        mbstring \
        bz2 \
        intl \
        gmp \
        opcache \
        soap \
        ldap \
        bcmath \
        exif

# ImageMagick
RUN pecl install imagick && docker-php-ext-enable imagick

# Apache Module
RUN a2enmod rewrite headers expires deflate

# Konfiguration
COPY conf/apache/vhost.conf      /etc/apache2/sites-available/000-default.conf
COPY conf/apache/security.conf   /etc/apache2/conf-available/suitecrm-security.conf
RUN a2enconf suitecrm-security
COPY conf/php/suitecrm.ini       /usr/local/etc/php/conf.d/suitecrm.ini

# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /var/www/html
EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
