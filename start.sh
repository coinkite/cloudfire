#!/bin/sh
#
#
if ! redis-cli -s redis.sock info > /dev/null ; then
    echo "Restarting redis"
    redis-server redis.conf &
else
    echo "Redis looks OK"
fi

mkdir -p /var/tmp/nginx
nginx -p `pwd` -c nginx.conf -s quit
nginx -p `pwd`/ -c nginx.conf

echo "http://localhost:80/"
