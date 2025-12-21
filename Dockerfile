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
RUN mkdir /extensions
WORKDIR /extensions

# Create welcome message
RUN echo '#!/bin/bash\n\
echo "================================================="\n\
echo "PHP Extension Development Environment"\n\
echo "================================================="\n\
echo ""\n\
echo "Available commands:"\n\
echo "  - create_skeleton <extension_name> [extension_dir]: Create a PHP extension skeleton"\n\
echo ""\n\
echo "Current PHP version:"\n\
php -v | head -n1\n\
echo ""\n\
echo "php.ini location:"\n\
echo $PHP_PREFIX/DEBUG/etc/php.ini\n\
echo ""\n\
echo "Working directory: /extensions"\n\
echo ""\n\
echo "Happy extension development!"\n\
echo "================================================="\n\
' > /usr/local/bin/welcome \
    && chmod +x /usr/local/bin/welcome

# Create create_skeleton script
RUN echo '#!/bin/bash\n\
echo "================================================="\n\
echo "PHP Extension Development Environment - create_skeleton"\n\
echo "================================================="\n\
echo ""\n\
echo "================================================="\n\
echo "Creating PHP extension skeleton..."\n\
echo ""\n\
if [ -z "$1" ]; then\n\
	echo "Extension name required. Usage: create_skeleton <extension_name> [extension_dir]" \n\
	exit 1\n\
fi\n\
EXTENSION_NAME="$1"\n\
EXTENSION_DIR="$2"\n\
if [ -z "$EXTENSION_DIR" ]; then\n\
	EXTENSION_DIR="/extensions/$EXTENSION_NAME"\n\
fi\n\
mkdir -p "$EXTENSION_DIR"\n\
php /usr/src/php-src/ext/ext_skel.php --ext "$EXTENSION_NAME" --dir "$EXTENSION_DIR"\n\
echo "Extension skeleton created at $EXTENSION_DIR"\n\
echo "================================================="\n\
' > /usr/local/bin/create_skeleton \
    && chmod +x /usr/local/bin/create_skeleton


CMD [ "/bin/bash" ]

RUN echo "welcome" >> /etc/bash.bashrc
