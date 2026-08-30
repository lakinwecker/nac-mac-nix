# lan-mouse config — trunkie (server)

Trunkie has the keyboard and mouse attached. The config is generated
declaratively by `machines.nix` (trunkie's `extraModules`) and lands at
`~/.config/lan-mouse/config.toml`:

```toml
port = 4343

[[clients]]
position = "left"
hostname = "phoebe.local"
ips = ["192.168.50.52"]
port = 4343
activate_on_startup = true
```

`position` is the peer's location relative to *this* host, so the Mac sitting
to the left of the desk is `position = "left"`.

`ips` is required. lan-mouse's resolver has no mDNS, so `phoebe.local` on its
own never resolves ([issue #234](https://github.com/feschber/lan-mouse/issues/234)).

## Config schema (0.11)

Peers are `[[clients]]` array-of-tables entries carrying a `position` key.
Earlier versions used bare `[left]` / `[top]` section headers; that form is
**silently ignored** by 0.11 — no error, the peer simply never appears.

## Certificate authorization

0.11 encrypts traffic with DTLS, so each side must authorize the other's TLS
certificate fingerprint before any input crosses. This is runtime pairing, not
something the Nix config can pre-seed:

1. In the lan-mouse GUI on each host, the **General** section of the *local*
   device shows that host's own fingerprint (`aa:bb:cc:…`).
2. On the receiving host, use **Authorize** under *Incoming Connections* and
   match it against the fingerprint shown on the sender.

To make it survive, add the peer's fingerprint to the generated config:

```toml
[authorized_fingerprints]
"bc:05:ab:7a:…" = "phoebe"
```

> **The activation script rewrites `config.toml` on every rebuild.** Anything
> the GUI persists into that file — authorized fingerprints especially — is
> lost on the next `nixos-rebuild`. Put fingerprints into trunkie's
> `extraModules` block in `machines.nix` once you know them, rather than
> leaving them only in the generated file.

## Auto-start

Handled by `common/networking.nix`, which defines a `lan-mouse` systemd user
service wanted by `graphical-session.target`. Nothing to do by hand.

Port 4343, not lan-mouse's default 4242 — nebula owns 4242. Opened in
`common/networking.nix`.
