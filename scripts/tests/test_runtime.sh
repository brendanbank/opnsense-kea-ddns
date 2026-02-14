# Test: runtime checks (sections 6-8)
# Validates running daemons, control sockets, and lease DDNS flags.

# --- 6. Kea daemons running ---
for daemon in kea-dhcp4 kea-dhcp-ddns kea-ctrl-agent; do
    if pgrep -x "$daemon" >/dev/null 2>&1; then
        pass "Daemon: $daemon is running"
    else
        fail "Daemon: $daemon is not running"
    fi
done

# --- 7. Kea control sockets responsive ---
KEA4_STATUS=$(kea_command "$KEA4_SOCK" '{"command": "status-get"}')
if echo "$KEA4_STATUS" | jq -e '.result == 0' >/dev/null 2>&1; then
    pass "Control socket: kea-dhcp4 responds to status-get"
else
    fail "Control socket: kea-dhcp4 not responding"
fi

DDNS_STATUS=$(kea_command "$DDNS_SOCK" '{"command": "status-get"}')
if echo "$DDNS_STATUS" | jq -e '.result == 0' >/dev/null 2>&1; then
    pass "Control socket: kea-dhcp-ddns responds to status-get"
else
    fail "Control socket: kea-dhcp-ddns not responding"
fi

# --- 8. Active leases have DDNS flags ---
LEASES_JSON=$(kea_command "$KEA4_SOCK" '{"command": "lease4-get-all"}')
LEASE_COUNT=$(echo "$LEASES_JSON" | jq '.arguments.leases | length' 2>/dev/null)
FWD_LEASE_COUNT=$(echo "$LEASES_JSON" | jq '[.arguments.leases[] | select(.["fqdn-fwd"] == true)] | length' 2>/dev/null)
REV_LEASE_COUNT=$(echo "$LEASES_JSON" | jq '[.arguments.leases[] | select(.["fqdn-rev"] == true)] | length' 2>/dev/null)

if [ "$LEASE_COUNT" -gt 0 ] 2>/dev/null; then
    pass "Leases: $LEASE_COUNT active lease(s)"
else
    fail "Leases: no active leases found"
fi

if [ "$FWD_LEASE_COUNT" -gt 0 ] 2>/dev/null; then
    pass "Leases: $FWD_LEASE_COUNT lease(s) with fqdn-fwd=true"
else
    fail "Leases: no leases with fqdn-fwd=true"
fi

if [ "$REV_LEASE_COUNT" -gt 0 ] 2>/dev/null; then
    pass "Leases: $REV_LEASE_COUNT lease(s) with fqdn-rev=true"
else
    fail "Leases: no leases with fqdn-rev=true"
fi
