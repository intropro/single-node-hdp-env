#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import json

from pprint import pprint
import xml.etree.ElementTree as ET


CONFIG_FILES = {
    'hdfs-site.xml': 'hadoop/conf/hdfs-site.xml',
    # 'hbase/conf/hdfs-site.xml',
    'core-site.xml': 'hadoop/conf/core-site.xml',
    # 'hbase/conf/core-site.xml',
    'hbase-site.xml': 'hbase/conf/hbase-site.xml',
    'hive-site.xml': 'hive/conf/hive-site.xml',
    # 'yarn/yarn-site.xml',
    'yarn-site.xml': 'hadoop/conf/yarn-site.xml',
    # 'mapred/mapred-site.xml',
    'mapred-site.xml': 'hadoop/conf/mapred-site.xml',
    # 'hive/conf/mapred-site.xml'
    # 'hive/conf/mapred-site.xml',
    'oozie-site.xml': 'oozie/conf/oozie-site.xml',
}

class ConfigBuilder(object):

    def __init__(self, config_path):

        if not os.path.exists(config_path):
            raise RuntimeError('The path does not exist, %s' % config_path)

        self.config_path = config_path
        self.config_files = []

        config_files=[
        ]
        for cfile in CONFIG_FILES:
            cfile = os.path.join(config_path, CONFIG_FILES[cfile])
            if not os.path.exists(cfile):
                print >> sys.stderr, "[WARNING] Config file does not exist, %s" % cfile
                continue
            else:
                self.config_files.append(cfile)


    def xml2dict(self, filename):

        result = list()
        for prop in ET.parse(filename).getroot():
            result.append(dict([(c.tag, c.text) for c in prop.getchildren()]))

        return dict((kv['name'], kv['value'].strip() if kv['value'] else "") for kv in result)


    @property
    def config(self):

        _config = dict()
        for conf_file in self.config_files:
            conf_name = os.path.basename(conf_file).replace('.xml', '')
            _config[conf_name] = dict()
            for kv in self.xml2dict(conf_file).items():
                if kv[0] in _config[conf_name] and _config[conf_name][kv[0]] != kv[1]:
                    print >> sys.stderr, "[WARNING] Duplicated key with different values, %s" % kv
                else:
                    _config[conf_name][kv[0]] = kv[1]
        return _config


def create_env_props(conf_dir):

    def get_prop(config, prop_name):

        if prop_name in config.keys():
            return config[prop_name]
        else:
            return ''

    builder = ConfigBuilder(conf_dir)

    _config = builder.config
    _env_props = {}

    # core-site.xml
    if 'core-site' in _config:
        _env_props['nameNode'] = get_prop(_config['core-site'], 'fs.defaultFS')
        _env_props['securityAuthentication'] = get_prop(_config['core-site'], 'hadoop.security.authentication')

    # yarn-site.xml
    if 'yarn-site' in _config:
        _env_props['jobTracker'] = get_prop(_config['yarn-site'], 'yarn.resourcemanager.address')

    # hbase-site.xml
    if 'hbase-site' in _config:
        _env_props['hbaseZookeeperQuorum'] = get_prop(_config['hbase-site'], 'hbase.zookeeper.quorum')

    # hive-site.xml
    if 'hive-site' in _config:
        _env_props['hiveZookeeperQuorum'] = get_prop(_config['hive-site'], 'hive.zookeeper.quorum')
        _env_props['hiveMetastoreUris'] = get_prop(_config['hive-site'], 'hive.metastore.uris')
        _env_props['hiveMetastorePrincipal'] = get_prop(_config['hive-site'], 'hive.metastore.kerberos.principal')

    # oozie-site.xml
    if 'oozie-site' in _config:
        _env_props['oozieServer'] = get_prop(_config['oozie-site'], 'oozie.base.url')

    return _env_props


if __name__ == '__main__':

    import optparse

    parser = optparse.OptionParser(usage="usage: %prog [options]")
    parser.add_option('--conf-dir', type=str, help='the path to config directory (optional, default /etc/)')
    parser.add_option('--server', type=str, help='Config server details: <ip-address>:<port>')
    parser.add_option('--env-props', type=str, help='the path to env.properties file, "-" for print to stdout')

    opts, args = parser.parse_args()

    if not opts.conf_dir:
        opts.conf_dir = '/etc/'

    if opts.env_props:
        env_props = create_env_props(opts.conf_dir)

        if opts.env_props == '-':
            for k,v in env_props.items():
                print "%s=%s" % (k,v)
        else:
            with open(opts.env_props, 'w') as env:
                for k,v in env_props.items():
                    env.write("%s=%s\n" % (k,v))

    if opts.server:

        import socket
        import SocketServer
        import SimpleHTTPServer

        class ConfigHandler(SimpleHTTPServer.SimpleHTTPRequestHandler):
            def do_GET(self):

                message = 'ConfigServer'

                if self.path == '/':
                    message = '''
                    <html>
                    <head>
                        <meta charset="utf-8">
                        <link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/1.10.11/css/jquery.dataTables.min.css">
                        <script type="text/javascript" language="javascript" src="http://code.jquery.com/jquery-1.12.0.min.js"></script>
	                    <script type="text/javascript" language="javascript" src="http://cdn.datatables.net/1.10.11/js/jquery.dataTables.min.js"></script>
                        <script type="text/javascript" class="init">{init_func}</script>
                    </head>
                    <body>
                        <h1>{hostname} environment configuration</h1>
                        <h2>Services</h2>
                        <p>Ambari: <a href="http://{hostname}:8080/">http://{hostname}:8080/</a></p>
                        <p>Hue: <a href="http://{hostname}:8000/">http://{hostname}:8000/</a></p>

                        <h2>Configs</h2>
                        <p><a href="/conf/environment.properties">environment.properties</a></p>
                        <p><a href="/conf/environment.json">environment.json</a></p>
                        <p><a href="/conf/config.json">config.json</a></p>

                        <h2>Hadoop configs</h2>
                        <p><a href="/conf/hdfs-site.xml">hdfs-site.xml</a></p>
                        <p><a href="/conf/core-site.xml">core-site.xml</a></p>
                        <p><a href="/conf/hbase-site.xml">hbase-site.xml</a></p>
                        <p><a href="/conf/hive-site.xml">hive-site.xml</a></p>
                        <p><a href="/conf/yarn-site.xml">yarn-site.xml</a></p>
                        <p><a href="/conf/mapred-site.xml">mapred-site.xml</a></p>
                        <p><a href="/conf/oozie-site.xml">oozie-site.xml</a></p>

                        <h2>Cluster parameters</h2>
                        <table id="config" class="display">
                            <thead><tr><th>config</th><th>parameter</th><th>value</th></tr></thead>
                        </table>
                    </body>
                    </html>
                    '''.format(
                        hostname=socket.getfqdn(),
                        init_func="$(document).ready(function() { $('#config').DataTable({'ajax': '/conf/config.json'}); } );"
                    )
                elif self.path.startswith('/conf/config.json'):
                    _msg = []
                    for name, conf in ConfigBuilder(opts.conf_dir).config.items():
                        for k,v in conf.items():
                            _msg.append((name,k,v))
                    # self.send_header("Content-Type", "application/json")
                    message = json.dumps({'data': _msg})
                elif self.path == '/conf/environment.json':
                    message = json.dumps(create_env_props(opts.conf_dir))
                elif self.path == '/conf/environment.properties':
                    message = '\n'.join("%s=%s" % (k,v) for k,v in create_env_props(opts.conf_dir).items())
                elif self.path.startswith('/conf/'):
                    conf_file = os.path.basename(self.path)
                    try:
                        message = open(os.path.join(opts.conf_dir, CONFIG_FILES[conf_file])).read()
                    except:
                        message = ''

                self.send_response(200)
                self.end_headers()
                self.wfile.write(message)

        address,port = opts.server.split(':')
        # handler = SimpleHTTPServer.SimpleHTTPRequestHandler
        httpd = SocketServer.TCPServer((address, int(port)), ConfigHandler)
        print "serving at %s:%s" % (address, port)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print >> sys.stderr, 'Interrupted by user'
