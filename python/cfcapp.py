#
import time
from flask import Flask, json
from flask.app import setupmethod
from threading import Thread

class DaemonThread(Thread):
	def start(self):
		self.daemon = True
		super(DaemonThread, self).start()

class WSConnection(object):
	def __init__(self, app, fid, wsid):
		self.app = app
		self.fid = fid
		self.wsid = wsid

	def __repr__(self):
		return '<WSConnection %s fid=..%s>' % (self.wsid, self.fid[-4:])

	def open(self):
		# do something when first connected
		pass

	def closed(self):
		# do something after closed; cannot send messages at this point
		pass

	def tx(self, msg):
		self.app.tx(msg, wsid=self.wsid)

class CFCFlask(Flask):
	''' Extensions to Flask() object to support app needs for CFC frontend '''
	#
	# override this -- what is the domain we're associated with
	# in the front end?
	#   lh = localhost/127.0.0.1
	#   none = no host given (ie. default)
	#	example.com = traffic for example.com
	#
	# Your app can still handle other traffic, but websocket stuff should be on these domains.
	#

	# how often to do websocket-level keepalive on sockets.
	ping_rate = 15		# seconds

	def __init__(self, *a, **kws):
		# list of functions that want to receive data from websocket clients
		self.ws_rx_handlers = []

		# map of all current connections
		self.ws_connections = {}

		self.my_vhosts = kws.pop('vhosts', ['lh', 'none'])
		
		super(CFCFlask, self).__init__(*a, **kws)

	def pinger(self):
		# Keep all connections alive with some minimal traffic
		RDB = self.redis
		RDB.publish('bcast', 'server restart')

		while 1:
			RDB.publish('bcast', 'PING')
			time.sleep(self.ping_rate)

	def rxer(self):
		# Listen for all traffic from the clients to us. Forward upwards to app
		RDB = self.redis

		endpoints = ['rx|'+v for v in self.my_vhosts]

		while 1:
			# block on read from a few lists...
			vhost, here = RDB.blpop(endpoints)

			# name of list which provides the value is the vhost source
			assert vhost.startswith('rx|')
			vhost = vhost[3:]
			assert vhost in self.my_vhosts, "Unexpended hostname: %s" % vhost

			# Data from WS is wrapped in some json by LUA code. Trustable.
			self.logger.debug('before = %r' % here)
			try:
				here = json.loads(here)
			except:
				self.logger.error('Badly wrapped WS message? %s' % here, exc_info=1)
				continue

			assert 'fid' in here
			assert 'wsid' in here
			wsid = here['wsid']
			fid = here['fid']

			# Socket state changes will "state" set but not "msg"
			if 'state' in here:
				sc = here['state']
				if sc == 'OPEN':
					self.ws_new_connection(wsid, fid)
				elif sc == 'CLOSE':
					conn = self.ws_connections.pop(wsid, None)
					if conn:
						conn.closed()

				# end of processing.
				continue

			assert 'msg' in here
			conn = self.ws_connections.get(wsid, None)
			if not conn:
				# this will happen if you restart python while the nginx/lua stays up
				self.logger.warn('New WSID')
				conn = self.ws_new_connection(wsid, fid)
				
			# Important: do not trust "msg" here as it comes
			# unverified from browser-side code. Could be nasty junk.
			self.logger.debug('here = %r' % here)
			msg = here.get('msg', None)

			for handler in self.ws_rx_handlers:
				handler(vhost, conn, msg)

			self.logger.debug('RX[%s] %r' % (vhost, msg))

	def ws_new_connection(self, wsid, fid):
		''' New WS connection, track it.
		'''
		self.ws_connections[wsid] = rv = WSConnection(self, wsid, fid)
		rv.open()
		return rv

	def tx(self, msg, conn = None, fid=None, wsid=None, bcast=False):
		'''
			Send a message via websocket to a specific browser, specific tab (wsid) or all

			'msg' can be text, but should probably be JSON in most applications.
		'''
		assert conn or fid or wsid or bcast, "Must provide a destination"

		if conn: 
			chan = 'wsid|' + conn.wsid
		elif wsid: 
			chan = 'wsid|' + wsid
		elif fid: 
			chan = 'fid|' + fid
		elif bcast:
			chan = 'bcast'

		self.redis.publish(chan, msg)

	def ws_close(self, wsid):
		'''
			Close a specific web socket from server side; perhaps because it mis-behaved.

			LUA code detects this message and kills it's connection.
		'''
		self.tx('CLOSE', wsid=wsid)

	@setupmethod
	def ws_rx_handler(self, f):
		"""Registers a function to be called when traffic is received via web sockets

		"""
		self.ws_rx_handlers.append(f)
		return f
			

	def start_bg_tasks(self):
		''' start long-lived background threads '''
		DaemonThread(name="pinger", target=self.pinger, args=[]).start()
		DaemonThread(name="rxer", target=self.rxer, args=[]).start()

