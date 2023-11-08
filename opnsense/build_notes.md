# Opnsense build notes

## Background

OPNsense is based on FreeBSD, so a lot of the commands are different to linux.

Config is stored in `/conf/config.xml`. This is the same file you download under `System` > `Configuration` > `Backups` > `Download configuration`. As of 23.7, user passwords in the xml file are hashed and salted, but others are not (e.g. SMTP, SNMP), so care needs to be taken with backup storage.

Broadly speaking, the defaults are good. Not many settings needed tweaking.

## Design decisions

By default, LAN can access OPT, but not the other way round. The goal is to protect the management network from any nasties on the user network (or, in case of future change, the IoT network). Therefore, the user stuff is placed on OPT1, and firewall rules set up to allow the user network to access services.

It was not necessary to touch NAT at all. The automatic rules are sufficient.

Unbound DNS turned out to do most of what pihole does, so I just used that for DNS filtering. Pihole by default uses Steven Black's blocklist, which is a preset in Unbound.

Local service name resolution is done by creating static leases.

## Manual steps

1. Create non-root user in the GUI. Ensure you set the login shell and paste your public key under `authorized_keys`.
2. Install guest agent:

   ```bash
   sudo pkg install qemu-guest-agent
   sysrc qemu_guest_agent_enable="YES"
   sudo service qemu-guest-agent start
   ```

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
3. Packages for ease of use:
   - `pkg install bash nano` (then you can set your login shell to bash in the GUI)
   - copy over `.bash*` files in this repo to the home folder and `chmod +x` them (BSD bash does not ship with a `.bashrc` or have `/etc/skel`)
   - `sed -i.bak s/EDITOR=vi/EDITOR=nano/g ~/.profile && rm .profile.bak`
   - I could not find a package for `ip` in the community repo.
4. Package for ease of use: [opnsense-cli](https://github.com/mihakralj/opnsense-cli) (install instructions under "releases").
5. Enable non-root user for sudo:
    - Best to create the user in the GUI. Ensure you set the login shell and paste your public key under `authorized_keys`.
    - `EDITOR=nano visudo /usr/local/etc/sudoers.d/100-user`
    - copy the user line from `/usr/local/etc/sudoers.d/100-user`, editing username to suit
    - don't just copy the file over. This file is tricky and should only ever be edited with `visudo` for safety - that includes permissions

## VPN

### Dynamic DNS

1. Install `os-ddclient` plugin
2. `Services` > `Dynamic DNS` > `Add`:
    - Service: Cloudflare
    - Username: _leave blank_
    - Password: _Cloudflare API token_
    - Zone: `dvlp.casa`
    - Hostname: `leigh.delamere.dvlp.casa`
    - Check IP method: `Interface`
    - Interface to monitor: `WAN`
3. Cloudflare limits changes to once every 5 minutes, so if `leigh.delamere.dvlp.casa` does not resolve to the correct IP, wait 5 mins and try again.

### VPN config file

1. `VPN` > `OpenVPN` > `Client Export`
    - Export type: `File only`
    - Hostname: `leigh.delamere.dvlp.casa`
    - Custom config:

        ```plaintext
        ca Leigh_Delamere.crt
        ```

    - Click on the download for `(none) Exclude certificate from export` (because we don't require client certificates for authentication)
2. `System` > `Trust` > `Certificates` > for `OpenVPN Server`, do `export user cert`
3. Rename the OpenVPN Server certificate to `Leigh_Delamere.crt`
4. Both files (`Leigh_Delamere.ovpn` and `Leigh_Delamere.crt`) are required to be in the same folder for the client

Config files are here:

[Leigh_Delamere.ovpn](./VPN_client_config/Leigh_Delamere.ovpn)

[Leigh_Delamere.crt](./VPN_client_config/Leigh_Delamere.crt)

### Windows

Tested on Windows 11 with OpenVPN Community 2.6.6-I001:

1. Install OpenVPN community edition (not Connect) from [openvpn.net](https://openvpn.net/community-downloads/) or with `winget install OpenVPNTechnologies.OpenVPN`
    - Optionally, include OpenSSL, in case it's needed for processing pfx certs
    - If installation fails with an error about TAP drivers, try excluding `Wintun`
    - OpenVPN Connect 3.4.2 doesn't respect the DNS servers pushed from OpnSense 23.7; Community Edition works.
2. Create `OpenVPN\config\Leigh_Delamere` folder in your home folder, e.g. `C:\Users\Freddie\OpenVPN\config\Leigh_Delamere`
3. Copy `Leigh_Delamere.ovpn` and `Leigh_Delamere.crt` to the config folder, so you have e.g. `C:\Users\Freddie\OpenVPN\config\Leigh_Delamere\Leigh_Delamere.ovpn`
4. Start `OpenVPN GUI`
5. Right-click on the systray icon > `Connect`

### Linux

Tested on Ubuntu 23.10 with OpenVPN 2.6.5:

1. Put both files (`Leigh_Delamere.ovpn` and `Leigh_Delamere.crt`) somewhere
2. `openvpn --config ./Leigh_Delamere.ovpn`

#### Issues

- You could use `nohup` to not tie up the console, but that presents issues with interactive auth. Use `--auth-user-pass <passwd_file>`.
- DNS not respected, AFAICS.
