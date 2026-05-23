# Hypervisor Discovery Cheatsheet

Quick-reference commands and fingerprints for identifying virtualized environments.

## MAC OUI Detection

| OUI Prefix | Hypervisor |
|---|---|
| `00:0C:29` | VMware |
| `00:50:56` | VMware |
| `00:05:69` | VMware |
| `00:1C:42` | Parallels |
| `00:15:5D` | Hyper-V (Windows 8+) |
| `00:03:FF` | Hyper-V (older) |
| `00:0F:4B` | Virtual Iron |
| `52:54:00` | QEMU/KVM (default) |
| `08:00:27` | VirtualBox |
| `00:A0:98` | Xen (HVM) |
| `00:16:3E` | Xen |
| `02:xx:xx:xx:xx:xx` | Random / transient (common in QEMU) |
| `56:xx:xx:xx:xx:xx` | QEMU-generated (user-mode NAT) |

## Linux Guest — Detect Hypervisor

```bash
# Check DMI info (most reliable)
sudo dmidecode -s system-manufacturer
sudo dmidecode -s system-product-name

# Check CPU flags
lscpu | grep -i hypervisor
grep -c 'hypervisor' /proc/cpuinfo   # non-zero = virtualized
grep -o 'hypervisor_vendor.*' /proc/cpuinfo

# Check /sys hypervisor boot param
cat /sys/hypervisor/type 2>/dev/null   # "xen", "kvm", "microsoft", etc.

# Check kernel ring buffer
dmesg | grep -iE 'virtual|hypervisor|kvm|xen|vmware|qemu|bochs'

# Check systemd
systemd-detect-virt

# Check device model strings
lspci | grep -iE 'vmware|virtualbox|qemu|bochs|xen|hyper-v'
lsusb | grep -iE 'vmware|qemu|virtualbox'

# VMware-specific
lsmod | grep vmw                 # vmw_vmci, vmwgfx, vmw_pvscsi
/usr/bin/vmware-checkvm          # installed with tools

# Hyper-V-specific
lsmod | grep hv_                 # hv_storvsc, hv_netvsc, hv_vmbus
sudo dmidecode | grep -i 'Microsoft'  # manufacturer = Microsoft Corporation

# KVM-specific
lsmod | grep kvm                 # kvm, kvm_intel, kvm_amd
cat /sys/devices/virtual/misc/kvm  # exists if host supports KVM

# Xen-specific
cat /proc/xen/capabilities 2>/dev/null   # "control_d" = dom0, empty = domU
lsmod | grep xen
```

## Windows Guest — Detect Hypervisor

```powershell
# Check system info
systeminfo | findstr /i "Hypervisor"

# Check registry
Get-ItemProperty HKLM:\HARDWARE\DESCRIPTION\System
# "SystemBiosVersion" often contains hypervisor name

# Check services
Get-Service -Name "vmtools", "VMware*", "VBox*", "xenevtchn"

# Device manager hidden devices
Get-WmiObject Win32_PnPEntity | Where-Object {$_.Name -match "VMware|VirtualBox|Hyper-V|Xen|QEMU"}

# Microsoft-specific
Get-WmiObject Win32_ComputerSystem | Select-Object Manufacturer,Model
# "Microsoft Corporation" + "Virtual Machine" = Hyper-V

# Check installed integration services
Get-WindowsFeature -Name *Hyper-V*
Get-Service -Name "Hyper-V*", "hv*"
```

## Port-Based Hypervisor Detection (Nmap)

```bash
# Proxmox detection
nmap -p 8006 -sV -T4 <target>
# Service should report: "Proxmox VE" or "PVE"

# ESXi detection
nmap -p 443,902 -sV -T4 <target>
# Port 902 = VMware authentication daemon
# Service banner: "VMware ESXi" or "VMware vCenter"

# Hyper-V WinRM detection
nmap -p 5985,5986 -sV -T4 <target>
# Check if HTTP headers mention "Microsoft-HTTPAPI"

# XenServer / XCP-ng detection
nmap -p 443 -sV -T4 <target>
# Port 443 may show Xen API or "XenServer"

# VirtualBox remote detection
nmap -p 18090-18100 -sV <target>
# VRDP (VirtualBox Remote Desktop Protocol)

# KVM/libvirt management detection
nmap -p 16509 -sV <target>
# libvirt TCP/TLS

# Generic HTTP fingerprinting
nmap --script http-title -p 443,8006,8080,8443 <target>
```

## Banner Grabbing

```bash
# HTTP server headers
curl -skI https://<target>:8006  # Proxmox
curl -skI https://<target>:443   # ESXi/vCenter
curl -skI http://<target>:80     # XenCenter (older)

# SSH banner
nc -w3 <target> 22 | grep -iE 'ssh|proxmox|vmware|xen|qemu'

# SNMP enumeration (if enabled)
snmpwalk -v2c -c public <target> | grep -iE 'vmware|proxmox|xen|hyper|virtual'
```

## Virtual Network Discovery

```bash
# Check virtual network interfaces
ip link show | grep -iE 'vmnic|vnic|eth\d\.\d+|vnet|veth|docker|br-.*'

# Bridge detection
brctl show 2>/dev/null
ip link show type bridge
ovs-vsctl show 2>/dev/null  # Open vSwitch (common in Proxmox/Xen)

# VMware vSwitch detection (within guest — limited)
# Best done on host or via management interface
```

## Proxmox-Specific Fingerprinting

```bash
# Version via API (unauthenticated)
curl -sk https://<target>:8006/api2/json/version

# Hostname detection
curl -sk https://<target>:8006/api2/json/nodes

# Check if SPICE/VNC console ports exposed
nmap -p 5900-5910,61000-61010 <target>

# Cluster detection
# Corosync port: 5404-5406 UDP
# Proxmox cluster communication
nmap -sU -p 5404-5406 <target>
```
