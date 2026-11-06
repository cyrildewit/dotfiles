# Proton VPN

## Profile

- [ ] Create a profile "Daily – NL": Netherlands, Fastest, WireGuard, NetShield
      blocking malware, ads and trackers, Secure Core off
- [ ] Set it as the default connection

## Settings

- [ ] Start on boot: on
- [ ] Auto-connect: on
- [ ] Kill switch: on
- [ ] Allow LAN connections: on (Philips Hue, local dev from other devices)
- [ ] Custom DNS: empty, otherwise NetShield is disabled
- [ ] Usage statistics and crash reports: off

## macOS

- [ ] iCloud Private Relay: off, it conflicts with the VPN
- [ ] Firewall: on, since LAN connections are allowed

## Verify

With the VPN connected:

- [ ] [ipleak.net](https://ipleak.net) shows only a Proton IP
- [ ] [dnsleaktest.com](https://dnsleaktest.com) extended test shows no ISP
      DNS servers
