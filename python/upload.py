#!/usr/bin/env python
#
import os, sys, re
from redis import Redis
import click
from hashlib import md5 as MD5
from mimetypes import guess_type, guess_extension

MIN_Q_SIZE = 8000
RDB = None

def blacklist_filename(fn):
	if fn.startswith('.git'): return True
	if fn.startswith('.') and '.sw' in fn: return True
	return False

def log_path(url, msg):
	click.echo("%-50.50s %s" % (url, msg))

@click.group()
@click.option('--sock', default='~/redis.sock')
@click.option('--redis', default=None)
def cli(sock, redis):
	global RDB
	if not redis:
		click.echo("Using redis via unix socket: %s" % sock)
		RDB = Redis(unix_socket_path=os.path.expanduser(sock))
	else:
		click.echo("Using redis @: %s" % redis)
		RDB = Redis(unix_socket_path=os.path.expanduser(hostname=redis))
	

@cli.command('single')
@click.option('--host', '-h', default="lh")
@click.argument('fd', type=click.File('rb'))
@click.argument('absurl')
def single(host, fd, absurl):
	upload_file(host, fd, absurl)

def upload_file(host, fd, absurl):
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
			# add file extension; if present.
			ext = (absurl.split('.', 1)[-1]).lower()
			hh += '.' + ext
		
		rv['_hash'] = hh

		if not RDB.hexists('new_files', hh) and not RDB.sismember('all_files', hh):
			RDB.hset('new_files', hh, content)
			log_path(absurl, 'UPLOADED')
		else:
			log_path(absurl, 'skipped (got it)')

	rv['Content-Type'] = ct + ('' if not enc else '; charset="%s"' % enc)
	print "%s => %r" % (rk, rv)
	RDB.hmset(rk, rv)

	

@cli.command()
@click.option('--host', '-h', default="lh")
@click.option('--baseurl', '-u',  default='/')
@click.argument('topdir', type=click.Path(exists=True))
def multi(host, baseurl, topdir):
	assert host == host.lower()
	assert baseurl[0] == '/'

	for root, dirs, files in os.walk(topdir):
		for fn in files:
			if blacklist_filename(fn):
				log_path(fn, 'junk')
				continue
			fname = os.path.join(root, fn)
			url = os.path.join(baseurl, fname[len(topdir):])
			#print '%s => %s' % (fname, url)
			upload_file(host, click.open_file(fname), url)

@cli.command()
def flush()
	RDB.flushdb()
	click.echo("Wiped database")

if __name__ == '__main__':
	cli()
	# You still need to tell lua to save the new files.
	click.echo("Remeber: /__A__/save?pw=hello")

# EOF
