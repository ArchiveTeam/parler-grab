# encoding=utf8
import datetime
from distutils.version import StrictVersion
import hashlib
import os.path
import random
from seesaw.config import realize, NumberConfigValue
from seesaw.externalprocess import ExternalProcess
from seesaw.item import ItemInterpolation, ItemValue
from seesaw.task import SimpleTask, LimitConcurrent
from seesaw.tracker import GetItemFromTracker, PrepareStatsForTracker, \
    UploadWithTracker, SendDoneToTracker
import shutil
import socket
import subprocess
import sys
import time
import string

import seesaw
from seesaw.externalprocess import WgetDownload
from seesaw.pipeline import Pipeline
from seesaw.project import Project
from seesaw.util import find_executable

if StrictVersion(seesaw.__version__) < StrictVersion('0.8.5'):
    raise Exception('This pipeline needs seesaw version 0.8.5 or higher.')


###########################################################################
# Find a useful Wget+Lua executable.
#
# WGET_AT will be set to the first path that
# 1. does not crash with --version, and
# 2. prints the required version string

WGET_AT = find_executable(
    'Wget+AT',
    [
        'GNU Wget 1.20.3-at.20200919.01',
        'GNU Wget 1.20.3-at.20201030.01'
    ],
    ['./wget-at']
)

if not WGET_AT:
    raise Exception('No usable Wget+At found.')


###########################################################################
# The version number of this pipeline definition.
#
# Update this each time you make a non-cosmetic change.
# It will be added to the WARC files and reported to the tracker.
VERSION = '20201225.02'
USER_AGENT = 'Archive Team'
TRACKER_ID = 'parler'
TRACKER_HOST = 'trackerproxy.archiveteam.org'


###########################################################################
# This section defines project-specific tasks.
#
# Simple tasks (tasks that do not need any concurrency) are based on the
# SimpleTask class and have a process(item) method that is called for
# each item.
class CheckIP(SimpleTask):
    def __init__(self):
        SimpleTask.__init__(self, 'CheckIP')
        self._counter = 0

    def process(self, item):
        # NEW for 2014! Check if we are behind firewall/proxy

        if self._counter <= 0:
            item.log_output('Checking IP address.')
            ip_set = set()

            ip_set.add(socket.gethostbyname('twitter.com'))
            ip_set.add(socket.gethostbyname('facebook.com'))
            ip_set.add(socket.gethostbyname('youtube.com'))
            ip_set.add(socket.gethostbyname('microsoft.com'))
            ip_set.add(socket.gethostbyname('icanhas.cheezburger.com'))
            ip_set.add(socket.gethostbyname('archiveteam.org'))

            if len(ip_set) != 6:
                item.log_output('Got IP addresses: {0}'.format(ip_set))
                item.log_output(
                    'Are you behind a firewall/proxy? That is a big no-no!')
                raise Exception(
                    'Are you behind a firewall/proxy? That is a big no-no!')

        # Check only occasionally
        if self._counter <= 0:
            self._counter = 10
        else:
            self._counter -= 1


class PrepareDirectories(SimpleTask):
    def __init__(self, warc_prefix):
        SimpleTask.__init__(self, 'PrepareDirectories')
        self.warc_prefix = warc_prefix

    def process(self, item):
        item_name = item['item_name']
        escaped_item_name = item_name.replace(':', '_').replace('/', '_').replace('~', '_')
        dirname = '/'.join((item['data_dir'], escaped_item_name[:30]))

        if os.path.isdir(dirname):
            shutil.rmtree(dirname)

        os.makedirs(dirname)

        item['item_dir'] = dirname
        item['warc_file_base'] = '-'.join([
            self.warc_prefix,
            #escaped_item_name[:45],
            hashlib.sha1(item_name.encode('utf8')).hexdigest(),
            time.strftime('%Y%m%d-%H%M%S')
        ])

        open('%(item_dir)s/%(warc_file_base)s.warc.gz' % item, 'w').close()
        open('%(item_dir)s/%(warc_file_base)s_data.txt' % item, 'w').close()

class MoveFiles(SimpleTask):
    def __init__(self):
        SimpleTask.__init__(self, 'MoveFiles')

    def process(self, item):
        os.rename('%(item_dir)s/%(warc_file_base)s.warc.gz' % item,
              '%(data_dir)s/%(warc_file_base)s.warc.gz' % item)
        os.rename('%(item_dir)s/%(warc_file_base)s_data.txt' % item,
              '%(data_dir)s/%(warc_file_base)s_data.txt' % item)

        shutil.rmtree('%(item_dir)s' % item)


def get_hash(filename):
    with open(filename, 'rb') as in_file:
        return hashlib.sha1(in_file.read()).hexdigest()

CWD = os.getcwd()
PIPELINE_SHA1 = get_hash(os.path.join(CWD, 'pipeline.py'))
LUA_SHA1 = get_hash(os.path.join(CWD, 'parler.lua'))

def stats_id_function(item):
    d = {
        'pipeline_hash': PIPELINE_SHA1,
        'lua_hash': LUA_SHA1,
        'python_version': sys.version,
    }

    return d


class WgetArgs(object):
    def realize(self, item):
        wget_args = [
            WGET_AT,
            '-U', USER_AGENT,
            '-nv',
            '--header', 'Cookie: jst=eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJzZXNzaW9uSWQiOjI0MzA1NTM3LCJ1c2VySWQiOjE1NTY4ODY0LCJwZXJtaXNzaW9ucyI6MjU2LCJ2ZXJpZmllZCI6ZmFsc2UsImlhdCI6MTYxMDI4NTAyMSwiZXhwIjoxNjEwMjg1MzIxfQ.1XHTNxJzP_20dMY7bAIwW-EfzIfYuiEnnhlN-qzZestgng-cwPWirRXbPdfGi9tkhF1HUpQ0XCgqiJ3UHsJV-A; mst=s%3AguF4Diq48gXITWH984v56tnoxYae2LKsOnE1CkggdsRsdjkyPugPWvHm5cvqKApKf6HAZQsPjFVNX7GFwN17ucnJyMFcbad2pYqlz1xvhkeCRg3cdSI1Djijs7VsBelV.7s09Z4U%2BaEql%2FQJ7RMchnrYkd%2F4h4h3LCW%2FH2rUAYWI',
            '--content-on-error',
            '--lua-script', 'parler.lua',
            '-o', ItemInterpolation('%(item_dir)s/wget.log'),
            '--no-check-certificate',
            '--output-document', ItemInterpolation('%(item_dir)s/wget.tmp'),
            '--truncate-output',
            '-e', 'robots=off',
            '--rotate-dns',
            '--recursive', '--level=inf',
            '--no-parent',
            '--page-requisites',
            '--timeout', '30',
            '--tries', 'inf',
            '--domains', 'parler.com',
            '--span-hosts',
            '--waitretry', '30',
            '--warc-file', ItemInterpolation('%(item_dir)s/%(warc_file_base)s'),
            '--warc-header', 'operator: Archive Team',
            '--warc-header', 'x-wget-at-project-version: ' + VERSION,
            '--warc-header', 'x-wget-at-project-name: ' + TRACKER_ID,
            '--warc-header', 'x-wget-at-project-item-name: ' + item['item_name'],
            '--warc-dedup-url-agnostic',
        ]

        item_name = item['item_name']
        item_type, item_value = item_name.split(':')

        item['item_type'] = item_type
        item['item_value'] = item_value

        if item_type == 'posts':
            start, end = item_value.split('-', 1)
            for i in range(int(start), int(end)+1):
                wget_args.extend(['--warc-header', 'parler-post: {}'.format(i)])
                wget_args.append('https://api.parler.com/v3/uuidConversion/post/{}'.format(i))
        else:
            raise ValueError('item_type not supported.')

        if 'bind_address' in globals():
            wget_args.extend(['--bind-address', globals()['bind_address']])
            print('')
            print('*** Wget will bind address at {0} ***'.format(
                globals()['bind_address']))
            print('')

        return realize(wget_args, item)

###########################################################################
# Initialize the project.
#
# This will be shown in the warrior management panel. The logo should not
# be too big. The deadline is optional.
project = Project(
    title = 'parler',
    project_html = '''
    <img class="project-logo" alt="logo" src="https://archiveteam.org/images/thumb/d/dc/Parler-logo.png/799px-Parler-logo.png" height="50px"/>
    <h2>parler.com <span class="links"><a href="https://parler.com/">Website</a> &middot; <a href="http://tracker.archiveteam.org/parler/">Leaderboard</a></span></h2>
    '''
)

pipeline = Pipeline(
    CheckIP(),
    GetItemFromTracker('http://%s/%s' % (TRACKER_HOST, TRACKER_ID), downloader,
        VERSION),
    PrepareDirectories(warc_prefix='parler'),
    WgetDownload(
        WgetArgs(),
        max_tries=1,
        accept_on_exit_code=[0, 4, 8],
        env={
            'item_dir': ItemValue('item_dir'),
            'item_type': ItemValue('item_type'),
            'item_value': ItemValue('item_value'),
            'warc_file_base': ItemValue('warc_file_base'),
        }
    ),
    PrepareStatsForTracker(
        defaults={'downloader': downloader, 'version': VERSION},
        file_groups={
            'data': [
                ItemInterpolation('%(item_dir)s/%(warc_file_base)s.warc.gz')
            ]
        },
        id_function=stats_id_function,
    ),
    MoveFiles(),
    LimitConcurrent(NumberConfigValue(min=1, max=20, default='2',
        name='shared:rsync_threads', title='Rsync threads',
        description='The maximum number of concurrent uploads.'),
        UploadWithTracker(
            'http://%s/%s' % (TRACKER_HOST, TRACKER_ID),
            downloader=downloader,
            version=VERSION,
            files=[
                ItemInterpolation('%(data_dir)s/%(warc_file_base)s.warc.gz'),
                ItemInterpolation('%(data_dir)s/%(warc_file_base)s_data.txt')
            ],
            rsync_target_source_path=ItemInterpolation('%(data_dir)s/'),
            rsync_extra_args=[
                '--recursive',
                '--partial',
                '--partial-dir', '.rsync-tmp',
                '--min-size', '1',
                '--no-compress',
                '--compress-level', '0'
            ]
        ),
    ),
    SendDoneToTracker(
        tracker_url='http://%s/%s' % (TRACKER_HOST, TRACKER_ID),
        stats=ItemValue('stats')
    )
)
