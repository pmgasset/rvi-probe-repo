# SupportLink Wrapper

This script restores the styled SupportLink web UI while keeping all existing JSON API endpoints.

* **HTML mode**: Requests without `action=` or `provider=` and without a JSON `Accept` header render the HTML dashboard.
* **API mode**: Requests with those parameters or JSON `Accept` are delegated to `supportlink.api`.
* The deploy script backs up the original API handler to `/www/cgi-bin/supportlink.api` and installs the wrapper at `/www/cgi-bin/supportlink`.
* Roll back by moving `supportlink.api` back to `supportlink` and restarting `uhttpd`.

## Deploy
```
sh scripts/deploy-supportlink-wrapper.sh
```
