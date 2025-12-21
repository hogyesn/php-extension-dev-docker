FROM debian:bookworm-slim

ARG PHP_VERSION=8.3.0

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages for building PHP from source
RUN apt-get update && apt-get install -y \
    build-essential \
    autoconf \
    automake \
    bison \
    flex \
    re2c \
    gdb \
    libtool \
    make \
    pkgconf \
    valgrind \
    git \
    libxml2-dev \
    libsqlite3-dev

ENV PHP_PREFIX=/usr/local/php-bin

WORKDIR /usr/src
# clone PHP source code
RUN git clone https://github.com/php/php-src.git
WORKDIR /usr/src/php-src
# checkout the specified PHP version
RUN git checkout "PHP-${PHP_VERSION}"

# Build and install PHP with debug symbols
RUN ./buildconf --force
RUN ./configure --enable-debug \
    --prefix=$PHP_PREFIX/DEBUG \
    --with-config-file-path=$PHP_PREFIX/DEBUG/etc

# Compile and install PHP
RUN make -j"$(nproc)"
RUN make install
# Create a php.ini file
RUN mkdir -p $PHP_PREFIX/DEBUG/etc
RUN touch $PHP_PREFIX/DEBUG/etc/php.ini

# Update PATH environment variable
ENV PATH="$PHP_PREFIX/DEBUG/bin:$PATH"

# Verify the installation
RUN php -v

# Set the working directory
WORKDIR /workspace

CMD [ "/bin/bash" ]

