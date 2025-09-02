SupportLink Static UI
====================
Static `/www/index.html` calls JSON CGI endpoints under `/cgi-bin`.

* `index.html` fetches `/cgi-bin/supportlink`, `/cgi-bin/internet_details`, and `/cgi-bin/outage_check?provider=...`.
* uhttpd home `/www`, `cgi_prefix /cgi-bin`.
* Cloudflared forwards `${MAC}.nomadconnect.app` to `http://127.0.0.1:80`.

Rollback: `mv /www/index.html.bak /www/index.html && /etc/init.d/uhttpd restart`

Quick tests:
`curl http://localhost/`
`curl http://localhost/cgi-bin/supportlink`
`curl http://localhost/cgi-bin/internet_details`
`curl http://localhost/cgi-bin/outage_check?provider=att`
