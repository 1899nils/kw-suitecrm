# ============================================================
# SuiteCRM 7 Docker Image (Legacy / Migration)
# Repo: https://github.com/1899nils/kw-suitecrm (branch: suite7)
# ============================================================
# Dieses Image basiert auf SuiteCRM 7.14.x und dient dazu, ein
# altes SuiteCRM-7-Backup wieder aufzunehmen. Spaeter kann von
# hier auf SuiteCRM 8 upgegradet werden.
# ============================================================

ARG SUITECRM_VERSION=7.14.6

FROM php:8.0-apache

ARG SUITECRM_VERSION
ENV SUITECRM_VERSION=${SUITECRM_VERSION}
ENV TZ=Europe/Berlin

LABEL org.opencontainers.image.source="https://github.com/1899nils/kw-suitecrm"
LABEL org.opencontainers.image.description="SuiteCRM ${SUITECRM_VERSION} (Legacy 7.x) auf PHP 8.0 Apache"
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

# PHP Extensions (Suite 7 braucht dieselben wie Suite 8)
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

# SuiteCRM 7 herunterladen – Baseline in /opt/suitecrm-source
RUN curl -fsSL \
    "https://github.com/salesagility/SuiteCRM/releases/download/v${SUITECRM_VERSION}/SuiteCRM-${SUITECRM_VERSION}.zip" \
    -o /tmp/suitecrm.zip \
    && unzip -q /tmp/suitecrm.zip -d /tmp/suitecrm_extract \
    && mkdir -p /opt/suitecrm-source \
    && if [ -f "/tmp/suitecrm_extract/install.php" ]; then \
         cp -r /tmp/suitecrm_extract/. /opt/suitecrm-source/; \
       else \
         SUBDIR=$(find /tmp/suitecrm_extract -maxdepth 2 -name "install.php" | head -1 | sed 's|/install.php||'); \
         cp -r "${SUBDIR}/." /opt/suitecrm-source/; \
       fi \
    && rm -rf /tmp/suitecrm.zip /tmp/suitecrm_extract \
    && test -f /opt/suitecrm-source/install.php || (echo "ERROR: install.php nicht gefunden!" && exit 1)

# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

WORKDIR /var/www/html
EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
