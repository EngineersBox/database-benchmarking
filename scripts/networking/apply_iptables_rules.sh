#!/bin/bash

# Exit on any error from child commands
set -e

case "$1" in
    "-h" ) ;&
    "--help" )
        echo "Usage: $0 <source ip> <source ip range> <port> [<verb: A|D>]";
        exit 1;;
    * ) ;;
esac

SOURCE_IP="$1"
SOURCE_IP_RANGE="$2"
SOURCE_PORT="$3"
VERB="${4:-A}"

USE_PERSISTENT_RULES=true
if ! command -v netfilter-persistent &> /dev/null; then
    echo "[NETFILTER] WARNING: iptables entries are emphemeral, 'netfilter-persistent' is used to ensure persistence, install the 'iptables-persistent' package to save rule changes"
    USE_PERSISTENT_RULES=false
fi

# See: https://www.digitalocean.com/community/tutorials/iptables-essentials-common-firewall-rules-and-commands
iptables -$VERB INPUT -p tcp -s "$SOURCE_IP/$SOURCE_IP_RANGE" --dport "$SOURCE_PORT" -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
echo "[IPTABLES] Created TCP input allowlist entry for $SOURCE_IP/$SOURCE_IP_RANGE:$SOURCE_PORT"
iptables -$VERB OUTPUT -p tcp --sport "$SOURCE_PORT" -m conntrack --ctstate ESTABLISHED -j ACCEPT
echo "[IPTABLES] Created TCP output allowlist entry for port $SOURCE_PORT"

if $USE_PERSISTENT_RULES; then
    netfilter-persistent save
    echo "[NETFILTER] Saved rule changes"
fi
