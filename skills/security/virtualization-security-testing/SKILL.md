---
name: virtualization-security-testing
description: Use when pentesting virtualized environments — Proxmox, VMware vSphere/ESXi, Hyper-V, KVM/QEMU, Xen, and LXC. Covers hypervisor discovery, VM escape paths, guest-to-host pivoting, disk/snapshot extraction, API exploitation, and known CVE references.
---

# Virtualization / Hypervisor Security Testing

Class-level umbrella for security testing of virtualized infrastructure. Virtualization hypervisors represent a critical trust boundary — compromising the hypervisor grants access to all guests. This skill chains together existing library skills and adds VM/hypervisor-specific techniques.

## Trigger Conditions

Load this skill when:
- The target environment includes Proxmox VE, VMware ESXi/vCenter, Microsoft Hyper-V, XenServer/XCP-ng, or KVM/QEMU hosts
- You need to assess VM escape risk or guest-to-host pivot paths
- You are extracting VM disk images, snapshots, or memory from hypervisor storage
- You need to test hypervisor management interfaces (web UI, SSH, APIs)
- You are auditing virtual networking (vSwitch, VXLAN, virtual bridging)

## Architecture Overview

```
Host OS (Linux/KVM, Windows/Hyper-V, ESXi)
├── Hypervisor (KVM, Hyper-V, VMware, Xen)
│   ├── Guest VM 1 (full virt / para-virt)
│   ├── Guest VM 2
│   └── Guest LXC / container (kernel-sharing)
├── Management Interface (Web UI / API / CLI)
│   ├── Proxmox: port 8006 (HTTPS web UI + REST API)
│   ├── ESXi:    port 443  (HTTP[S] web UI + SDK)
│   ├── vCenter: port 443  (web + API)
│   └── Hyper-V: port 5985/5986 (WinRM / PowerShell)
└── Storage Backend
    ├── Local (raw/qcow2/vmdk/vhdx images)
    ├── NFS / iSCSI / Ceph
    └── Snapshots (differencing disks / checkpoint files)
```

## Phase 1: Discovery & Reconnaissance

### Host Discovery
- Scan ports targeting hypervisor management interfaces
- Identify virtualization via MAC OUI (00:0C:29, 00:50:56 = VMware; 00:15:5D = Hyper-V; 52:54:00 = QEMU/KVM)
- Check SSH banners / HTTP Server headers for hypervisor product strings

**Applicable skills:** `scanning-network-with-nmap-advanced`, `conducting-external-reconnaissance-with-osint`, `performing-ssl-tls-security-assessment`

### Guest Fingerprinting
- Check for VMware Tools / Hyper-V Integration Services / QEMU Guest Agent
- Look for virtualized hardware strings: `dmesg | grep -i virtual`, `lscpu | grep Hypervisor`
- Detect VM escape surfaces (shared folders, drag-and-drop, clipboard sharing)
- Check paravirtualized drivers (virtio, vmw_pvscsi, hv_storvsc)

## Phase 2: Management Interface & API Testing

### Proxmox Specific
- **Web UI** (port 8006 HTTPS): test default creds (`root`:`proxmox` or `root` with no password in older versions)
- **REST API** at `/api2/json/`: enumerate nodes, VMs, storage, users
  - `GET /api2/json/access/ticket` — auth endpoint
  - `GET /api2/json/nodes` — node listing
  - `GET /api2/json/cluster/resources` — all resources
  - `GET /api2/json/access/users` — user enumeration
- **Known CVE surface:**
  - CVE-2023-2336 (auth bypass in pve-container)
  - CVE-2023-2337 (file read via symlink in pve-container)
  - CVE-2022-31256 (command injection in VZDump)
  - CVE-2021-3654 (XSS in NovaCombu)
  - CVE-2021-41510 (privilege escalation via API)
  - Pwn2Own targets (multiple years)

### VMware ESXi / vCenter
- **Web UI** (port 443): test default creds
- **SDK/API** at `/sdk/` and `/api/`
- **Known CVEs:**
  - CVE-2021-21972 (ESXi RCE in vCenter)
  - CVE-2021-21974 (OpenSLP heap overflow)
  - CVE-2022-22954 (vCenter SSRF)
  - Log4Shell (CVE-2021-44228) in vCenter

### Hyper-V
- **WinRM** (ports 5985/5986): PowerShell remoting
- **Known CVEs:**
  - CVE-2022-24492 (Hyper-V RemoteFX RCE)
  - CVE-2021-28476 (Hyper-V vmswitch heap overflow)
  - CVE-2021-26413 (Hyper-V vSock DDoS)

**Applicable skills:** `performing-web-application-penetration-test`, `conducting-api-security-testing`, `testing-for-broken-access-control`, `bypassing-authentication-with-forced-browsing`, `testing-api-security-with-owasp-top-10`, `exploiting-http-request-smuggling`

## Phase 3: VM Escape & Guest-to-Host

### LXC (Container) Escape — Kernel-Sharing Surface
- LXC containers share the host kernel — higher escape surface than full VMs
- Check for: `--privileged` mode, capabilities (`--cap-add SYS_ADMIN`, `--cap-add NET_ADMIN`), device cgroup exemptions
- Common escape vectors:
  - Mount host filesystem via device cgroup: `mknod /dev/sda1 b 8 1 && mount /dev/sda1 /mnt`
  - Abuse `notify_on_release` cgroup trick
  - `release_agent` escape via cgroup v1
  - `__dump_signal` race in older kernels

### KVM / QEMU Escape (Full VMs)
- Rarer but higher impact: escape from KVM guest to host
- Attack surface: QEMU device model emulation (e1000, virtio, floppy, USB)
- Known escapes: Venom (CVE-2015-3456 — FDC), CVE-2019-14835 (virtio-net),
  CVE-2021-20255 (e1000e), CVE-2021-3582 (JFS)

### VMware Guest Escape
- VMware Tools vulnerabilities (HGFS, drag-and-drop, shared folders)
- CVE-2017-4901 (drag-and-drop file copy)
- CVE-2019-5519 (VMCI)
- CVE-2023-20871 (vmxnet3)

### Hyper-V Guest Escape
- CVE-2022-30163 (Hyper-V RDP RCE from guest)
- CVE-2021-28476 (vmswitch — triggered from guest NIC)
- CVE-2022-23259 (Hyper-V remote code execution from guest)

**Applicable skills:** `performing-privilege-escalation-on-linux`, `scanning-network-with-nmap-advanced`, `exploiting-race-condition-vulnerabilities`, `performing-container-escape-detection`

## Phase 4: Disk & Snapshot Extraction

### Image Formats by Hypervisor
| Hypervisor | Format | Tools |
|---|---|---|
| Proxmox / KVM | qcow2, raw | qemu-img, qemu-nbd |
| VMware | vmdk (monolithic/split) | qemu-img, vmware-mount |
| Hyper-V | vhdx, vhd | qemu-img, DiskPart |
| Xen | raw, qcow2 | qemu-img |

### Extraction Techniques
- Mount qcow2 via NBD: `qemu-nbd --connect=/dev/nbd0 image.qcow2`
- Convert between formats: `qemu-img convert -O raw source.qcow2 disk.raw`
- Extract files from VMDK: `guestmount -a disk.vmdk -m /dev/sda1 /mnt/vm`
- Access snapshots: `qemu-img snapshot -l disk.qcow2`
- Revert to snapshot: `qemu-img snapshot -a <tag> disk.qcow2`

### Memory Extraction
- VMware: .vmem files (alongside .vmdk)
- Hyper-V: VM saved state (.bin, .vsv) — use volatility3 for analysis
- QEMU: use `pmemdump` or `avml` inside guest
- Proxmox: dump via `qm monitor <vmid>` then `dump-guest-memory`

**Applicable skills:** `acquiring-disk-image-with-dd-and-dcfldd`, `analyzing-memory-dumps-with-volatility`, `performing-memory-forensics-with-volatility`, `extracting-windows-event-logs-artifacts`

## Phase 5: Post-Exploitation & Lateral Movement

### VM-to-VM Lateral
- Virtual networking: test for promiscuous mode, forged transmits, MAC spoofing
- VXLAN / VXLAN bypass: if VTEP discovery is possible
- Shared storage: mount same datastore, access other VM disks
- Management network pivot: Proxmox/ESXi management network is VLAN-separated — bridge if guest NIC is on management VLAN

### Hypervisor Persistence
- Proxmox: cron on host, modified templates, manipulated backup scripts
- ESXi: VIB (vSphere Installation Bundle) backdoor, host profiles
- Hyper-V: PowerShell module persistence, integration services

### Evasion
- Disable guest agent (prevents hypervisor telemetry)
- Modify VM configuration without restart (Proxmox: `qm set <vmid>`)
- Use encrypted/templated disks to avoid inspection

**Applicable skills:** `conducting-internal-network-penetration-test`, `performing-lateral-movement-detection`, `analyzing-network-packets-with-scapy`, `conducting-man-in-the-middle-attack-simulation`

## Reference Files

- `references/proxmox-cve-history.md` — curated list of Proxmox VE CVEs
- `references/hypervisor-discovery-cheatsheet.md` — fingerprinting commands and port-based detection

## Pitfalls

- **Do not attempt VM escape payloads on production systems** — use isolated lab infrastructure (segmented Proxmox victims, Docker sandboxes). See SOUL.md Attack-to-Defense Doctrine.
- LXC containers share the host kernel — privilege escalation inside a container often IS host root. Treat container access as near-host access.
- qcow2 snapshots are differencing — the backing file must be present or merged to read the full image.
- Proxmox API rate-limits aggressively with newer versions; pace enumeration scans.
- ESXi host firewalls (services.md) block many ports by default — use the host IPMI/management network for full access.
- VM escape CVEs are rare and quickly patched — focus on management interface compromise as the higher-probability path.
- Many hypervisors ship with default TLS certs — don't confuse self-signed with vulnerability, but do note the potential for MITM.
