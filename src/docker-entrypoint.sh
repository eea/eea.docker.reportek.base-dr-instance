#!/bin/bash
set -e

# ============================================================================
# Docker Entrypoint for Reportek Zope Instance
# ============================================================================

ZOPE_HOME=${ZOPE_HOME:-/opt/zope}
ZOPE_USER=${ZOPE_USER:-zope-www}
ZOPE_UID=${ZOPE_UID:-1000}
ZOPE_GID=${ZOPE_GID:-1000}

# ============================================================================
# Helper Functions
# ============================================================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

# ============================================================================
# User/Permission Setup
# ============================================================================

setup_permissions() {
    log "Setting up permissions for UID:GID = $ZOPE_UID:$ZOPE_GID"

    # Only attempt to modify users and chown if running as root
    if [ "$(id -u)" = "0" ]; then
        # Update user/group IDs if needed
        if [ "$(id -u $ZOPE_USER)" != "$ZOPE_UID" ]; then
            usermod -u $ZOPE_UID $ZOPE_USER 2>/dev/null || true
        fi

        if [ "$(id -g $ZOPE_USER)" != "$ZOPE_GID" ]; then
            groupmod -g $ZOPE_GID zope-www 2>/dev/null || true
        fi

        # Ensure proper ownership of var directory
        chown -R $ZOPE_UID:$ZOPE_GID $ZOPE_HOME/var
    else
        log "Running as non-root user. Skipping usermod and chown."
    fi
}

# ============================================================================
# Admin User Setup
# ============================================================================

setup_admin_user() {
    local admin_user=${ZOPE_ADMIN_USER:-admin}
    local admin_pass=${ZOPE_ADMIN_PASSWORD:-admin}
    local inituser_file="$ZOPE_HOME/var/inituser"

    if [ ! -f "$inituser_file" ]; then
        log "Creating initial admin user: $admin_user"
        # Create inituser file with hashed password
        $ZOPE_HOME/bin/python -c "
from hashlib import sha1
import binascii
user = '$admin_user'
password = '$admin_pass'
hash = '{SHA}' + binascii.b2a_base64(sha1(password.encode()).digest()).decode().strip()
print(f'{user}:{hash}')
" > "$inituser_file"
        if [ "$(id -u)" = "0" ]; then
            chown $ZOPE_UID:$ZOPE_GID "$inituser_file"
        fi
    fi
}

# ============================================================================
# ZODB Setup
# ============================================================================

setup_zodb() {
    local zodb_conf="$ZOPE_HOME/etc/zodb.conf"
    local cache_size=${ZODB_CACHE_SIZE:-50000}
    local shared_blob_dir=${ZEO_SHARED_BLOB_DIR:-off}

    log "Generating ZODB configuration at $zodb_conf"

    if [ -n "$RELSTORAGE_DSN" ]; then
        log "RELSTORAGE_DSN is set. Configuring RelStorage (PostgreSQL)..."
        cat <<EOF > "$zodb_conf"
<zodb_db main>
    cache-size $cache_size
    <relstorage>
        <postgresql>
            dsn $RELSTORAGE_DSN
        </postgresql>
        shared-blob-dir $shared_blob_dir
        blob-dir $ZOPE_HOME/var/blobstorage
    </relstorage>
    mount-point /
</zodb_db>
EOF
    elif [ -n "$ZEO_ADDRESS" ]; then
        log "ZEO_ADDRESS is set to $ZEO_ADDRESS. Configuring ZEO Client..."
        cat <<EOF > "$zodb_conf"
<zodb_db main>
    cache-size $cache_size
    <zeoclient>
        server $ZEO_ADDRESS
        storage 1
        name zeostorage
        var $ZOPE_HOME/var
        cache-size 128MB
        blob-dir $ZOPE_HOME/var/blobstorage
        shared-blob-dir $shared_blob_dir
    </zeoclient>
    mount-point /
</zodb_db>
EOF
    else
        log "Neither RELSTORAGE_DSN nor ZEO_ADDRESS set. Configuring local FileStorage..."
        cat <<EOF > "$zodb_conf"
<zodb_db main>
    cache-size $cache_size
    <filestorage>
        path $ZOPE_HOME/var/filestorage/Data.fs
        blob-dir $ZOPE_HOME/var/blobstorage
    </filestorage>
    mount-point /
</zodb_db>
EOF
    fi

    if [ "$(id -u)" = "0" ]; then
        chown $ZOPE_UID:$ZOPE_GID "$zodb_conf"
    fi
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
    local command=$1
    shift || true

    # Setup permissions
    setup_permissions

    # Setup admin user if needed
    setup_admin_user

    # Generate ZODB configuration dynamically based on env vars
    setup_zodb

    # Generate WSGI configuration dynamically based on env vars
    log "Setting Waitress threads to ${ZOPE_THREADS:-4}"
    sed -i "s/^threads = .*/threads = ${ZOPE_THREADS:-4}/g" "$ZOPE_HOME/etc/zope.ini"

    local event_log_level=${EVENT_LOG_LEVEL:-INFO}
    local access_log_level=${ACCESS_LOG_LEVEL:-WARN}
    log "Setting EVENT_LOG_LEVEL to $event_log_level and ACCESS_LOG_LEVEL to $access_log_level"
    sed -i "s/^level = EVENT_LOG_LEVEL_MARKER/level = $event_log_level/g" "$ZOPE_HOME/etc/zope.ini"
    sed -i "s/^level = ACCESS_LOG_LEVEL_MARKER/level = $access_log_level/g" "$ZOPE_HOME/etc/zope.ini"

    # Generate Zope configuration dynamically based on env vars
    local zope_debug_mode=${ZOPE_DEBUG_MODE:-off}
    local zope_verbose_security=${ZOPE_VERBOSE_SECURITY:-off}
    log "Setting debug-mode to $zope_debug_mode and verbose-security to $zope_verbose_security"
    sed -i "s/^debug-mode DEBUG_MODE_MARKER/debug-mode $zope_debug_mode/g" "$ZOPE_HOME/etc/zope.conf"
    sed -i "s/^verbose-security VERBOSE_SECURITY_MARKER/verbose-security $zope_verbose_security/g" "$ZOPE_HOME/etc/zope.conf"

    case "$command" in
        start|fg)
            log "Starting Zope instance"
            if [ "$(id -u)" = "0" ]; then
                exec gosu $ZOPE_USER $ZOPE_HOME/bin/runwsgi $ZOPE_HOME/etc/zope.ini
            else
                exec $ZOPE_HOME/bin/runwsgi $ZOPE_HOME/etc/zope.ini
            fi
            ;;

        console)
            log "Starting Zope console"
            if [ "$(id -u)" = "0" ]; then
                exec gosu $ZOPE_USER $ZOPE_HOME/bin/zconsole debug $ZOPE_HOME/etc/zope.conf "$@"
            else
                exec $ZOPE_HOME/bin/zconsole debug $ZOPE_HOME/etc/zope.conf "$@"
            fi
            ;;

        debug)
            log "Starting Zope in debug mode"
            if [ "$(id -u)" = "0" ]; then
                exec gosu $ZOPE_USER $ZOPE_HOME/bin/zconsole debug $ZOPE_HOME/etc/zope.conf "$@"
            else
                exec $ZOPE_HOME/bin/zconsole debug $ZOPE_HOME/etc/zope.conf "$@"
            fi
            ;;

        adduser)
            log "Adding Zope user"
            if [ "$(id -u)" = "0" ]; then
                exec gosu $ZOPE_USER $ZOPE_HOME/bin/addzopeuser "$@"
            else
                exec $ZOPE_HOME/bin/addzopeuser "$@"
            fi
            ;;

        test|tests)
            log "Running tests iteratively over modules in src/"
            # Handle testing dynamically replicating legacy bin/test loop sequences
            for i in $(ls $ZOPE_HOME/src); do
                # Auto exclude non-package directories representing backup folders or configs (hyphens are invalid in python imports)
                if [ ! -d "$ZOPE_HOME/src/$i" ] || [ ! -f "$ZOPE_HOME/src/$i/setup.py" ] || [[ "$i" == *"-"* ]]; then
                    echo "============================================================="
                    echo "Auto: Skipping tests for: $i                                 "
                    continue
                fi

                # Manual exclude tests
                if [ ! -z "$EXCLUDE" ] && [[ $EXCLUDE == *"$i"* ]]; then
                    echo "============================================================="
                    echo "Manual: Skipping tests for: $i                               "
                    continue
                fi

                echo "============================================================="
                echo "Running tests for:                                           "
                echo "                                                             "
                echo "    $i                                                       "
                echo "                                                             "

                if [ "$(id -u)" = "0" ]; then
                    gosu $ZOPE_USER $ZOPE_HOME/bin/zope-testrunner --test-path $ZOPE_HOME/src/$i -v -vv -s $i || true
                else
                    $ZOPE_HOME/bin/zope-testrunner --test-path $ZOPE_HOME/src/$i -v -vv -s $i || true
                fi
            done
            ;;

        coverage)
            TARGET_PKG="${GIT_NAME:-Products.Reportek}"
            log "Running coverage tracking exclusively over $TARGET_PKG"
            cd $ZOPE_HOME/src/$TARGET_PKG
            if [ "$(id -u)" = "0" ]; then
                gosu $ZOPE_USER $ZOPE_HOME/bin/coverage run $ZOPE_HOME/bin/zope-testrunner --test-path $(pwd) -v -vv -s $TARGET_PKG --xml=$(pwd)
                gosu $ZOPE_USER $ZOPE_HOME/bin/coverage xml -i --include="*/$TARGET_PKG/*"
            else
                $ZOPE_HOME/bin/coverage run $ZOPE_HOME/bin/zope-testrunner --test-path $(pwd) -v -vv -s $TARGET_PKG --xml=$(pwd)
                $ZOPE_HOME/bin/coverage xml -i --include="*/$TARGET_PKG/*"
            fi
            exit 0
            ;;

        zopepy|python)
            log "Starting Python interpreter"
            if [ "$(id -u)" = "0" ]; then
                exec gosu $ZOPE_USER $ZOPE_HOME/bin/python "$@"
            else
                exec $ZOPE_HOME/bin/python "$@"
            fi
            ;;

        shell|bash)
            log "Starting bash shell as $ZOPE_USER"
            if [ "$(id -u)" = "0" ]; then
                exec gosu $ZOPE_USER /bin/bash "$@"
            else
                exec /bin/bash "$@"
            fi
            ;;

        help|--help|-h)
            cat <<EOF
Reportek Zope Docker Container

Usage: docker run [options] reportek [command]

Commands:
  start       Start Zope (default)
  fg          Start Zope in foreground mode (same as start)
  console     Start Zope debug console
  debug       Start Zope debugger
  adduser     Add a Zope user
  test|tests  Execute Zope tests iterating over modules in src/
  coverage    Run explicitly tracked coverage metrics parsing Products.Reportek
  python      Run Python interpreter
  shell       Start bash shell as zope user
  help        Show this help message

Environment Variables:
  ZOPE_HOME            Zope installation directory (default: /opt/zope)
  ZOPE_USER            User to run Zope as (default: zope-www)
  ZOPE_UID             UID for Zope user (default: 1000)
  ZOPE_GID             GID for Zope group (default: 1000)
  ZOPE_ADMIN_USER      Admin username (default: admin)
  ZOPE_ADMIN_PASSWORD  Admin password (default: admin)

Examples:
  docker run reportek start
  docker run reportek console
  docker run reportek python myscript.py
  docker run reportek shell

EOF
            ;;

        *)
            if [ -n "$command" ]; then
                log "Running custom command: $command $*"
                if [ "$(id -u)" = "0" ]; then
                    exec gosu $ZOPE_USER "$command" "$@"
                else
                    exec "$command" "$@"
                fi
            else
                log "No command specified, starting Zope"
                if [ "$(id -u)" = "0" ]; then
                    exec gosu $ZOPE_USER $ZOPE_HOME/bin/runwsgi $ZOPE_HOME/etc/zope.ini
                else
                    exec $ZOPE_HOME/bin/runwsgi $ZOPE_HOME/etc/zope.ini
                fi
            fi
            ;;
    esac
}

# Run main function with all arguments
main "$@"
