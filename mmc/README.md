# MMC (Message to Machine Communication)

MMC is a system designed to facilitate communication between host machines and virtual machines (VMs) running under QEMU/KVM. It provides a secure and efficient way to send messages from any network machine to specific VMs using IPv6 multicast and virtual serial devices.

## System Architecture

The MMC system consists of three main components:

1. **mmc-vm-daemon**: A daemon running inside each VM that receives messages through a virtio-serial device and forwards them to a TCP server, then returns the response.
2. **mmc-host-daemon**: A daemon running on host machines that relays messages between the network (IPv6 multicast) and VMs through Unix sockets.
3. **mmc-cli**: A command-line interface for sending messages to VMs from any network machine.

### Communication Flow

```
[mmc-cli] --IPv6 Multicast--> [mmc-host-daemon] --Unix Socket--> [mmc-vm-daemon] --TCP--> [External Server]
                                                                                              |
[mmc-cli] <--IPv6 Multicast-- [mmc-host-daemon] <--Unix Socket-- [mmc-vm-daemon] <--TCP-- [External Server]
```

## Features

- IPv6 multicast-based communication
- Secure authentication using hash-based protocol
- Support for multiple simultaneous VM connections
- Simple command-line interface with readline support
- Configurable through JSON files
- Comprehensive logging system
- Graceful connection handling and reconnection
- Cross-platform support (AMD64, ARM64)
- Debian package support

## Installation

### Prerequisites

- Linux system with QEMU/KVM support
- IPv6 network with multicast support
- Debian-based system (Ubuntu, Debian)
- Root privileges for installation

### Quick Installation with Debian Packages

1. **Install dependencies**:
   ```bash
   # On host machine (AMD64)
   sudo ./install_dependencies.sh host
   
   # On target machine (ARM64)
   sudo ./install_dependencies.sh target
   ```

2. **Build Debian packages**:
   ```bash
   ./build_deb.sh
   ```

3. **Install packages**:
   ```bash
   # On host machine (AMD64)
   sudo dpkg -i deb-pkg/mmc-cli_1.1.0_amd64.deb
   
   # On ARM64 host device
   sudo dpkg -i deb-pkg/mmc-host-daemon_1.1.0_arm64.deb
   
   # Inside the VM running on the ARM64 device (copy the package to the VM first)
   sudo dpkg -i mmc-vm-daemon_1.1.0_arm64.deb
   ```

## Configuration

Each component requires a configuration file. By default, these are located in `/etc/mmc/`:

### VM Daemon Configuration (`mmc-vm-daemon-config.json`)
```json
{
    "serial_device": "/dev/virtio-ports/mmc0",
    "log_file": "/var/log/mmc-vm.log",
    "remote_ip": "127.0.0.1",
    "remote_port": 101,
    "tcp_response_timeout": 10
}
```

### Host Daemon Configuration (`mmc-host-daemon-config.json`)
```json
{
    "unix_socket_path": "/tmp/mmc.socket",
    "multicast_group": "ff02::1",
    "listen_interface": "eth0",
    "log_file": "/var/log/mmc-host.log",
    "response_message": "OK",
    "hash": "undef",
    "unix_socket_retry_delay": 20,
    "unix_socket_retry_count": 0
}
```

### CLI Configuration (`mmc-cli-config.json`)
```json
{
    "multicast_group": "ff02::1",
    "port": 12345,
    "interface": "eth0"
}
```

## Usage

### Setting up the VM

1. **Add a virtio-serial device to your QEMU/KVM VM configuration**:
   ```xml
   <devices>
     <channel type="unix">
       <source mode="bind" path="/tmp/mmc.socket"/>
       <target type="virtio" name="mmc0"/>
     </channel>
   </devices>
   ```

2. **Start the VM daemon inside the virtual machine**:
   ```bash
   # If installed via .deb package
   sudo systemctl start mmc-vm-daemon
   
   # If installed manually
   sudo mmc-vm-daemon
   ```

### Starting the Host Daemon

On the host machine running the VMs:
```bash
# If installed via .deb package
sudo systemctl start mmc-host-daemon

# If installed manually
sudo mmc-host-daemon
```

### Using the CLI

The CLI provides an interactive interface for sending messages to VMs:

```bash
# Start the CLI
mmc-cli
```

#### Available Commands

- **`SEND <message>`**: Send a message to all connected VMs
  - Maximum message length: 1019 characters
  - Example: `SEND Hello from host!`

- **`LIST`**: List all connected hosts with their hashes and IPv6 addresses
  - Shows authentication status and connection details

- **`DISPLAY_DB`**: Execute the display_db.sh script in all connected VMs
  - Runs the script locally in each VM and returns the output
  - Useful for database queries or system information gathering

- **`HELP`**: Show available commands and their descriptions

- **`EXIT` or `QUIT`**: Exit the program and notify all hosts of disconnection

#### Example Session

```bash
$ mmc-cli
MMC CLI started. Type 'HELP' for available commands.
mmc> LIST
Connected hosts (2):
1. Hash: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2g3h4, IPv6: fe80::1234
2. Hash: b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2g3h4i5, IPv6: fe80::5678

mmc> SEND Hello from host!
Message sent

mmc> [MMC-RESPONSE][a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2g3h4]: Server response: OK

mmc> DISPLAY_DB
Display DB command sent to all connected VMs

mmc> [MMC-RESPONSE][a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2g3h4]: Database records:
User: john, Status: active
User: jane, Status: inactive

mmc> EXIT
Notified 2 host(s) of disconnection
Goodbye!
```

## Authentication Protocol

The MMC system uses a hash-based authentication protocol:

1. **HELLO**: Host daemon sends a "hello-<hash>" message with a random 64-character hash
2. **WELCOME**: CLI validates the hash and responds with "welcome-<hash>"
3. **SEND**: Upon successful authentication, messages are sent with "SEND " prefix
4. **RESP**: Responses include "RESP <hash><message>" format
5. **END**: Connection termination message

### Message Format

- **Authentication**: `hello-<64-char-hash>` / `welcome-<64-char-hash>`
- **Commands**: `SEND <message>`
- **Responses**: `RESP <64-char-hash><message>`
- **Termination**: `END`

## Build Scripts

### `install_dependencies.sh`

Installs all required dependencies for building and running MMC components.

**Usage**:
```bash
sudo ./install_dependencies.sh [mode]
```

**Modes**:
- **`host`**: Install on AMD64 host machine for building mmc-cli (AMD64) and daemons (ARM64)
- **`target`**: Install on ARM64 target machine for running daemons

**What it installs**:
- Development tools (gcc, make, pkg-config, dpkg-dev)
- Libraries (libreadline-dev, libjson-c-dev, libssl-dev)
- Cross-compilation tools (for host mode)
- Runtime libraries

### `build_deb.sh`

Builds Debian packages for all MMC components.

**Usage**:
```bash
./build_deb.sh
```

**What it does**:
1. Builds mmc-cli for AMD64
2. Builds mmc-host-daemon and mmc-vm-daemon for ARM64
3. Creates Debian packages with proper dependencies
4. Includes systemd service files and configuration
5. Generates packages in `deb-pkg/` directory

**Generated packages**:
- `mmc-cli_1.1.0_amd64.deb`
- `mmc-host-daemon_1.1.0_arm64.deb`
- `mmc-vm-daemon_1.1.0_arm64.deb`

## Troubleshooting

### Common Issues

1. **Connection Failed**
   - Check if the multicast interface is correctly configured
   - Verify that IPv6 multicast is enabled on your network
   - Ensure the Unix socket path exists and has correct permissions
   - Check firewall settings for multicast traffic

2. **Authentication Errors**
   - Verify that all components are using the same protocol version
   - Check the logs for detailed error messages
   - Ensure multicast group addresses match across components

3. **VM Daemon Issues**
   - Verify virtio-serial device is properly configured in VM
   - Check serial device path in configuration
   - Ensure TCP server is running and accessible

### Logging

All components write detailed logs to their configured log files:

- **VM Daemon**: `/var/log/mmc-vm.log`
- **Host Daemon**: `/var/log/mmc-host.log`

**Log monitoring**:
```bash
# Monitor VM daemon logs
sudo tail -f /var/log/mmc-vm.log

# Monitor host daemon logs
sudo tail -f /var/log/mmc-host.log
```

### Debug Mode

For debugging, you can run components manually with verbose output:
```bash
# Run with debug output
sudo mmc-vm-daemon -c /etc/mmc/mmc-vm-daemon-config.json
sudo mmc-host-daemon -c /etc/mmc/mmc-host-daemon-config.json
mmc-cli -c /etc/mmc/mmc-cli-config.json
```

## Security Considerations

- The system uses a simple hash-based authentication
- Messages are sent in clear text over the network
- Access to the Unix socket should be properly restricted
- Consider using network encryption for sensitive data
- Hash generation uses cryptographically secure random numbers

## Development

### Project Structure
```
mmc/
├── include/
│   ├── mmc_common.h          # Common definitions and utilities
│   └── mmc_config.h          # Configuration structures
├── utils/
│   ├── mmc_common.c          # Common utility functions
│   └── mmc_config.c          # Configuration management
├── mmc-vm-daemon/
│   ├── mmc-vm-daemon.c       # VM daemon source
│   ├── mmc-vm-daemon-config.json
│   ├── mmc-vm-daemon.service
│   └── build.sh
├── mmc-host-daemon/
│   ├── mmc-host-daemon.c     # Host daemon source
│   ├── mmc-host-daemon-config.json
│   ├── mmc-host-daemon.service
│   └── build.sh
├── mmc-cli/
│   ├── mmc-cli.c             # CLI source
│   ├── mmc-cli-config.json
│   └── build.sh
├── build_deb.sh              # Debian package builder
├── install_dependencies.sh   # Dependency installer
└── README.md
```

### Building for Different Architectures

Individual components can be built for specific architectures:
```bash
# Build for specific architecture
cd mmc-cli && ./build.sh amd64 && cd ..
cd mmc-host-daemon && ./build.sh arm64 && cd ..
cd mmc-vm-daemon && ./build.sh arm64 && cd ..
```

Supported architectures:
- `amd64` (x86_64)
- `arm64` (aarch64)
- `arm` (armhf)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Commit your changes
6. Push to the branch
7. Create a Pull Request

## License

[Insert your license information here]

## Authors

[Insert author information here] 