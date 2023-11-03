# Opnsense build notes

## Background

OPNsense is based on FreeBSD, so a lot of the commands are different.

Config is stored in `/conf/config.xml`. This is the same file you download under `System` > `Configuration` > `Backups` > `Download configuration`. As of 23.7, user passwords in the xml file are hashed and salted, but others are not (e.g. SMTP, SNMP), so care needs to be taken with backup storage.

Broadly speaking, the defaults are good. Not many settings needed tweaking.

## Design decisions

By default, LAN can access OPT, but not the other way round. The goal is to protect the management network from any nasties on the user network (or, in case of future change, the IoT network). Therefore, the user stuff is placed on OPT1, and firewall rules set up to allow the user network to access services.

It was not necessary to touch NAT at all. The automatic rules are sufficient.

Unbound DNS turned out to do most of what pihole does, so I just used that for DNS filtering. Pihole by default uses Steven Black's blocklist, which is a preset in Unbound.

Local service name resolution is done by creating static leases.

## To do

VPN. I had planned to use tailscale, but OPNsense supports OpenVPN, which reduces moving parts.

## Nuisances and fixes

1. I had issues with hardware offloading. Ensure you leave `Interfaces` > `Settings` > disable hardware `CRC`, `TSO` and `LRO` ticked.
    1. With CRC enabled, the web page wouldn't really load. Fix:
        - log into shell through proxmox
        - do `ifconfig vtnet1 -lro -lro6`, etc, for each interface
        - `ifconfig` reveals which offload features are enabled
        - this fixes temporarily, so you can go into the GUI and tick the damn boxes
    2. With TSO enabled, I got endless TCP retransmissions, visible in Wireshark but not in the firewall logs. This broke access across network segments, but not the web gui.
    3. I'm not even mucking with `LRO`. Just disable it.
2. Issues with SSH and sudo - because bracketed paste randomly turns on, so pasting a complex password fails. If you paste something and it's wrapped in `00~`/`01~`, that's the issue.
    - Fix (hopefully): copy over `/etc/inputrc` and `chmod 755`
3. Enabling new user for sudo:
    - Best to create the user in the GUI. Ensure you set the login shell and paste your public key under `authorized_keys`.
    - `visudo /usr/local/etc/sudoers.d/100-user`
    - copy the user line from `/usr/local/etc/sudoers.d/100-user`, editing username to suit
    - if you don't know vi, it's weird:
        - if it doesn't enter text, press the `i` key
        - when finished, press `Esc` then type `:wq` and press `Enter`
    - don't just copy the file over. This file is tricky and should only ever be edited with `visudo` for safety
4. Packages for ease of use: `pkg install bash nano` (then you can set your login shell to bash in the GUI). I could not find a package for `ip` in the community repo.
5. Package for ease of use: [opnsense-cli](https://github.com/mihakralj/opnsense-cli) (install instructions under "releases").
