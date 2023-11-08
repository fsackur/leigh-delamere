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

## To do

VPN. I had planned to use tailscale, but OPNsense supports OpenVPN, which reduces moving parts.

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

### VPN server

1. Generate new cert for user in `System` > `Access` > `Users` > `Edit` > `User Certificates`   <!-- and export the cert and private key -->
2. `System` > `Trust` > `Certificates` > for the `OpenVPN Server` cert, `export user cert`
    - assume the download is called `Web+GUI+TLS+certificate.crt` for the next steps; amend as needed
3. `System` > `Trust` > `Certificates` > for the user cert, `export ca+user cert+user key in .p12 format`
    - use the user's password to protect the export
    - assume the download is called `freddie.p12` for the next steps; amend as needed
4. `VPN` > `OpenVPN` > `Client Export` >
    - extract the downloaded zip
    - assume the downloaded files are called `Remote_access.ovpn` and `Remote_access-tls.key` for the next steps; amend as needed
5. Rename:
    - `freddie.p12` => `freddie@opnsense.leigh.delamere.pfx`
    - `Web+GUI+TLS+certificate.crt` => `opnsense.leigh.delamere.crt`
    - `Remote_access.ovpn` => `opnsense.leigh.delamere.ovpn`
    - `Remote_access-tls.key` => `opnsense.leigh.delamere.tls.key`
6. Edit `opnsense.leigh.delamere.ovpn`:
    - `tls-auth Remote_access-tls.key 1` => `tls-auth opnsense.leigh.delamere.tls.key 1`
    - append `ca opnsense.leigh.delamere.crt`
    - append `pkcs12 freddie@opnsense.leigh.delamere.pfx`
7. Zip up the files as `opnsense.leigh.delamere.zip`

## VPN client

### Windows

Tested on Windows 11 with OpenVPN Community 2.6.6-I001

1. Install OpenVPN community edition (not Connect) from [openvpn.net](https://openvpn.net/community-downloads/) or with `winget install OpenVPNTechnologies.OpenVPN`
    - OpenVPN Connect 3.4.2 crashed every time, likely due to the self-signed certificate
    - Optionally, include OpenSSL, in case it's needed for processing pfx certs
    - If installation fails with an error about TAP drivers, try excluding `Wintun`
2. Create `OpenVPN\config` in your home folder, e.g. `C:\Users\Freddie\OpenVPN\config`
3. Extract zip to the config folder, so you have e.g. `C:\Users\Freddie\OpenVPN\config\opnsense\opnsense.leigh.delamere.ovpn`
4. Start `OpenVPN GUI`
5. Right-click on the systray icon > `Connect`

### Linux

4. Convert crt&key into .pfx:

    ```
    ❯ openssl pkcs12 -in /c/gitroot/leigh-delamere/vpn/freddie-freddie.crt -inkey /c/gitroot/leigh-delamere/vpn/freddie-freddie.key -out /c/gitroot/leigh-delamere/vpn/freddie-freddie.pfx -export
    Enter Export Password:
    Verifying - Enter Export Password:
    ```

    ```
    openssl pkcs12 -CAfile ./Web+GUI+TLS+certificate.crt -in freddie-freddie.crt -inkey freddie-freddie.key -out freddie-freddie.pfx -export
    ```

    ```
    openvpn --config .\Remote_access.ovpn --ca .\Web+GUI+TLS+certificate.crt --auth-user-pass pass --pkcs12 .\nopass.pfx
    ```
