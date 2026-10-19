# Mirai Malware Controler

## Global architecture

[**Client app**]
    |
(IPv6 TCP socket)
    |
[**Host daemon (Server)**]
    |
(AF_UNIX socket)
    |
[QEMU host backend] -> [Virtio-serial device] -> [**VM daemon**]

1. **Client** connects via IPv6 to **Host daemon**.
2. **Host daemon** forwards messages via **AF_UNIX** socket to **QEMU charatect device backend**.
3. **VM daemon** reads from **Virtio-serial** and controls the **Mirai malware**.

## Programs

### VM daemon

* Runs in the guest.
* Opens `/dev/virtio-ports/<name>` (char device) in read mode.
* Logs incoming messages.

### Host daemon

* Listens on an IPv6 TCP socket (e.g., `:::9000`).
* Listens/opens an AF_UNIX socket.
* When it receives a messages from the network client, sends it via AF_UNIX socket (to QEMU backend -> Virtio).

### Client

* Simple network app that connects to IPv6 address and port (e.g., `::1:9000`) and sends messages.

## QEMU configuration

When launching QEMU, one needs to configure:

> ```sh
> qemu-system-x86_64 \
>  -chardev socket,path=/tmp/vm_virtio.sock,server=on,wait=off,id=char0 \
>  -device virtserialport,chardev=char0,name=com.myvm.channel \
>  <other params...>
> ```

* `-chardev socket`: QEMU creates a UNIX socket server at `/tmp/vm_virtio.sock`.
* `-device virtserialport`: Inside the VM, this appears as `/dev/virtio-ports/com.myvm.channel`.

## Directory layout

> ```perl
> mirai_malware_controler/
> ├── client/
> │   ├── client.c
> │   ├── Makefile
> ├── host_daemon/
> │   ├── host_daemon.c
> │   ├── Makefile
> │   ├── host_daemon.service
> ├── vm_daemon/
> │   ├── vm_daemon.c
> │   ├── Makefile
> │   ├── vm_daemon.service
> └── README.md
> ```

## Build a Debian package

To build a `.deb` package manually, one needs:

* A **clean directory** structure.
* A special `DEBIAN/control` file with package metadata.
* The **binaries installed in the right filesystem tree** (`/usr/local/bin`, etc.).
* Optional systemd service files in `/etc/systemd/system` if you want auto-start.

Debian tools one will needs installed:

> ```sh
> sudo apt install build-essential devscripts dh-make debhelper fakeroot
> ```

### Directory layout for packaging

Imagine we are packaging `host_daemon`. We must create a tree like this:

> ```perl
> host_daemon_package/
> ├── DEBIAN/
> │   └── control
> ├── usr/
> │   └── local/
> │       └── bin/
> │           └── host_daemon
> ├── etc/
> │   └── systemd/
> │       └── system/
> │           └── host_daemon.service
> ```

* `DEBIAN/control` contains package metadata.
* `usr/local/bin/host_daemon` is the binary.
* `etc/systemd/system/host_daemon.service` is your systemd service file.

### Control file

Create a file `DEBIAN/control` with the following content:
