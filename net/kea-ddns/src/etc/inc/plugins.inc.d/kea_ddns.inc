<?php

/*
 * Copyright (C) 2026 Brendan Bank <brendan.bank@gmail.com>
 * Copyright (C) 2026 Yip Rui Fung <rf@yrf.me>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

function kea_ddns_run()
{
    return [
        'kea_dhcpv4_config' => 'kea_ddns_get_dhcpv4_overlay',
        'kea_ddns_generate' => 'kea_ddns_generate_config',
    ];
}

function kea_ddns_get_dhcpv4_overlay()
{
    $mdl = new \OPNsense\KeaDdns\KeaDdns();
    if (!$mdl->general->enabled->isEqual('1')) {
        return [];
    }
    return $mdl->getDhcpv4Overlay();
}

function kea_ddns_generate_config()
{
    $mdl = new \OPNsense\KeaDdns\KeaDdns();
    if (!$mdl->general->enabled->isEqual('1')) {
        return [];
    }
    if ($mdl->general->manual_config->isEmpty()) {
        $mdl->generateD2Config();
    }
    return ['enabled' => true];
}

function kea_ddns_services()
{
    $services = [];
    $mdl = new \OPNsense\KeaDdns\KeaDdns();
    if ($mdl->general->enabled->isEqual('1')) {
        $services[] = [
            'configd' => [
                'restart' => ['kea restart'],
                'start' => ['kea start'],
                'stop' => ['kea stop'],
            ],
            'name' => 'kea-dhcp',
            'description' => gettext('KEA DHCP DDNS server'),
            'pidfile' => '/var/run/kea/kea-dhcp-ddns.kea-dhcp-ddns.pid',
            'id' => 'ddns',
        ];
    }
    return $services;
}

function kea_ddns_syslog()
{
    return ['kea_ddns' => ['facility' => ['kea-dhcp-ddns']]];
}
