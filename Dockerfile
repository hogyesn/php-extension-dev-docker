FROM debian:bookworm-slim

ARG PHP_VERSION=8.3.0
ENV PHP_VERSION=${PHP_VERSION}

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
    libsqlite3-dev \
    wget \
    curl \
    gdbserver

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
RUN make clean
RUN make -j"$(nproc)"
RUN make install
# Create a php.ini file
RUN mkdir -p $PHP_PREFIX/DEBUG/etc
RUN touch $PHP_PREFIX/DEBUG/etc/php.ini

# Update PATH environment variable
ENV PATH="$PHP_PREFIX/DEBUG/bin:$PATH"

# Verify the installation
RUN php -v

RUN mkdir /debug_scripts

# Set the working directory
RUN mkdir /extensions
WORKDIR /extensions

# Create welcome message
COPY scripts/welcome /usr/local/bin/welcome
RUN chmod +x /usr/local/bin/welcome

# Create create_skeleton script
COPY scripts/create_skeleton /usr/local/bin/create_skeleton
RUN chmod +x /usr/local/bin/create_skeleton

# Build and test the extension
COPY scripts/build_extension /usr/local/bin/build_extension
RUN chmod +x /usr/local/bin/build_extension

# Create debug_extension script
COPY scripts/debug_extension /usr/local/bin/debug_extension
RUN chmod +x /usr/local/bin/debug_extension

# Create debug PHP script
COPY scripts/create_debug_script /usr/local/bin/create_debug_script
RUN chmod +x /usr/local/bin/create_debug_script

CMD [ "/bin/bash" ]

RUN echo "welcome" >> /etc/bash.bashrc
