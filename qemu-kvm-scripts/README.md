# qemu-kvm-scripts

## Getting started

### First step with Git

#### Optimize Git performance:

The following commands disable submodule summary, automatic fetching of submodules, and prevent Git form checking the latest commit in submodules.

> ```sh
> $ git config --global status.submoduleSummary false
> $ git config --global fetch.recurseSubmodules false
> $ git config --global diff.ignoreSubmodules dirty
> ```

To reverse this behaviour, use the following commands:

> ```sh
> $ git config --global --unset status.submoduleSummary
> $ git config --global --unset fetch.recurseSubmodules
> $ git config --global --unset diff.ignoreSubmodules
> ```

and,

> ```sh
> $ git config --global status.submoduleSummary true
> $ git config --global fetch.recurseSubmodules true
> $ git config --global diff.ignoreSubmodules none
> ```

#### Clone the repository wihtout fetching large LFS files

> ```sh
> $ git clone --recurse-submodules git clone --recurse-submodules https://github.com/user/qemu-kvm-scripts.git
> $ cd qemu-kvm-scripts
> ```

* This **clones** the repository and **initialises the submodules** (**isos** and **disk-images**).
* **Git LFS files will not be downloaded yet. Only small pointer files.

#### Ensure Git LFS is installed

Before working with LFS files, make sure Git LFS is installed:

> ````sh
> $ sudo apt install git-lfs -y
> ```

and,

> ````sh
> $ git lfs install
> ```

#### Check the FLS files without downloading

To **list** the files tracked by Git LFS but not yet downloaded, go to sub-module folders and use the follwing command:

> ````sh
> $ git lfs ls-files
> ```

#### Retrive the large LFS files (if needed)

If the you want to fetch the large files, go to sub-module folders and use the follwing command::

> ````sh
> $ git lfs pull
> ```

* This downloads **only the LFS files for the currently checked-out commit.

### Install required packages on the host (Debian)

On your **host machine (Debian)**, intall the necessary **QEMU**, **SPICE**, and **PulseAudio** packages:

> ```sh
> $ sudo apt update
> $ sudo apt install -y qemu-kvm qemu-utils qemu-system-x86 qemu-system-gui libvirt-daemon-system libvirt-clients virt-manager spice-client-gtk spice-client-glib-usb-acl-helper
> $ sudo apt install -y pulseaudio pulseaudio-utils
> ```

Ensure the **libvirtd** service is running:

> ```sh
> $ sudo systemctl enable --now libvirtd
> ```

### Install required packages on the guest (Ubuntu 22.04)

> ```sh
> $ sudo apt update
> $ sudo apt install -y spice-vdagent qemu-guest-agent
> ```

Enable and start the services:

> ```sh
> $ sudo systemctl enable --now spice-vdagent qemu-guest-agent
> ```

### Install required packages on the distant machine (Debian)

If you want to connect to a VM from a remote machine using the SPICE protocol, please install the following packages:

> ```sh
> $ sudo apt install virt-viewer spice-client-gtk
> ```

#### Check for errors

**Please note** that this subsection is no longer required.

If the services fail to start, check for errors in the system logs and their status:

> ```sh
> $ journalctl -xe | grep spice
> $ journalctl -xe | grep qemu-guest-agent
> ```

> ```sh
> $ systemctl status spice-vdagent
> $ systemctl status qemu-guest-agent
> ```

You may need to fix permission issue if you get the following error **"Failed to bind socket to /var/run/qemu-ga.sock: Permission denied"**. This means that QEMU doesn't have permission to create the socket.

1. Run this on the **host** to ensure the directory exists and is writable:
> ```sh
> $ sudo mkdir -p /var/run
> $ sudo chmod 777 /var/run
> ```
2. Check if another process is using the socket. If the file exists, delete it and try again:
> ```sh
> $ ls -l /var/run/qemu-ga.sock
> $ sudo rm /var/run/qemu-ga.sock
> ```
3. After fixing the socket issue, restart `qemu-guest-agent` in the **Ubuntu guest**.
> ```sh
> $ sudo systemctl restart qemu-guest-agent
> $ systemctl status qemu-guest-agent
> ```

### Add your user to necessary groups

Run the following command to add you user to the appropriate groups:

> ```sh
> $ sudo usermod -aG kvm,libvirt,dialout,input <your-username>
> ```

* `kvm`: Grants permission to use KVM.
* `libvirt`: Grants permission to use libvirt for managing virtual machines.
* `dialout`: Grants access to serial devices (e.g., `/dev/ttyUSB*`).
* `input`: Grants access to some input devices (e.g., for USB passthrough).

### QEMU VM management script

This script helps manage QEMU virtual machines with options for booting from an ISO, running in snapshot mode, and other configurations.

#### Uasge

> ```sh
> $ ./launch_vm.sh [OPTIONS]
> ```

#### Options

| Option       | Description                                                  |
|:-------------|:-------------------------------------------------------------|
| `--iso`      | Boot the VM from an ISO file.                                |
| `--disk`     | Boot the VM from the disk image (**default**).               |
| `--snapshot` | Run the VM in snapshot mode (**changes will not be saved**). |
| `--help`     | Display this help message and exit.                          |

#### VM parameters

The **VM parameters** are in the `./config/config.json` file and can be modified as required.

> ```sh
> {
>     "QEMU": "qemu-system-x86_64",
>     "VM_NAME": "ubuntu-22.04-vm",
>     "MEMORY": "32G",
>     "CPUS": "10",
>     "DISK_IMAGE": "./disk-images/ubuntu-22.04-image.qcow2",
>     "DISK_SIZE": "1000G",
>     "DISK_FORMAT": "qcow2",
>     "ISO_PATH": "./isos/ubuntu-22.04.5-desktop-amd64.iso",
>     "USERNAME_1": "joachim.schmidt",
>     "FOLDERS_TO_SHARE": ["/home/${USERNAME_1}", "/data"],
>     "SPICE_IP_ADDR": "0.0.0.0",
>     "_SPICE_IP_ADDR": "127.0.0.1",
>     "SPICE_PORT": "5900",
>     "USB_DEVICE_NAMES": ["FT232H"],
>     "DRIVER_FILE": "./drivers/drivers.json"
> }
> ```

#### Examples

##### Boot from ISO

If you haven't created your VM yet, you can create a new one by booting from an ISO image.

> ```sh
> $ ./launch_vm.sh --iso
> ```

##### Boot from disk (**default**)

> ```sh
> $ ./launch_vm.sh
> ```

or:

> ```sh
> $ ./launch_vm.sh --disk
> ```

##### Run in snapshot mode

> ```sh
> $ ./launch_vm.sh --snapshot
> ```

or:

> ```sh
> $ ./launch_vm.sh --disk --snapshot
> ```

##### Boot from ISO and use snapshot mode

> ```sh
> $ ./launch_vm.sh --iso --snapshot
> ```

##### Display help

> ```sh
> $ ./launch_vm.sh --help
> ```

### Connect to the VM using a SPICE client

Since you are running QEMU with SPICE, you **must use a SPICE client**.

On the host (Debian), open a SPICE session:

> ```sh
> $ remote-viewer spice://127.0.0.1:5900
> ```

If you do not have `remote-viewer`, install it:

> ```sh
> $ sudo apt install -y virt-viewer
> ```

### How to mount the shared folder

You need to use the `mount` command with the **9p** protocol.

> ```sh
> $ sudo mkdir /mnt/shared
> $ sudo mount -t 9p -o trans=virtio hostshare /mnt/shared
> ```

To add the `mount` command to the `/etc/fstab` file so that it mounts automatically at boot, you need to fill it in with the next entry:

> ```sh
> hostshare /mnt/shared 9p trans=virtio,defaults 0 0
> ```

You can use the following command to append the entry to `/etc/fstab`.

> ```sh
> $ echo "hostshare /mnt/shared 9p trans=virtio,defaults 0 0" | sudo tee -a /etc/fstab
> ```

* `hostshare`: The source (name of the 9p share).
* `/mnt/shared`: The mount point.
* `9p`: The filesystem type (Plan 9 filesystem).
* `trans=virtio,defaults`: Mount options:
  * `trans=virtio`: Uses virtio transport.
  * `defaults`: Includes standard options like `rw`, `suid`, `dev`, `exec`, `auto`, `nouser`, `async`.
* `0 0`: These numbers define dump and fsck settings:
  * First `0`: No dump.
  * Second `0`: No filesystem check on boot.

### SSH into the guest VM

On the **host machine** and since we forwarded SSH from **guest VM port 22** to **host port 4000**, you can connect to the guest VM via SSH:

> ```sh
> $ ssh -p 4000 user@127.0.0.1
> ```

### Create an SSH tunnel from your local machine

You must create an SSH tunnel to forward the SPICE port frome the remote machine to your local machine.

#### Verify SPICE is running

On the **host machine**, after running the VM, check if QEMU is listening on port **5900**.

> ```sh
> $ ss -tln | grep 5900
> ```

Expected output:

> ```sh
> LISTEN  0      4096         0.0.0.0:5900      0.0.0.0:*
> ```

#### Enable SSH port forwarding

On the **host machine**, edit the SSH config:

> ```sh
> $ sudo vim /etc/ssh/sshd_config
> ```

Ensure these lines exist (or are uncommented):

> ```sh
> AllowTcpForwarding yes
> GatewayPorts yes
> ```

Restart SSH:

> ```sh
> $ sudo systemctl restart ssh
> ```

#### Set up SSH tunnel on your local machine

On your **local machine**, create an SSH tunnel to forward SPICE:

> ```sh
> $ ssh -L 5902:127.0.0.1:5900 -N -f user@remote-host
> ```

* `-L 5902:127.0.0.1:5900`: Forwards **local port 5901** to **remote port 5900** (SPICE).
* `-N`: No remote shell (just forwarding).
* `-f`: Runs in the background.
* `user@remote-host`: Replace with you **remote username and IP/hostname**.

Check if the tunnel is working:

> ```sh
> $ ss -tln | grep 5902
> ```

Expected output:

> ```sh
> LISTEN  0      128    127.0.0.1:5902     0.0.0.0:*
> ```

#### Connect to the remote VM via SPICE

Now that the tunnel is running, connect using **SPICE client software**.

On your **local machine**, run:

> ```sh
> $ remote-viewer spice://127.0.0.1:5902
> ```
