# lan-mouse topology — phoebe (Mac) as the hub

phoebe holds the keyboard and mouse and does all the capturing. trunkie and
roach only *emulate* — they receive input and can never initiate a crossing
themselves.

```
   roach  -------  phoebe  ------- trunkie
                     (hub)

   from phoebe:  roach = "left",  trunkie = "right"
   from roach:   phoebe = "right"
   from trunkie: phoebe = "left"
```

## Why phoebe captures and the Linux boxes do not

xdg-desktop-portal-hyprland leaks an EIS file descriptor per input-capture
session, and lan-mouse opens one per barrier crossing. After roughly 36 the
D-Bus **session bus** runs out of in-flight fd references and
xdg-desktop-portal segfaults, taking down every client on that bus — terminals,
the bar, Electron apps — not just the portal.

- Upstream issue: <https://github.com/hyprwm/xdg-desktop-portal-hyprland/issues/419>
- Fix: PR #421, **unmerged**, part 2 of 3 (also needs hyprland-protocols ≥ 0.8.0
  and a Hyprland-side change)

Measured on trunkie: +3 fds per crossing, never released; crashes observed at 39, 45
and 50 sessions. Stopping lan-mouse does **not** give the fds back — they belong
to xdph and survive until it restarts.

Capture is the only path that touches the portal. Emulation uses the wlroots
virtual-input protocols instead, so a host that never captures never leaks. That
is what `lanMouseCaptureBackend = "dummy"` in `machines.nix` buys: it adds
`--capture-backend dummy`, measured to produce zero portal sessions and zero fd
growth. Do not reach for `layer-shell` instead — it also avoids the portal, but
sticks modifier keys and repeats keystrokes.

macOS capture does not involve xdph at all, which is why phoebe is the hub.

## Linux side (declarative)

Both configs are generated into `/etc/lan-mouse/config.toml` from each host's
`extraModules` block in `machines.nix` — not `~/.config`, because activation on
these hosts runs from the initrd before `/home` is mounted, so a home-written
config is shadowed the moment `/home` mounts over it.

`position` is where the *peer* sits relative to this host, so both list phoebe:
trunkie says `left`, roach says `right`.

## phoebe side (manual — not NixOS)

`~/.config/lan-mouse/config.toml`:

```toml
port = 4343

[authorized_fingerprints]
"<trunkie fingerprint>" = "trunkie"
"<roach fingerprint>"  = "roach"

[[clients]]
position = "right"
hostname = "trunkie.local"
ips = ["192.168.50.15"]
port = 4343
activate_on_startup = true

[[clients]]
position = "left"
hostname = "roach.local"
ips = ["192.168.50.172"]
port = 4343
activate_on_startup = true
```

`position` only picks which screen edge triggers a crossing — it does not have
to match physical desk layout.

## Addressing

`ips` is mandatory in every peer block: lan-mouse's resolver has no mDNS, so a
bare `.local` name never resolves (feschber/lan-mouse#234). That means these
addresses have to stay put, so they are DHCP reservations on the router rather
than ordinary leases:

| host    | MAC                 | address        |
|---------|---------------------|----------------|
| trunkie | `10:7B:44:92:D4:7C` | 192.168.50.15  |
| roach   | `F8:3D:C6:C2:FF:7C` | 192.168.50.172 |

trunkie's is the onboard NIC `enp5s0` — deliberately *not* the dock's USB NIC
(`8c:3b:4a:28:fd:9a`), which is left unmanaged in `hosts/trunkie/default.nix`
and never holds an address.

roach's is its Wi-Fi MAC. Its wired NIC (`bc:fc:e7:f1:4b:09`) is a separate
interface with a separate lease, so plugging roach into ethernet would move it
off the reserved address and break the peer with a "connection timed out" until
`ips` is updated.

## Fingerprints

0.11 encrypts with DTLS; an unlisted peer is rejected at handshake with
`Alert is Fatal or Close Notify`. Each side must authorize the other.

Known: **phoebe** is
`8b:73:b1:29:df:1d:50:bb:92:ce:d1:15:21:ae:af:45:b8:a0:21:14:33:d1:ee:8e:14:50:0a:d9:ac:15:6f:6b`,
already in both Linux configs. **trunkie** is
`44:bc:eb:83:d7:a3:e8:99:1c:57:e8:7b:4e:01:67:7a:f4:45:c2:64:9e:5a:e5:79:5b:ae:ba:23:58:fe:b7:6a`.

roach's does not exist until lan-mouse runs there once; read it with:

Wrapped in `bash -c` because the login shell here is nushell, where `>` is a
comparison operator rather than a redirect — the two-step version writes no file
and the second command then fails on a path that does not exist.

```bash
bash -c "awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' ~/.config/lan-mouse/lan-mouse.pem | nix shell nixpkgs#openssl -c openssl x509 -noout -fingerprint -sha256"
```

The `.pem` is created the first time lan-mouse runs on that host.

Put fingerprints in `machines.nix`, not via `lan-mouse cli authorize-key` —
that writes to the config file, which the Nix-generated `/etc` copy replaces on
every rebuild.

## Coming back: the release bind

`Ctrl+Shift+Super+Alt` — on phoebe's keyboard, Control+Shift+Command+Option.

With `--capture-backend dummy` a Linux host has nothing watching its screen edge,
so it cannot hand the pointer back on its own. The release bind is the route
back, and it is handled by whichever machine is *currently capturing* — phoebe —
so it works regardless of the receiving host's backend.

Verified on trunkie: repeated crossings back and forth, with the portal counters
flat throughout (6 sessions / 6 ConnectToEIS / 32 xdph fds before and after).
Under the portal backend the same crossings would have cost roughly +3 sessions
and +3 fds each.

## Service

`common/networking.nix` defines the `lan-mouse` user service, wanted by
`graphical-session.target`. Port 4343, not lan-mouse's default 4242, because
nebula owns 4242.
