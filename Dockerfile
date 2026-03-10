# syntax=docker/dockerfile:1
# Docker Hardened Images (DHI) - Requires: docker login dhi.io
# See: https://docs.docker.com/dhi/

ARG PYTHON_VERSION=3.12
ARG DEBIAN_VERSION=debian13

# ============================================================================
# Builder Stage - Uses -dev variant with build tools
# ============================================================================
FROM dhi.io/python:${PYTHON_VERSION}-${DEBIAN_VERSION}-dev AS builder

COPY --from=dhi.io/uv:0 /uv /usr/local/bin/uv

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    UV_COMPILE_BYTECODE=1 \
    ZOPE_HOME=/opt/zope \
    ZOPE_UID=1000 \
    ZOPE_GID=1000

ENV ZIP_CACHE_PATH=${ZOPE_HOME}/var

# Install build dependencies (including passwd for user management)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    libldap2-dev \
    libmagic1 \
    libsasl2-dev \
    wget \
    zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN uv venv $ZOPE_HOME

# Copy and install requirements
COPY requirements.txt $ZOPE_HOME/
RUN uv pip install --python=$ZOPE_HOME/bin/python -r $ZOPE_HOME/requirements.txt && \
    # Patch PlonePAS to use Image.LANCZOS instead of Image.ANTIALIAS (removed in recent versions of Pillow)
    sed -i 's/Image\.ANTIALIAS/Image.LANCZOS/g' \
        $ZOPE_HOME/lib/python3.12/site-packages/Products/PlonePAS/config.py && \
    # Patch pas.plugins.ldap to close the <link>
    sed -i 's|></link>|/>|g' \
        $ZOPE_HOME/lib/python3.12/site-packages/pas/plugins/ldap/zmi/manage_plugin.pt

# Clone and install Products.Reportek from git
RUN git clone --branch wip_migration_to_zope4_5_py3 --single-branch \
    https://github.com/eea/Products.Reportek.git $ZOPE_HOME/src/Products.Reportek && \
    rm -rf $ZOPE_HOME/src/Products.Reportek/.git && \
    uv pip install --python=$ZOPE_HOME/bin/python -e $ZOPE_HOME/src/Products.Reportek

# Create directory structure
RUN mkdir -p $ZOPE_HOME/etc \
    $ZOPE_HOME/var/filestorage \
    $ZOPE_HOME/var/blobstorage \
    $ZOPE_HOME/var/cache \
    $ZOPE_HOME/var/log

# Copy configuration files
COPY src/zope.ini $ZOPE_HOME/etc/
COPY src/zope.conf $ZOPE_HOME/etc/
COPY src/site.zcml $ZOPE_HOME/etc/

# Pre-compile translation files
ENV zope_i18n_compile_mo_files=true

# ============================================================================
# Runtime Stage - Uses -dev variant (runtime variant has no shell)
# ============================================================================
FROM dhi.io/python:${PYTHON_VERSION}-${DEBIAN_VERSION}-dev AS runtime

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    ZOPE_HOME=/opt/zope \
    ZOPE_UID=1000 \
    ZOPE_GID=1000

ENV ZIP_CACHE_PATH=${ZOPE_HOME}/var

# Install runtime dependencies (including passwd for user management)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    cron \
    gosu \
    libldap2 \
    libmagic1 \
    libsasl2-2 \
    poppler-utils \
    procps \
    wv && \
    rm -rf /var/lib/apt/lists/*

# Create user after installing passwd package
RUN groupadd -g ${ZOPE_GID} zope-www && \
    useradd -g ${ZOPE_GID} -u ${ZOPE_UID} -m -s /bin/bash zope-www

# Configure OpenLDAP
RUN mkdir -p /etc/ldap && \
    echo "TLS_CACERT /etc/ssl/certs/ca-certificates.crt" > /etc/ldap/ldap.conf && \
    echo "REFERRALS off" >> /etc/ldap/ldap.conf

# Copy installation from builder
COPY --from=builder --chown=${ZOPE_UID}:${ZOPE_GID} $ZOPE_HOME $ZOPE_HOME

# Copy entrypoint
COPY src/docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

# Environment
ENV zope_i18n_compile_mo_files=true \
    ZOPE_HOME=/opt/zope

WORKDIR $ZOPE_HOME
EXPOSE 8080

HEALTHCHECK --interval=1m --timeout=5s --start-period=1m \
    CMD nc -z -w5 127.0.0.1 8080 || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]

USER zope-www
