#!/usr/bin/env python
#
import os, sys, re, requests
from redis import Redis
import click
from hashlib import md5 as MD5
from mimetypes import guess_type, guess_extension
from urlparse import urlparse

MIN_Q_SIZE = 8000
RDB = None

def blacklist_filename(fn):
	if fn.startswith('.git'): return True
	if fn.startswith('.') and '.sw' in fn: return True
	return False

def log_path(url, msg):
	click.echo("%-50.50s %s" % (url, msg))

def url_to_key(host, absurl):
	assert absurl[0] == '/'
	assert host
	return '%s|%s' % (host.lower(), absurl)

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
	

@cli.command('single', help="Upload a single file as response for specific URL")
@click.option('--host', '-i', default="lh")
@click.argument('fd', type=click.File('rb'))
@click.argument('absurl')
def single(host, fd, absurl):
	upload_file(host, fd, absurl)

def upload_file(host, fd, absurl):
	rk = url_to_key(host, absurl)
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
	#print "%s => %r" % (rk, rv)
	RDB.hmset(rk, rv)

	

@cli.command(help="Upload a tree of files")
@click.option('--host', '-i', default="lh")
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

	click.echo("Remember: You still need to tell server to save the files, see 'write' cmd")

@cli.command(help="Reset entire redis database!")
def flushdb():
	RDB.flushdb()
	click.echo("Wiped database")

@cli.command(help="List defined urls for host")
@click.option('--wipe', '-w', is_flag=True, help="Wipe them.")
@click.argument('host')
def list(host, wipe):
	keys = RDB.keys(host + '|/*')
	if not keys:
		click.echo("No matches. Nothing stored for that host: '%s'" % host)
		return

	click.echo("Existing paths:")
	for k in keys:
		click.echo("  %s" % k)

	if wipe:
		RDB.delete(*keys)
		click.echo("\nWiped them.")

@cli.command(help="Setup a redirect")
@click.option('--host', '-i', default="lh")
@click.option('--code', '-c', default=302)
@click.argument('from_url', metavar="FROM")
@click.argument('to')			# help="Can be relative or absolute"
def redirect(host, code, from_url, to):
	parts = urlparse(from_url)
	rk = url_to_key(parts.netloc or host, parts.path)
	rv = {}
		
	rv['_redirect'] = to
	rv['_code'] = code
	RDB.delete(rk)
	RDB.hmset(rk, rv)

	click.echo("Added: %s => %s" % (from_url, to))

@cli.command(help="Commit uploaded files to disk cache")
@click.option('--password', '-p',  default='hello')
def write(password):
	r = requests.get('http://localhost/__A__/save?pw=%s' % password)
	print r.content

if __name__ == '__main__':
	cli()

# EOF
