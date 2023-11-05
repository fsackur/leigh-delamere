# Proxmox build notes

## Context

Proxmox is free to use without a subscription. However, it displays a nag screen on login and you have to explicitly add the community repository to receive updates.

> TODO: remove the nag screen. There is a function in `/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js` but it's an arms race, so proxmox break working solutions on updates, and my perl skills aren't up to reliably editing javascript. Possibly in a docker container?

## Manual steps

1. Install Proxmox VE 8.0.2 from USB
2. Browse to [https://10.9.9.2:8006](https://10.9.9.2:8006) (or whatever the IP address is)
3. Node > Updates > Repositories
    1. Add repository `No-Subscription`
    2. Disable `ceph` and `pve-enterprise` repositories (because they require a subscription)
4. Rename node according to the [wiki](https://pve.proxmox.com/wiki/Renaming_a_PVE_node) - this must be done before creating VMs
    1. `/etc/hosts`
    2. `/etc/hostname`
    3. `/etc/mailname` (this may not exist)
    4. `/etc/postfix/main.cf`
5. Set web UI port according to the [wiki](https://pve.proxmox.com/wiki/Web_Interface_Via_Nginx_Proxy):

    ```bash
    apt update
    apt install -y nginx

    rm /etc/nginx/sites-enabled/default
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
        ssl_certificate /etc/pve/local/pve-ssl.pem;
        ssl_certificate_key /etc/pve/local/pve-ssl.key;
        proxy_redirect off;
        location / {
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_pass https://localhost:8006;
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
    EOF

    systemctl daemon-reload
    systemctl enable nginx
    systemctl start nginx
    ```
6. Install sudo:

    ```bash
    apt install sudo
    echo "freddie ALL=(ALL:ALL) ALL" >> /etc/sudoers.d/100-user
    ```
