# Ubuntu Server Autoinstall + Pterodactyl Provisioning Tool

A small utility that takes a standard **Ubuntu Server LTS ISO** and adds:

- a minimal autoinstall configuration  
- a post‑install provisioning script  
- automatic setup of **Pterodactyl Panel + Wings**  
- the required services (Docker, MariaDB, Redis, PHP, NGINX)  

The result is a custom ISO that installs Ubuntu Server with **minimal user interaction** and prepares a LAN‑only Pterodactyl host for running game servers.

This is a helper tool for personal use, learning, and small private setups — not a commercial product.

---

## Purpose and Scope

The goal is to simplify the process of preparing a small machine to act as a **local game‑server host** using Pterodactyl. It removes repetitive setup steps and bundles them into a single ISO build process.

This project is intentionally modest in scope:

- It does **not** aim to be a full automation framework.  
- It does **not** aim to cover every Pterodactyl configuration.  
- It does **not** attempt to manage SSL, domains, or public‑facing deployments.  
- It is meant for **trusted LAN environments**, not internet‑exposed servers.

---

## Who This Is For

This tool is intended for:

- hobbyists hosting game servers for friends  
- people who want a simple LAN‑only Pterodactyl setup  
- users who prefer automation over manual installation  
- small home labs or local machines behind a router firewall  

It assumes:

- the machine is on a **trusted LAN**  
- the router/firewall protects it  
- only game server ports are exposed externally  
- the Pterodactyl panel stays **LAN‑only**  
- the user is comfortable with basic command‑line steps  

It is **not** intended for production, enterprise, or public hosting.

---

## What the Tool Actually Does

- Extracts a standard Ubuntu Server ISO  
- Injects autoinstall configuration and postinstall scripts  
- Patches GRUB to boot into autoinstall mode  
- Rebuilds a bootable ISO  
- During installation, the system:
  - asks the user to confirm the DHCP‑assigned IP (network config is intentionally minimal)  
  - installs required packages  
  - deploys Pterodactyl Panel  
  - deploys Wings  
  - configures firewall rules for LAN use  
  - creates admin accounts using credentials provided during ISO creation  
  - enables systemd services  

The final machine boots into a ready‑to‑use Pterodactyl environment on the LAN.

---

## Installation Flow

1. Place a supported Ubuntu Server LTS ISO in the project directory.  
2. Run the build script.  
3. Choose a provisioning branch.  
4. Enter the credentials that will be injected into the ISO.  
5. The tool extracts the ISO, injects files, replaces placeholders, and rebuilds a new ISO.  
6. Burn or mount the resulting ISO.  
7. Boot the target machine.  
8. During install, confirm the DHCP network assignment.  
9. Autoinstall completes and provisioning runs automatically.  
10. Access the Pterodactyl panel from another device on the LAN.

---

## Security and Responsibility

This project is designed for **LAN‑only** use. You are responsible for:

- choosing strong passwords  
- securing your network  
- keeping your system updated  
- understanding the risks of exposing services to the internet  

The author is **not responsible** for:

- security issues in your deployment  
- misconfigured networks or firewalls  
- vulnerabilities in Ubuntu, Subiquity, cloud‑init, or autoinstall  
- vulnerabilities in Pterodactyl Panel or Wings  
- any damage, data loss, or misuse of this tool  

This is a personal/portfolio project and a helper for friends, not a supported product.

---

## Network Considerations: Carrier‑Grade NAT (CGNAT)

Some internet providers place customers behind Carrier‑Grade NAT (CGNAT). This means the customer does not receive a true public IPv4 address, and inbound connections from the internet may not reach the machine directly.

This matters only if the user intends to make game servers accessible from outside their home network.
The Pterodactyl panel itself is LAN‑only by design in this project.
What CGNAT means for the user

    Port forwarding on the home router may not work.

    Friends outside the LAN may not be able to join hosted game servers.

    The machine may appear to have a public IP, but inbound traffic never reaches it.

    Troubleshooting becomes confusing because everything looks correct locally.

Why this project mentions it

During our attempt to implement the resulted ISO, CGNAT was the single biggest obstacle encountered.
The server installed correctly, Pterodactyl worked, Wings worked, Docker worked — but external players could not connect because the ISP blocked inbound traffic at the carrier level.
What the user can do about it

    Check whether their ISP uses CGNAT.

    Request a public IPv4 address (some ISPs provide one on request).

    Use IPv6 if supported by the game and the ISP.

    Use a VPN with port‑forwarding capabilities.

    Host the server only for LAN players.

Planned helper tool

A small “Am I behind CGNAT?” checker will be added later to help users identify this issue early.
This avoids wasted time debugging a network limitation that cannot be fixed from the machine itself.

---

## Acknowledgements

Respect and thanks to the teams who built the real technology:

- **Canonical** — Ubuntu Server, Subiquity, autoinstall, cloud‑init  
- **Pterodactyl Project** — Panel, Wings, Eggs, documentation  
- **Docker, MariaDB, Redis, PHP, NGINX** — core infrastructure components  

This tool does not modify or redistribute their software.  
It only automates installation and configuration.

---

## License

Released under the **MIT License**.

---
