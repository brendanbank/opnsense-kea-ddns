# Test: DDNS round-trip (section 11)
# Adds a synthetic lease, triggers DDNS, verifies DNS, then cleans up.

TEST_IP="10.2.200.250"
TEST_MAC="de:ad:be:ef:00:01"

# Pick the first DDNS-enabled subnet on the test IP's network
TEST_SUBNET_ID=$(jq -r '[.Dhcp4.subnet4[] | select(.["ddns-send-updates"] == true and .subnet == "10.2.200.0/24")][0].id' < "$KEA4_CONF" 2>/dev/null)
TEST_SUFFIX=$(jq -r '[.Dhcp4.subnet4[] | select(.["ddns-send-updates"] == true and .subnet == "10.2.200.0/24")][0]["ddns-qualifying-suffix"]' < "$KEA4_CONF" 2>/dev/null)
TEST_SUFFIX="${TEST_SUFFIX%.}"
TEST_HOSTNAME="keaddns-functest.${TEST_SUFFIX}"

# Extract TSIG key for DNS cleanup
TSIG_NAME=$(jq -r '.DhcpDdns["tsig-keys"][0].name' < "$DDNS_CONF" 2>/dev/null)
TSIG_ALGO=$(jq -r '.DhcpDdns["tsig-keys"][0].algorithm' < "$DDNS_CONF" 2>/dev/null)
TSIG_SECRET=$(jq -r '.DhcpDdns["tsig-keys"][0].secret' < "$DDNS_CONF" 2>/dev/null)
FWD_ZONE=$(jq -r '.DhcpDdns["forward-ddns"]["ddns-domains"][0].name' < "$DDNS_CONF" 2>/dev/null)
REV_ZONE=$(jq -r '.DhcpDdns["reverse-ddns"]["ddns-domains"][0].name' < "$DDNS_CONF" 2>/dev/null)

# Build the reverse name: 10.2.200.250 -> 250.200.2.10.in-addr.arpa
TEST_PTR=$(echo "$TEST_IP" | awk -F. '{print $4"."$3"."$2"."$1}').in-addr.arpa

ddns_cleanup() {
    # Delete the test lease (ignore errors)
    kea_command "$KEA4_SOCK" "{\"command\": \"lease4-del\", \"arguments\": {\"ip-address\": \"$TEST_IP\"}}" >/dev/null 2>&1
    # Remove DNS records via nsupdate
    nsupdate -y "${TSIG_ALGO}:${TSIG_NAME}:${TSIG_SECRET}" << EOF 2>/dev/null
server ${DNS_SERVER}
zone ${FWD_ZONE}
update delete ${TEST_HOSTNAME} A
send
EOF
    nsupdate -y "${TSIG_ALGO}:${TSIG_NAME}:${TSIG_SECRET}" << EOF 2>/dev/null
server ${DNS_SERVER}
zone ${REV_ZONE}
update delete ${TEST_PTR} PTR
send
EOF
}

if [ -n "$TEST_SUBNET_ID" ] && [ "$TEST_SUBNET_ID" != "null" ]; then
    # Clean up any stale test records from a previous run
    ddns_cleanup

    # Add test lease
    ADD_RESULT=$(kea_command "$KEA4_SOCK" "{\"command\": \"lease4-add\", \"arguments\": {\"ip-address\": \"$TEST_IP\", \"hw-address\": \"$TEST_MAC\", \"hostname\": \"$TEST_HOSTNAME\", \"fqdn-fwd\": true, \"fqdn-rev\": true, \"subnet-id\": $TEST_SUBNET_ID}}")
    if echo "$ADD_RESULT" | jq -e '.result == 0' >/dev/null 2>&1; then
        pass "DDNS round-trip: test lease added ($TEST_HOSTNAME -> $TEST_IP)"

        # Trigger DDNS
        RESEND_RESULT=$(kea_command "$KEA4_SOCK" "{\"command\": \"lease4-resend-ddns\", \"arguments\": {\"ip-address\": \"$TEST_IP\"}}")
        if echo "$RESEND_RESULT" | jq -e '.result == 0' >/dev/null 2>&1; then
            pass "DDNS round-trip: NCR generated"
        else
            fail "DDNS round-trip: lease4-resend-ddns failed"
        fi

        # Wait for DDNS propagation
        sleep 3

        # Check forward DNS
        RESOLVED_IP=$(dig +short "$TEST_HOSTNAME" "@$DNS_SERVER" 2>/dev/null | head -1)
        if [ "$RESOLVED_IP" = "$TEST_IP" ]; then
            pass "DDNS round-trip: forward DNS $TEST_HOSTNAME -> $TEST_IP"
        else
            fail "DDNS round-trip: forward DNS expected $TEST_IP, got ${RESOLVED_IP:-NXDOMAIN}"
        fi

        # Check reverse DNS
        RESOLVED_NAME=$(dig +short -x "$TEST_IP" "@$DNS_SERVER" 2>/dev/null | head -1)
        EXPECTED_NAME="${TEST_HOSTNAME%.}."
        if [ "$RESOLVED_NAME" = "$EXPECTED_NAME" ]; then
            pass "DDNS round-trip: reverse DNS $TEST_IP -> $TEST_HOSTNAME"
        else
            fail "DDNS round-trip: reverse DNS expected $TEST_HOSTNAME, got ${RESOLVED_NAME:-NXDOMAIN}"
        fi

        # Clean up
        ddns_cleanup
    else
        fail "DDNS round-trip: failed to add test lease"
    fi
else
    fail "DDNS round-trip: no DDNS-enabled subnet found for $TEST_IP"
fi
