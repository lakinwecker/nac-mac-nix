# lan-mouse config — phoebe & harry (clients)

Each client defines the server (trunkie) as a peer, using the position trunkie
occupies *relative to that client*. Config lives at
`~/.config/lan-mouse/config.toml`.

## harry (Surface) — trunkie is above

Generated declaratively by `machines.nix` (harry's `extraModules`):

```toml
port = 4343

[[clients]]
position = "top"
hostname = "trunkie.local"
ips = ["192.168.50.15"]
port = 4343
activate_on_startup = true
```

## phoebe (Mac) — trunkie is to the right

Not NixOS, so place this by hand at `~/.config/lan-mouse/config.toml`:

```toml
port = 4343

[[clients]]
position = "right"
hostname = "trunkie.local"
ips = ["192.168.50.15"]
port = 4343
activate_on_startup = true
```

## Config schema (0.11)

Peers are `[[clients]]` array-of-tables entries carrying a `position` key
(`left` | `right` | `top` | `bottom`). Earlier versions used bare `[left]` /
`[top]` section headers; 0.11 **silently ignores** that form — no error, the
peer just never shows up.

`ips` is required. lan-mouse's resolver has no mDNS, so `trunkie.local` on its
own never resolves ([issue #234](https://github.com/feschber/lan-mouse/issues/234)).
Use LAN IPs or `/etc/hosts` entries.

## Certificate authorization

0.11 encrypts traffic with DTLS. Each side must authorize the other's TLS
fingerprint before input crosses — see
[lan-mouse-server.md](lan-mouse-server.md#certificate-authorization).
