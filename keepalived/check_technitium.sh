#!/bin/sh
# keepalived health check for Technitium DNS Server.
# Healthy = the DNS server on THIS box answers a name from one of its own zones.

# >>> CHANGE THIS <<<
# CHECK_NAME: a name in a zone your server answers for (Zones tab),
# for example the record you added for a device in Step 6 (nas.home.arpa).
CHECK_NAME="CHANGE-ME.nas.home.arpa"

dig +time=1 +tries=1 +short @127.0.0.1 "$CHECK_NAME" A | grep -q '^[0-9]'
