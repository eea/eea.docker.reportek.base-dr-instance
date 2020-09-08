#!/opt/zope/bin/zopepy

import os
import re
from shutil import copy


class Environment(object):
    """ Configure container via environment variables
    """
    def __init__(self, env=os.environ):
        self.env = env
        self.threads = self.env.get('ZOPE_THREADS', '')
        self.fast_listen = self.env.get('ZOPE_FAST_LISTEN', '')
        self.force_connection_close = self.env.get('ZOPE_FORCE_CONNECTION_CLOSE', '')
        self.zope_conf = '/opt/zope/parts/instance/etc/zope.conf'
        self.sentry = self.env.get('SENTRY', '')
        self.sentry_log_level = self.env.get('SENTRY_LOG_LEVEL', 'ERROR').upper()
        self.evt_log_level = self.env.get('EVENT_LOG_LEVEL', 'INFO').upper()
        self.access_log_level = self.env.get('ACCESS_LOG_LEVEL', 'WARN').upper()
        self.session_manager_timeout = self.env.get('SESSION_MANAGER_TIMEOUT', '')
        self._conf = ''

    @property
    def conf(self):
        """ Zope conf
        """
        if not self._conf:
            with open(self.zope_conf, 'r') as zfile:
                self._conf = zfile.read()
        return self._conf

    @conf.setter
    def conf(self, value):
        """ Zope conf
        """
        self._conf = value

    def log(self, msg='', *args):
        """ Log message to console
        """
        print msg % args

    def zeo_mode(self):
        """ ZEO Client
        """
        server = os.environ.get("ZEO_ADDRESS", None)

        if "<blobstorage>" not in self.conf or not server:
            return

        zeo_conf = ZEO_TEMPLATE.format(
            zeo_address=server,
            read_only=os.environ.get('ZEO_READ_ONLY', 'false'),
            zeo_client_read_only_fallback=os.environ.get('ZEO_CLIENT_READ_ONLY_FALLBACK', 'false'),
            shared_blob_dir=os.environ.get('ZEO_SHARED_BLOB_DIR', 'off'),
            zeo_storage=os.environ.get('ZEO_STORAGE', '1'),
            zeo_client_cache_size=os.environ.get('ZEO_CLIENT_CACHE_SIZE', '128MB'),
            zeo_client_blob_cache_size=os.environ.get('ZEO_CLIENT_BLOB_CACHE_SIZE', '500000000')
        )

        pattern = re.compile(r"<blobstorage>.+</blobstorage>", re.DOTALL)
        self.conf = re.sub(pattern, zeo_conf, self.conf)

    def zeo_temp_storage(self):
        """ Use a tempstorage from zeo server
        """
        server = os.environ.get("ZEO_ADDRESS", None)
        zeo_temp_storage = os.environ.get('ZEO_TEMP_STORAGE', 'temp')
        if "<zodb_db temporary>" not in self.conf or not server or not zeo_temp_storage:
            return
        zodb_temp = ZODB_TEMP_STORAGE_TEMPLATE.format(
            zeo_address=server,
            zeo_temp_storage=zeo_temp_storage,
            zeo_client_cache_size=os.environ.get('ZEO_CLIENT_CACHE_SIZE', '128MB'),
        )
        pattern = re.compile(r"<zodb_db temporary>.+</zodb_db>", re.DOTALL)
        self.conf = re.sub(pattern, zodb_temp, self.conf)

    def zope_log(self):
        """ Zope logging
        """
        if not self.sentry:
            return

        if 'raven.contrib.zope' in self.conf:
            self.log('Sending logs to sentry: %s', self.sentry)
            return

        if self.sentry:
            self.log("Sending logs to sentry: '%s'", self.sentry)
            sentry_tmpl = SENTRY_TEMPLATE % (self.sentry, self.sentry_log_level)
            self.conf = "%import raven.contrib.zope\n" + self.conf.replace('</eventlog>', "%s</eventlog>" % sentry_tmpl)

    def zope_log_level(self):
        """ Zope log level
        """
        def handle_log_level(l_type):
            log_sect_start = self.conf.index('<%s' % l_type)
            log_sect_stop = self.conf.index('</%s' % l_type)
            log_fragment = self.conf[log_sect_start:log_sect_stop]
            new_log_fragment = []
            log = {
                'eventlog': self.evt_log_level,
                'logger': self.access_log_level
            }
            sentry = False
            for line in log_fragment.split('\n'):
                if '<sentry>' in line:
                    sentry = True
                elif '</sentry>' in line:
                    sentry = False
                if 'level ' in line and line.split('level')[1].lstrip() != log.get(l_type) and not sentry:
                    line = 'level'.join([line.split('level')[0], ' %s' % log.get(l_type)])
                new_log_fragment.append(line)
            self.conf = self.conf.replace(log_fragment, '\n'.join(new_log_fragment))

        handle_log_level('eventlog')
        handle_log_level('logger')

    def zope_threads(self):
        """ Zope threads
        """
        if not self.threads:
            return

        self.conf = self.conf.replace('zserver-threads 2', 'zserver-threads %s' % self.threads)

    def zope_fast_listen(self):
        """ Zope fast-listen
        """
        if not self.fast_listen or self.fast_listen == 'off':
            return

        self.conf = self.conf.replace('fast-listen off', 'fast-listen %s' % self.fast_listen)

    def zope_force_connection_close(self):
        """ force-connection-close
        """
        if not self.force_connection_close or self.force_connection_close == 'on':
            return

        self.conf = self.conf.replace(
            'force-connection-close on', 'force-connection-close %s' % self.force_connection_close)

    def zope_session_timeout_minutes(self):
        """ session-timeout-minutes
        """
        if not self.session_manager_timeout:
            return
        zst = 'session-timeout-minutes %s' % self.session_manager_timeout

        if 'session-timeout-minutes' in self.conf:
            pattern = re.compile(r"session-timeout-minutes.+$", re.MULTILINE)
            re.sub(pattern, zst, self.conf)
        else:
            self.conf = '\n'.join([self.conf, zst])

    def finish(self):
        conf = self.conf
        with open(self.zope_conf, 'w') as zfile:
            zfile.write(conf)

    def setup(self):
        """ Configure
        """
        self.zeo_mode()
        self.zeo_temp_storage()
        self.zope_log()
        self.zope_log_level()
        self.zope_threads()
        self.zope_fast_listen()
        self.zope_force_connection_close()
        self.zope_session_timeout_minutes()
        self.finish()

    __call__ = setup


SENTRY_TEMPLATE = """
    <sentry>
      dsn %s
      level %s
    </sentry>
"""

ZEO_TEMPLATE = """
    <zeoclient>
      read-only {read_only}
      read-only-fallback {zeo_client_read_only_fallback}
      blob-dir /opt/zope/var/blobstorage
      shared-blob-dir {shared_blob_dir}
      server {zeo_address}
      storage {zeo_storage}
      name zeostorage
      var /opt/zope/parts/instance/var
      cache-size {zeo_client_cache_size}
      blob-cache-size {zeo_client_blob_cache_size}
    </zeoclient>
""".strip()

ZODB_TEMP_STORAGE_TEMPLATE = """
    <zodb_db temporary>
        mount-point /temp_folder
        cache-size 10000
        container-class Products.TemporaryFolder.TemporaryContainer
      <zeoclient>
          server {zeo_address}
          storage {zeo_temp_storage}
          var /opt/zope/parts/instance/var
          cache-size {zeo_client_cache_size}
      </zeoclient>
     </zodb_db>
""".strip()

def initialize():
    """ Configure
    """
    environment = Environment()
    environment.setup()


if __name__ == "__main__":
    initialize()
