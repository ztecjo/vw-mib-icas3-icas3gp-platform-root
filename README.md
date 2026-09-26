# VW MIB ICAS3 / ICAS3GP Platform — USB Auto-Execution to Root

**Researcher:** Saif Alzyoud ([ZTECJO](https://www.ztecjo.com) · [Alzyoud.org](https://www.alzyoud.org))  
**Found:** early 2022  
**Tested on ICAS3:** 2022–2023  
**Tested on ICAS3GP:** late 2023 – early 2024  

Early public research / first documented public PoC of this **ICAS3GP USB → root** path (to our knowledge).

### Timeline

| When | What |
|------|------|
| **Early 2022** | Vulnerability first found |
| **2022–2023** | Tested / validated on **ICAS3** |
| **Late 2023 – early 2024** | Tested / validated on **ICAS3GP** |

---

## Summary

Physical USB insert causes the head unit to auto-run an unsigned shell script as **root**, yielding full control of the **AGL** guest and lateral root on the **QNX** host on VW MEB **ICAS3** / **ICAS3GP** (Samsung Exynos Auto + AGL + QNX + Android).

From that foothold you can go deeper into **all OS domains** inside the infotainment system — including the **Android VM**, which communicates with the other guests over **TCP/UDP network bridges** — and onward toward **vehicle-connected** paths exposed from the IVI.

Works on **production units with secure boot enabled**; the same SSH access path remains valid.

| Unit | SoC | Notes |
|------|-----|--------|
| **ICAS3** | Samsung V700F | Earlier MEB IVI — hardware + UART documented here |
| **ICAS3GP** | Samsung V700F31 (`S5AHR80AD0`) | Newer generation — primary exploit confirmation |

Both run **AGL + QNX + Android** as guests under a hypervisor.

---

## Core finding

On USB mount (`/tmp/USB/PORT1/PART1/`), the IVI stack:

1. Looks for engineering hooks (e.g. `tcpsniffer/start_tcpsniffer.sh`)
2. Invokes **`lg.sh`** via **`RunAutoHmiUpdate` / `HmiUpdate`**

That script runs **immediately on insert**, as **root** (`uid=0`), with `sh`/`bash`. No signed update package is required for this path.

PoC script: [`scripts/lg.sh`](scripts/lg.sh)

---

## Impact chain

1. Root on AGL IVI guest (`euto-v7-icas3cn-gp`)
2. Lateral root on QNX host (`ICAS3-HOST`) via internal guest networking
3. Cross-guest reach across **all OS domains** in the infotainment stack (**AGL + QNX + Android**)
4. From there, deeper access into the **Android VM**, which talks to the other guests over **TCP/UDP network bridges** (internal virtual networking between VMs)
5. Same bridging path can extend toward **vehicle-facing** interfaces / domains reachable from the compromised IVI (car-side services behind the head unit)
6. Boot-mode control via RPMB (baremetal / recovery / fastboot / default) — see [`docs/codes_for_reboot_qnx.txt`](docs/codes_for_reboot_qnx.txt)

**Bottom line:** this USB→root PoC is not limited to a single guest shell — it is a foothold into the full multi-OS IVI architecture and a bridge toward Android and vehicle-connected domains.

---

## UART debug

A **UART debug port** is present on the PCB (4-pin connector). It exposes boot / hypervisor console output (loader, VM bring-up, vbpipe, secure-boot status lines, etc.) useful for correlating the multi-OS boot chain.

Full UART capture from **ICAS3 hardware**: [`docs/ICAS3_UART_00000012_20200923_081024.log`](docs/ICAS3_UART_00000012_20200923_081024.log) — includes the USB → `RunAutoHmiUpdate` → `lg.sh` call.

Photo of UART serial session: [`images/icas3/05_uart_boot_log_yat.jpeg`](images/icas3/05_uart_boot_log_yat.jpeg)

UART is for research / boot visibility — the **primary exploit vector is USB auto-exec**, not UART.

---

## Repository layout

```text
vw-mib-icas3-icas3gp-platform-root/
├── README.md
├── scripts/
│   └── lg.sh                          # USB auto-exec PoC (runs as root on insert)
├── docs/
│   ├── ICAS3_UART_00000012_20200923_081024.log  # ICAS3 HW UART log (shows lg.sh auto-call)
│   ├── PCB_INFO.txt                   # disp_sysinfo dump (ICAS3GP)
│   └── codes_for_reboot_qnx.txt       # RPMB boot-mode values
├── images/
│   ├── icas3/                         # ICAS3 hardware + UART
│   ├── icas3gp/                       # ICAS3GP hardware + bench
│   └── poc/                           # SSH root stills (AGL + QNX)
└── poc/
    └── IMG_8292_ICAS3GP_root_poc.MOV  # Full live root PoC (~1:51)
```

---

## Log evidence — script auto-call

File: [`docs/ICAS3_UART_00000012_20200923_081024.log`](docs/ICAS3_UART_00000012_20200923_081024.log) — **UART log from ICAS3 hardware** (same USB auto-exec path later confirmed on ICAS3GP).

```text
[Settings] USB status : INSERTED
[Settings] USB status : MOUNTED
Couldn't find /tmp/USB/PORT1/PART1/tcpsniffer/start_tcpsniffer.sh on USB stick

HmiUpdate.cpp ... mount file path : /tmp/USB/PORT1/PART1/
HmiUpdate.cpp ... lg : /tmp/USB/PORT1/PART1/lg.sh

UNodeBlock.cpp RunAutoHmiUpdate 547  file:/tmp/USB/PORT1/PART1/lg.sh doesn't exist
```

In that capture the stick had no `lg.sh` yet — the important part is **`RunAutoHmiUpdate` hard-wired to invoke `lg.sh` on mount**. With `lg.sh` present, it runs as root on insert.

---

## PoC evidence

### Video (full ICAS3GP root)

[`poc/IMG_8292_ICAS3GP_root_poc.MOV`](poc/IMG_8292_ICAS3GP_root_poc.MOV) — ~1:51, 1080p

| Time | What happens |
|------|----------------|
| 0:00 | Open ICAS3GP PCB / heatsink on bench |
| ~0:15 | Display on bench — normal home UI |
| ~0:30 | Network hotspot enabled (unit reachable for SSH) |
| ~0:45 | PuTTY → `10.173.189.1`, login as **root** |
| ~1:00 | `root@euto-v7-icas3cn-gp:F244.07` · `id` → `uid=0(root)` |
| ~1:15 | AGL/IVI filesystem listing |
| ~1:30–1:50 | Pivot to `root@ICAS3-HOST:F244.07_221103` (QNX host) |

### Stills

| File | Proof |
|------|--------|
| [`images/poc/SSH_ROOT_AGL_VM.png`](images/poc/SSH_ROOT_AGL_VM.png) | Root on AGL guest `euto-v7-icas3cn-gp` / F244.07 |
| [`images/poc/SSH_ROOT_QNX_MAIN_HOST.png`](images/poc/SSH_ROOT_QNX_MAIN_HOST.png) | Lateral root on QNX `ICAS3-HOST` / F244.07_221103 |

---

## Hardware gallery — ICAS3

| Image | Description |
|-------|-------------|
| [`01_bench_uart_setup.jpeg`](images/icas3/01_bench_uart_setup.jpeg) | Bench setup — unit + UART/serial to host |
| [`02_pcb_overview.jpeg`](images/icas3/02_pcb_overview.jpeg) | PCB overview — V700F area, MCU, Fakra I/O |
| [`03_pcb_soc_uart.jpeg`](images/icas3/03_pcb_soc_uart.jpeg) | SoC module + **UART 4-pin** at board edge |
| [`04_incar_system_info.jpeg`](images/icas3/04_incar_system_info.jpeg) | In-car System info (`10A035844D`, HW C06, SW 1516) |
| [`05_uart_boot_log_yat.jpeg`](images/icas3/05_uart_boot_log_yat.jpeg) | UART boot log (YAT) — hypervisor VMs, `qnx-ivi-and` |
| [`06_glovebox_ecu.jpeg`](images/icas3/06_glovebox_ecu.jpeg) | ICAS3 ECU behind glovebox in MEB ID vehicle |

---

## Hardware gallery — ICAS3GP (bench)

Target: Samsung **V700F31 / S5AHR80AD0**, application sticker **(Tavascan)**.  
UI match: part **`10C035878`**, HW **G04**, SW **F244** (aligns with SSH host `F244.07`).

| Image | Description |
|-------|-------------|
| [`01_pcb_chassis_harness.jpeg`](images/icas3gp/01_pcb_chassis_harness.jpeg) | Disassembled PCB + housing + harness |
| [`02_bench_power_fakra.jpeg`](images/icas3gp/02_bench_power_fakra.jpeg) | Bench power (+12V/GND) + Fakra loom |
| [`03_display_system_info_f244.jpeg`](images/icas3gp/03_display_system_info_f244.jpeg) | Live System information (F244) |
| [`04_display_rear_connectors.jpeg`](images/icas3gp/04_display_rear_connectors.jpeg) | Rear of display / bench connectors |
| [`05_display_home_bench.jpeg`](images/icas3gp/05_display_home_bench.jpeg) | Home menu on bench platform |
| [`06_pcb_heatsink_fan.jpeg`](images/icas3gp/06_pcb_heatsink_fan.jpeg) | PCB with heatsink + fan |
| [`07_enclosure_closed.jpeg`](images/icas3gp/07_enclosure_closed.jpeg) | Closed black enclosure (pre-open) |
| [`08_soc_v700f31_lid.jpeg`](images/icas3gp/08_soc_v700f31_lid.jpeg) | SoC lid: **V700F31 / S5AHR80AD0** |
| [`09_soc_ufs_detail.jpeg`](images/icas3gp/09_soc_ufs_detail.jpeg) | SoC + UFS + RF detail |
| [`10_full_bench_14v.jpeg`](images/icas3gp/10_full_bench_14v.jpeg) | Full lab: display + 14.0V PSU + open PCB |
| [`11_pcb_fakra_cables.jpeg`](images/icas3gp/11_pcb_fakra_cables.jpeg) | Fakra/HSD links + harness |

More unit details: [`docs/PCB_INFO.txt`](docs/PCB_INFO.txt)

---

## Disclaimer

This repository documents historical security research for educational and defensive purposes (OEM hardening, awareness). Do not use against systems you do not own or lack authorization to test.

---

## Author

**Saif Alzyoud**  
- https://www.ztecjo.com  
- https://www.alzyoud.org  

Copyright (c) Saif Alzyoud / ZTECJO. All rights reserved.
