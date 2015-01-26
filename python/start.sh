#!/bin/sh
#
# NOTE: this assumes you're using a virtualenv called "ENV" in this directory
#
PY=ENV/bin/python
VHOST=cloudfire-demo.coinkite.com

# update in-memory version of static files
$PY upload.py multi http://$VHOST/static/ ../img

# start a fast-cgi server.
$PY fserver.py -r unix:../redis.sock --vhost $VHOST
