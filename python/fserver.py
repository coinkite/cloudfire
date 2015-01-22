#!/usr/bin/env python
#
# Be a Fast CGI server, running on a localhost port.
#
import click

from flup.server.fcgi import WSGIServer
class MyWSGIServer(WSGIServer):

    # See .../flup/server/fcgi_base.py for original version

    debug = False           # just in case

    def error(self, req):
        """
        This  be triggerd by:

			curl -v "https://hostname/..%c0%af..%c0%af..%c0%af..%c0%af..%c0%af..%c0%af..%c0%af..%c0%afetc/passwd"

        """
        # NOTE: req = <flup.server.fcgi_base.Request>
        # NOTE: "working outside of request context" here

        # Have not found a way to get the IP address here... if I could,
        # then would ban it... like this:

        errorpage = """<pre>Unhandled Late Exception.\n\nSorry."""
        req.stdout.write('Status: 500 Internal Server Error\r\n' +
                         'Content-Type: text/html\r\n\r\n' + errorpage)

@click.command('start')
@click.option('--port', '-p', default=9999)
@click.option('--ip', '-h', default='127.0.0.1')
@click.option('--debug', '-d', is_flag=True, help="Runs locally as web server")
def start_server(ip, port, debug):
	from example_app import app

	app.debug = True

	if debug:
		app.run(host="0.0.0.0", port=port)
	else:
		print "Running as FastCGI at %s:%d" % (ip, port)
		MyWSGIServer(app, bindAddress=(ip, port), multiplexed=True, umask=0).run()

if __name__ == '__main__':
	start_server()




