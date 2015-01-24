#
# Things that need to run all the time, regardless of client requests.
#
import os, sys, time
from threading import Thread

class DaemonThread(Thread):
	def start(self):
		self.daemon = True
		super(DaemonThread, self).start()

def pinger(app):
	# keep all connections alive with some minimal traffic
	RDB = app.redis
	RDB.publish('bcast', 'server restart')

	while 1:
		print "ping."
		RDB.publish('bcast', 'PING')
		#RDB.publish('bcast', 'test')
		time.sleep(15)

def rxer(app):
	# listen for all traffic from the clients to us
	RDB = app.redis

	while 1:
		vhost, here = RDB.blpop(('rx|none', 'rx|lh'))
		print "Got %s: %r" % (vhost, here)
	
		

def start_background(app):
	DaemonThread(name="pinger", target=pinger, args=[app]).start()
	DaemonThread(name="rxer", target=rxer, args=[app]).start()

