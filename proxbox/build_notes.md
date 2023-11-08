# Proxmox build notes

## Context

Proxmox is free to use without a subscription. However, it displays a nag screen on login and you have to explicitly add the community repository to receive updates.

It is based on Debian 12, so use that when searching how to do things in the shell.

> TODO: remove the nag screen. There is a function in `/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js` but it's an arms race, so proxmox break working solutions on updates, and my perl skills aren't up to reliably editing javascript. Possibly in a docker container?

## Manual steps

1. Install Proxmox VE 8.0.2 from USB
2. Browse to [https://10.9.9.2:8006](https://10.9.9.2:8006) (or whatever the IP address is)
3. `Node` > `Updates` > `Repositories`
    1. Add repository `No-Subscription`
    2. Disable `ceph` and `pve-enterprise` repositories (because they require a subscription)
4. Install sudo: `apt update && apt install sudo`
5. Create non-root user account:

    ```bash
    adduser freddie
    # paste password (twice)
    # just hit return for room number, work phone, etc

    # Grant sudo rights:
    /usr/sbin/visudo /etc/sudoers.d/100-user
    # paste in as follows:
    freddie ALL=(ALL:ALL) ALL

    # Grant key-based SSH:
    cd /home/freddie
    mkdir .ssh
    chown freddie:freddie .ssh
    chmod 700 .ssh

    # replace with your own public key
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEffBykA/0JEvwZ0XXaoOusrugan/uG6KBZ/CqepKUZA freddie@leigh.delamere" >> .ssh/authorized_keys

    chown freddie:freddie .ssh/authorized_keys
    chmod 700 .ssh/authorized_keys
    ```

    Then, in the web UI:

    - `Datacenter` > `Permissions` > `Groups` > create group `Admins`
    - `Datacenter` > `Permissions` (no submenu) > `Add` > `Group permission`
      - path: `/`
      - group: `Admins`
      - role: `Administrator`
      - propagate: yes
    - `Datacenter` > `Permissions` > `Users` > `Add`
      - same username and password
      - realm: `PAM`
      - group: `admins`
    - when logging in, set realm to `PAM`

6. Set web UI to listen on default port, according to the [wiki](https://pve.proxmox.com/wiki/Web_Interface_Via_Nginx_Proxy):

    ```bash
    apt update
    apt install -y nginx
    rm /etc/nginx/sites-enabled/default

    CERT_FILE="/etc/pve/local/pve-ssl.pem"
    KEY_FILE="/etc/pve/local/pve-ssl.key"
    PROXMOX_PORT=8006
    cat << EOF > /etc/nginx/conf.d/proxmox.conf
    upstream proxmox {
        server "$(hostname -f)";
    }

    server {
        listen 80 default_server;
        rewrite ^(.*) https://\$host\$1 permanent;
    }

    server {
        listen 443 ssl;
        server_name _;
        ssl_certificate $CERT_FILE;
        ssl_certificate_key $KEY_FILE;
        proxy_redirect off;
        location / {
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_pass https://localhost:$PROXMOX_PORT;
        proxy_buffering off;
        client_max_body_size 0;
        proxy_connect_timeout  3600s;
            proxy_read_timeout  3600s;
            proxy_send_timeout  3600s;
            send_timeout  3600s;
        }
    }
    EOF

    mkdir -p /etc/systemd/system/nginx.service.d/
    cat << EOF > /etc/systemd/system/nginx.service.d/override.conf
    [Unit]
    Requires=pve-cluster.service
    After=pve-cluster.service

    [Service]
    Restart=on-failure
    RestartSec=10
    EOF

    systemctl daemon-reload
    systemctl enable nginx
    systemctl restart nginx
    ```

    Now you can access the server at [https://proxbox/](https://proxbox/) - or you will, once you've set up DNS in OPNsense.
