#!/usr/bin/env python
#
# A program to demonstate how to upload a static website into the CFC. 
#
# You'd need to run it a few times:
#	- upload content with "upload.py multi path-to-topdir"
#	- commit that to disk in CFC: "upload.py write"
#	- add some redirects, like root => index.html
#	- 		./upload.py redirect / /index.html
#
#
import os, sys, re, requests
from redis import Redis
import click
from hashlib import md5 as MD5
from mimetypes import guess_type, guess_extension
from urlparse import urlparse

MIN_Q_SIZE = 8000
RDB = None
admin_pw = None

def blacklist_filename(fn):
	if fn.startswith('.git'): return True
	if fn.startswith('.') and '.sw' in fn: return True
	return False

def better_mimes(fname):
	if fname.endswith('.svg'):
		return 'image/svg+xml'
	if fname.endswith('.md'):
		return 'text/plain'

def log_path(url, msg):
	click.echo("%-50.50s %s" % (url, msg))

def url_to_key(host, absurl):
	assert absurl[0] == '/'
	assert host
	return '%s|%s' % (host.lower(), absurl)

@click.group()
@click.option('--sock', default='~/redis.sock')
@click.option('--redis', default=None)
@click.option('--password', '-p',  default='hello')
def cli(sock, redis, password):
	global RDB, admin_pw
	if not redis:
		click.echo("Using redis via unix socket: %s" % sock)
		RDB = Redis(unix_socket_path=os.path.expanduser(sock))
	else:
		click.echo("Using redis @: %s" % redis)
		RDB = redis.Redis.from_url(redis)

	admin_pw = password
	

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
	needs_write = False

	ct, enc = guess_type(absurl, strict=False)
	print "%s = %s" % (absurl, ct)
	if not ct:
		ct = better_mimes(absurl)
		if not ct:
			ct = 'text/html'
	if not enc and ct and ct.startswith('text/'):
		enc = 'utf-8'

	ll = len(content)
	rv['Content-Length'] = ll

	if ll < MIN_Q_SIZE:
		rv['_content'] = content
		log_path(absurl, 'In-Memory')
	else:
		hh = MD5(content).hexdigest()
		if '.' in absurl:
			# add file extension; if present.
			ext = (absurl.split('.', 1)[-1]).lower()
			hh += '.' + ext
		
		rv['_hash'] = hh
		needs_write = True

		if not RDB.hexists('new_files', hh) and not RDB.sismember('all_files', hh):
			RDB.hset('new_files', hh, content)
			log_path(absurl, 'UPLOADED')
		else:
			log_path(absurl, 'skipped (got it)')

	rv['Content-Type'] = ct + ('' if not enc else '; charset="%s"' % enc)
	#print "%s => %r" % (rk, rv)
	RDB.hmset(rk, rv)

	return needs_write
	

@cli.command(help="Upload a tree of files")
@click.argument('baseurl')
@click.argument('topdir', type=click.Path(exists=True))
def multi(baseurl, topdir):
	parts = urlparse(baseurl)
	host = parts.netloc.lower()
	baseurl = parts.path
	
	host = host.lower()
	assert baseurl[0] == '/'

	needs_write = False
	for root, dirs, files in os.walk(topdir):
		for fn in files:
			if blacklist_filename(fn):
				log_path(fn, 'junk')
				continue
			fname = os.path.join(root, fn)
			url = os.path.join(baseurl, fname[len(topdir)+1:])
			print '%s => %s' % (fname, url)
			wr = upload_file(host, click.open_file(fname), url)
			if wr: needs_write = True

	if needs_write:
		do_write()
	#click.echo("Remember: You still need to tell server to save the files, see 'write' cmd")

@cli.command(help="Reset entire redis database!")
def flushdb():
	RDB.flushdb()
	click.echo("Wiped database")

@cli.command(help="Show what's in redis cache")
def dump():
	k = RDB.keys('*|/*')
	print '\n'.join(k)

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
def write():
	do_write()

def do_write():
	r = requests.get('http://localhost/__A__/save?pw=%s' % admin_pw)
	print r.content

if __name__ == '__main__':
	cli()

# EOF
