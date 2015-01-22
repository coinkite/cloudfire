#!/usr/bin/env python
#
import os, sys
from redis import Redis
import click
from hashlib import md5 as MD5
from mimetypes import guess_type, guess_extension

MIN_Q_SIZE = 8000

RDB = Redis(unix_socket_path='../redis.sock')

@click.command()
@click.option('--host', '-h', default="lh")
@click.argument('fd', type=click.File('rb'))
@click.argument('absurl')
def upload_file(fd, host, absurl):
	assert absurl[0] == '/'
	rk = '%s|%s' % (host, absurl)
	content = fd.read()
	rv = {}

	ct, enc = guess_type(absurl, strict=False)
	if not ct:
		ct = 'text/html'
	if not enc and ct and ct.startswith('text/'):
		enc = 'utf-8'

	ll = len(content)
	rv['Content-Length'] = ll

	if ll < MIN_Q_SIZE:
		rv['_content'] = content
	else:
		hh = MD5(content).hexdigest()
		if '.' in absurl:
			hh += '.' + absurl.split('.', 1)[-1]
		
		rv['_hash'] = hh
		RDB.hset('new_files', hh, content)

	rv['Content-Type'] = ct + ('' if not enc else '; charset="%s"' % enc)
	RDB.hmset(rk, rv)
	

@click.command()
@click.option('--host', '-h', default="lh")
@click.option('--urldir', '-u',  default='/')
@click.argument('files', type=click.File('rb'), nargs=-1)
def upload(files, host, urldir):
	assert host == host.lower()
	assert urldir[0] == '/'

	for fn in files:
		path = os.path.join(urldir, fn.name)
		upload_file(fn, host, path)

if __name__ == '__main__':
	upload_file()

# EOF
