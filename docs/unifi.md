# Unifi build notes

The wifi settings are configured centrally.

Ubiquiti APs ship with a default URL that they use to inform the console that they are available for adoption into the network.

They show up under `UniFi Devices` along with the existing APs. You can then click to adopt them.

Wifi is configured centrally. After adopting an AP, you must go to `Settings` > `WiFi` > click on the wifi network > `Broadcasting APs` tick the new AP.

> **WIFI STRENGTH**
>
> Do not crank up the transmitter power to improve wifi. This can have a detrimental effect, because the client devices may receive better but they can't transmit better. They merely take longer to disconnect from a weak AP and rehome to a closer one.
>
> The only way to improve wifi quality is to add more APs.

1. New Unifi access points find the controller by the default inform address, which is `http://unifi:8080/inform`. Name resolution should work for `unifi` and point to the server, and TCP 8080 should be reachable from the new AP.
2. If you can't do that, then:
    1. Find the new AP in your DHCP leases (for example, 10.7.7.53)
    2. SSH to it with `ssh ubnt@10.7.7.53` (password: `ubnt`)
    3. If not updated, they may only support archaic ciphers: `ssh -v -oHostKeyAlgorithms=+ssh-rsa -oPubkeyAcceptedAlgorithms=+ssh-rsa ubnt@10.7.7.53`
    4. Update the inform URL: `set-inform http://foo.bar:8080/inform`
3. The device should show up as "not adopted" in the console. Adopt it.
4. After adoption, they no longer allow login on the default password. Use the console login instead.
