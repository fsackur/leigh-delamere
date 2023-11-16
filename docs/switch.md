# Netgear GS108 switch build notes

1. Default IP address is `192.168.0.239` - you will need to set a static IP address for initial config
2. Default password is `password`
3. Set static IP: `10.9.9.10` / `255.255.255.0` / `10.9.9.1`
4. `VLAN` > `802.1Q` > `Advanced` > `Enable`
5. Add VLANs as follows:

    | ID | Purpose |
    |----|---------|
    | 6  | WAN     |
    | 7  | LAN     |
    | 8  | Guest   |
    | 9  | Mgmt    |

6. `VLAN` > `802.1Q` > `Advanced` > `Port PVID` (this sets the VLAN for non-VLAN-aware devices)
    - all ports by default on PVID `7`
    - WAN port on PVID `6`
    - Trunk port (to Proxmox host) on PVID `9`
    - If still configuring, temporarily set your laptop port to PVID `9`
    - Burglar alarm on PVID `8`
7. `VLAN` > `802.1Q` > `Advanced` > `VLAN Membership` - ports can be blank, `U` or `T` - for not members, untagged, or tagged.

    | ID | Purpose |
    |----|---------|
    | 1  | set all to blank |
    | 6  | set WAN to `U`, set trunk port to `T` |
    | 7  | set WAPs (wifi access points) to `U`, set trunk port to `T` |
    | 8  | set burglar alarm port to `U`, set trunk port to `T` |
    | 9  | set trunk port to `T` |

    > N.B. WAPs need to be on ports 1-4, as those provide PoE
