#!/usr/local/bin/bash

# stop firewall
service pf stop
# renew cert
/usr/local/bin/certbot-2.7 renew --quiet
# enable firewall
service pf start