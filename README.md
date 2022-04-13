# Zope w/ Eionet Data Repository Add-ons ready to run Docker image

Docker base image for Zope with Eionet Data Repository specific Add-ons and settings available.

### Supported tags and respective Dockerfile links

  - `:latest` (default)

### Base docker image

 - [hub.docker.com](https://hub.docker.com/r/eeacms/reportek-base-dr/)

### Source code

  - [github.com](http://github.com/eea/eea.docker.reportek.base-dr-instance)

### Installation

1. Install [Docker](https://www.docker.com/)

2. Install [Docker Compose](https://docs.docker.com/compose/) (optional)

## Usage

See [eeacms/zope](https://hub.docker.com/r/eeacms/zope)

## Upgrade

    $ docker pull eeacms/reportek-base-dr

## Supported environment variables

On top of the environment variables supported by the base [eeacms/zope](https://hub.docker.com/r/eeacms/zope) image, you can also use the following variables which won't trigger a re-run of the buildout process:
- `ZOPE_THREADS` - default `2`
- `ZOPE_FAST_LISTEN` - default `off`
- `GRAYLOG` - format `<hostname_or_ip>:<port>`
- `GRAYLOG_FACILITY`

- `ZOPE_FORCE_CONNECTION_CLOSE` - default `on`
- `SESSION_MANAGER_TIMEOUT` - in minutes
- `ZEO_ADDRESS` - format `<hostname_or_ip>:<port>`
- `ZEO_READ_ONLY` - default `false`
- `ZEO_CLIENT_READ_ONLY_FALLBACK` - default `false`
- `ZEO_SHARED_BLOB_DIR` - default `off`
- `ZEO_STORAGE` - default `1`
- `ZEO_CLIENT_CACHE_SIZE` - default `128MB`
- `ZEO_CLIENT_BLOB_CACHE_SIZE` - default `500000000` in bytes
- `EVENT_LOG_LEVEL` - default `INFO`
- `ACCESS_LOG_LEVEL` - default `WARN`
- `SENTRY` - format `'<PROTOCOL>://<PUBLIC_KEY>:<SECRET_KEY>@<HOST>/<PATH><PROJECT_ID>'`
- `SENTRY_LOG_LEVEL` - default `ERROR`
- `ZIP_CACHE_ENABLED` - default `true`
- `ZIP_CACHE_THRESHOLD` - default `100000000` in bytes
- `ZIP_CACHE_PATH` - default `/opt/zope/var/instance/zip_cache`

## Copyright and license

The Initial Owner of the Original Code is European Environment Agency (EEA).
All Rights Reserved.

The Original Code is free software;
you can redistribute it and/or modify it under the terms of the GNU
General Public License as published by the Free Software Foundation;
either version 2 of the License, or (at your option) any later
version.

## Funding

[European Environment Agency (EU)](http://eea.europa.eu)


