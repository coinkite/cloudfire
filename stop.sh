#!/bin/sh
nginx -p `pwd` -c nginx.conf -s quit
