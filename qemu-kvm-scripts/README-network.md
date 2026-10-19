# qemu-kvm-scripts

## Network configurations

### Configuring an isolated virtual network

#### Network diagram with QEMU/KVM, TAP, bridge, and control interface

![Isolated Network](./img/isolatednetwork.png)

##### Explanation of the diagram elements

1. Bridge `br0` (**isolated network**)
   * It acts as a **virtual switch** allowing VMs to communicate with each other.
   * Connected to **TAP interfaces** (`tap0`, `tap1`, `tap2`, ...).
   * The **DHCP server** (`dnsmasq`) automatically assigns IP addresses in the `192.168.100.x` range.
2. **TAP interfaces** (`tap0`, `tap1`, `tap2`, ...)
   * Each VM has an isolated network interface connected to `br0` via a TAP interface.
   * This interface receives an **IP via DHCP** from `dnsmasq`.
3. **Control interface (NAT)**
   * Each VM has a **second network interface** for management.
   * This interface uses **the** `user` **mode** (`-netdev user`) for external access.
   * An IP is automatically assigned in the `10.0.2.0/24` range by QEMU.
   * The host can connect to VMs via **SSH**(`10.0.2.x)`).
4. `dnsmasq` (**DHCP server**)
   * Assigns IP addresses in the isolated network `192.168.100.10 - 192.168.100.100`.
