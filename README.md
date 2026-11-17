# Technitium DNS Server at home

▶️ Video: https://youtu.be/MQcR3S3qYVM

Technitium DNS Server blocks ads like Pi-hole, but it finds every answer on its own (recursive), so Google, Cloudflare or your internet provider's DNS never get the list of sites your home visits. This repo has the install command, the Advanced Blocking config (YouTube and TikTok blocked on one kid's laptop only) and the keepalived files for a second server with one floating IP, all from the video.

The addresses below are examples. Replace them with yours:

| | IP | Role |
|---|---|---|
| `dns1` | `192.168.1.61` | main server |
| `dns2` | `192.168.1.62` | second server |
| floating IP | `192.168.1.60` | what your devices use as DNS (keepalived only) |
| kid's laptop | `192.168.1.50` | the device in the `kids` group |

## What you need
Official requirements from [technitium.com/dns](https://technitium.com/dns/):
- Windows, Linux, macOS, Docker or Raspberry Pi (arm7 CPU; Raspberry Pi 1 and Zero are not supported).
- The .NET 10 runtime. On Linux the install script below installs it for you.
- Technitium doesn't list a minimum CPU, RAM or disk.

Plus:
- A PC to test from.
- For Step 8, a second machine.

In the video: two Ubuntu 24.04 containers on Proxmox, Technitium v15.6.2, keepalived 2.2.8.

## Step 1: Install
SSH into the server, then the one command from Technitium's site:
```bash
curl -sSL https://download.technitium.com/dns/install.sh | sudo bash
```
`curl` downloads the install script, the pipe `|` hands it to `bash` to run, and `sudo` asks for your password. On Ubuntu it also switches off `systemd-resolved` so Technitium can use port 53. That's expected.

It prints a web address with the server's name. Your PC may not know that name yet, so use the IP instead.

## Step 2: The dashboard
Open `http://192.168.1.61:5380` in your browser. The first time, it asks for a new admin password. This page controls your whole network's DNS, so make it strong.

## Step 3: Ad blocking
Settings → Blocking → Quick Add → **Default** → Save. Blocking is already on; this adds one well-known list (about 77,000 domains), updated every day.

## Step 4: Point a PC at it
`Win + R` → `ncpa.cpl` → right click Ethernet or Wi-Fi → Properties → Internet Protocol Version 4 (TCP/IPv4) → "Use the following DNS server addresses" → the server's IP → OK.

Test in Terminal:
```
nslookup doubleclick.net
nslookup github.com
```
`doubleclick.net` = Non-existent domain (blocked). `github.com` = its real address.

**"No response from server"?** Your router probably hands out an IPv6 DNS server too, and Windows asks that one first. Untick **Internet Protocol Version 6 (TCP/IPv6)** in the same adapter properties and try again.

Whole house: put the Technitium server's IP in your router's **DHCP** settings as the DNS server it hands out (not the WAN DNS setting). The [Pi-hole video](https://youtu.be/UDNSbAFTXxQ) shows that screen.

## Step 5: Answers on its own
- Settings → Proxy & Forwarders: the forwarders box is empty, so Technitium goes to the root servers itself.
- Apps → App Store → **Query Logs (Sqlite)** → Install. Logs → Query Logs: the answers say `Recursive`.
- A site you need shows as blocked? Add it in the **Allowed** tab.
- DNSSEC check (on by default): `nslookup dnssec-failed.org` fails on purpose (broken signature).

## Step 6: Names for your devices
Zones → Add Zone → your zone name, **Primary Zone** → Add. Add Record → Name `nas`, Type `A`, the device's IP → Save.
```
ping nas.home.arpa
```
Use `home.arpa` (reserved for home networks) or a part of your domain nothing else uses (like `home.yourdomain.com`). If you use your whole public domain as the zone, every public name in it you didn't add stops working for devices that use this server.

## Step 7: Rules per device
Apps → App Store → **Advanced Blocking** → Install → Config. Replace the sample with [advanced-blocking/config.json](advanced-blocking/config.json) and Save.

Change only two things:
1. `"192.168.1.50"` under `networkGroupMap`: your kid's laptop's IP.
2. The `blocked` list: the sites to block for that group (`youtube.com`, `tiktok.com` in the video).

Keep every other line, even the empty ones: each group needs them all. Then reserve that laptop's IP in your router (DHCP reservation / static lease), or it can get a new address and slip out of the group.

## Stop devices going around it
The DNS setting on a device is only a suggestion (`nslookup youtube.com 8.8.8.8` asks Google directly). To close that:
- **Router firewall:** allow port 53 (UDP + TCP) out only from your Technitium servers' IPs, and block port 53 out for every other device. Or use a DNS redirect / DNAT rule to Technitium.
- **Encrypted DNS (DoH) goes out on port 443**, so the port 53 rule can't stop it. Settings → Blocking → add HaGeZi's "Encrypted DNS servers only" list (Wildcard Domains format, the one HaGeZi lists for Technitium) and Save:
  ```
  https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/doh-onlydomains.txt
  ```
- Then in the **Blocked** tab, block `use-application-dns.net`. That's Firefox's canary domain: when it's blocked, Firefox turns its own DoH off.

## Step 8: A second server
Install Technitium on a second machine (Steps 1 and 2).

1. On dns1: Administration → Cluster → Initialize → New Cluster. Pick the cluster domain carefully (it can't be changed later) and enter dns1's IP. It creates its own certificate, so the servers talk encrypted.
2. On dns2 (set its admin password first): Administration → Cluster → Initialize ▾ → **Join Cluster**. Secondary Node IP = dns2's IP, Primary Node URL = dns1's HTTPS address shown on dns1's Cluster page (port 53443), Primary Node IP Address = dns1's IP (needed, dns2 can't look up dns1's cluster name), **Ignore Certificate Validation Errors** (self-signed), user `admin` + dns1's password. Joining overwrites dns2's settings, allowed/blocked lists and apps with dns1's.
3. Settings now copy from dns1 to dns2 by themselves (about 10 seconds in the video). Zones only copy if they're in the cluster catalog: Zones → your zone → Options → Zone Options → pick the cluster catalog → Save.

The cluster copies settings, but each server keeps its own IP, and while dns1 is off you can't change settings.

### One floating IP with keepalived (optional)
Your devices get one address (`192.168.1.60`) that moves to whichever server is alive. The full walkthrough is in the [Pi-hole High Availability video](https://youtu.be/UDNSbAFTXxQ) and [Pihole_HA](https://github.com/wetsand24/Pihole_HA). For Technitium only the health check changes.

On both servers:
```bash
sudo apt install -y keepalived dnsutils
ip -br a
```
Note your network card's name (first column, e.g. `eth0`, `ens18`).

| File | Goes to |
|---|---|
| [keepalived/check_technitium.sh](keepalived/check_technitium.sh) | `/etc/keepalived/check_technitium.sh` on both |
| [keepalived/keepalived-dns1.conf](keepalived/keepalived-dns1.conf) | `/etc/keepalived/keepalived.conf` on dns1 |
| [keepalived/keepalived-dns2.conf](keepalived/keepalived-dns2.conf) | `/etc/keepalived/keepalived.conf` on dns2 |

What to change:
- `check_technitium.sh`: set `CHECK_NAME` to a name in one of your zones (the `nas` record from Step 6). With the placeholder left in, the check always fails.
- Both `.conf` files: `interface`, `unicast_src_ip` (this server), `unicast_peer` (the other server) and `virtual_ipaddress` (a free IP outside your router's DHCP range). Change `virtual_router_id` only if something else on your network already uses 213.

```bash
sudo chmod 755 /etc/keepalived/check_technitium.sh
sudo /etc/keepalived/check_technitium.sh; echo $?
sudo systemctl restart keepalived
ip -br a
```
`0` = healthy. dns1 now shows its own IP plus the floating IP. Point your router's DHCP DNS at the floating IP only.

In the video: shutting down the main server, not one lookup failed. When Technitium crashed instead, one lookup failed and it answered again in about 8 seconds.

## Good to know
- DNS blocking won't remove YouTube ads or ads in most streaming apps; they come from the same servers as the video.

## Links
- Technitium DNS Server: https://technitium.com/dns/
- Source code: https://github.com/TechnitiumSoftware/DnsServer
- HaGeZi DNS block lists: https://github.com/hagezi/dns-blocklists
