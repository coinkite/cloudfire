#!/bin/sh
#
#
mkdir -p /var/tmp/nginx
nginx -p `pwd`/ -c nginx.conf

echo "http://localhost:80/"
