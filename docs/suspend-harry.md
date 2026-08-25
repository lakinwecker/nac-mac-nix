# harry (Surface Pro 9) — s2idle suspend

## Symptom

Close the lid, and sometimes the machine does not come back. Screen black, no
input, appears dead. It is not dead — it suspends correctly and then takes
minutes to resume. Both "crashes" on 2026-08-24 were power-cycles of a machine
that was still working through the resume.

Journal always ends at `PM: suspend entry (s2idle)` with no oops or panic,
because that is what a successful suspend looks like.

## Cause

The ACPI PM1 and GPE0 register blocks are nested inside a PCI hotplug bridge's
I/O window. `/proc/ioports`:

```
PCI Bus 0000:00
  PCI Bus 0000:02          <- Thunderbolt hotplug bridge (00:07.0 -> bus 02-79)
    ACPI PM1a_EVT_BLK
    ACPI PM1a_CNT_BLK
    ACPI PM_TMR
    ACPI PM2_CNT_BLK
    ACPI GPE0_BLK
```

How they got there:

```
pci 0000:00:07.0: bridge window [io 0x1000-0x0fff] to [bus 02-79] add_size 1000
pci 0000:00:07.0: bridge window [io 0x1000-0x1fff]: assigned
```

When 00:07.0 drops power state during s2idle its I/O decode goes away, so reads
of PM1a_EVT_BLK and GPE0_BLK return all-ones. Every GPE and every fixed event
reads asserted — the counters confirm it, all incrementing in lockstep:

```
ff_pwr_btn  11029 STS invalid     gpe51  11028 invalid
ff_pmtimer  11029 invalid         gpe53  11028 invalid
ff_slp_btn  11029 invalid         ...
sci 11030   gpe_all 352898        (~32 GPEs asserted per SCI)
```

ACPICA finds no handler for the 23 GPEs that have no `_Lxx/_Exx` method, logs
"No handler or method for GPE xx" for each, and loops. ~300k kmsg lines per
resume; 145k SCIs measured across one session. At roughly a millisecond each
that is the multi-minute resume.

## Fix

`pci=hpiosize=0` in `boot.kernelParams` — sets the hotplug I/O reservation to
zero so the bridge never claims the window.

Confirmed 2026-08-25. A 12m09s lid-close suspend spent 12m06s in hardware sleep
(99.6%, up from 58%) and woke immediately:

| | before | after |
|---|---|---|
| SCIs | 145226 | 2 |
| `gpe_all` | 4647108 | 2 |
| GPE errors | 2274 | 1 (boot baseline) |
| missed kmsg | 3918370 | 0 |

Tradeoff: hot-plugged Thunderbolt/PCIe devices get no legacy I/O port window.
Almost nothing modern uses PCI I/O space. Suspect this line if a TB dock
misbehaves.

Verify after reboot, before testing the lid:

```
grep -A6 "PCI Bus 0000:02" /proc/ioports
journalctl -b | grep "00:07.0.*bridge window \[io"
journalctl -b | grep -c "No handler or method for GPE"
```

The ACPI blocks should no longer be nested under `PCI Bus 0000:02`.

## What does not work

- **`acpi_mask_gpe=0xNN`** — masks are cleared by the resume path. All 23 were
  back after the first real suspend (`gpe71` had already reverted to `invalid`).
  2285 GPE errors before masking, 2274 after.
- **`surface_gpe`** — cannot bind. Firmware writes `sys_vendor`, `board_vendor`
  and `chassis_vendor` with a leading space (`" Microsoft Corporation"`, visible
  in the `DMI:` banner as a double space) and the driver uses `DMI_EXACT_MATCH`.
  This is firmware-wide on SP9, not specific to this unit. It governs lid wake
  only, not the storm. Blacklisting it is a widely repeated workaround that does
  nothing either way.
- **`HandleLidSwitch=ignore`** — reported as not helping in #1446.

## Not the cause

`pm_test` bisect (`freezer`, `devices`, `platform` — the only phases valid for
s2idle) all pass, with a full clean LPS0 entry/exit and 305ms device resume. No
driver suspend callback hangs. `suspend_stats` showed 73s of real hardware sleep
in a 125s suspend.

## Upstream

- [#1290 — SP9, Arch, doesn't sleep right](https://github.com/linux-surface/linux-surface/discussions/1290)
  — start here. Nov 2023–Feb 2026. Identifies the ACPI interrupt storm; source
  of `pci=hpiosize=0`.
- [#1446 — SP9 ACPI errors during sleep](https://github.com/linux-surface/linux-surface/issues/1446)
  — identical GPE list. Open. Occurs on stock and surface kernels alike.
- [#1910 — Can't wake from suspend (NixOS, SP9)](https://github.com/linux-surface/linux-surface/issues/1910)
  — closest symptom match. Intermittent; reportedly fine on Debian.
- [#1082 — SP9 ACPI error spam after closing type cover while plugged in](https://github.com/linux-surface/linux-surface/issues/1082)
  — closed without explanation. 7GB memory growth, failed shutdowns.
- [#1919 — surface_gpe no compatible device on SP9](https://github.com/linux-surface/linux-surface/issues/1919)
  — confirms the message is common on SP9. No maintainer response.

The project [wiki](https://github.com/linux-surface/linux-surface/wiki/Known-Issues-and-FAQ)
does not document any of this. `pci=hpiosize=0` is a community finding.

## Firmware

Not implicated. UEFI 22.107.143 (07/2025) is about a year behind, but the
mechanism is Linux PCI resource allocation, not firmware. Windows lives on a
separate drive if an update is ever wanted.
