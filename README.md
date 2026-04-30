# nac-mac-nix

Flake-based NixOS configs for my personal machines, plus matching installer ISOs built from the same flake.

## Machines

| Host      | Hardware                                      |
| --------- | --------------------------------------------- |
| `harry`   | Surface Pro 9 (Intel)                         |
| `sebbers` | AMD laptop                                    |
| `trunkie` | Threadripper desktop                          |
| `roach`   | Asus TUF Gaming F16 (Intel Raptor Lake + NVIDIA) |
| `shrike`  | Dell XPS 16 9650 (Intel Panther Lake, Arc iGPU)   |

## Usage

`build.sh` drives everything. Run with no args for full help.

```bash
./build.sh --iso                 # build every installer ISO
./build.sh --iso roach           # build one ISO
./build.sh --switch              # rebuild + switch current host
./build.sh --install <host> [--disk <name> <device>]...  # wipe & install from a live ISO
./build.sh --wipe    <host> [--disk <name> <device>]...  # wipe only (recovery)
```

Write an ISO to USB with `dd`, boot the target machine, then from the live environment:

```bash
cd /iso/flake
./build.sh --install <host>
```

Full installer notes: [docs/install.md](docs/install.md).

## Docs

- [Install](docs/install.md)
- [Hibernate setup — harry](docs/hibernate-harry.md)
- [lan-mouse server](docs/lan-mouse-server.md) / [client](docs/lan-mouse-client.md)

Architecture and per-host gotchas live in [CLAUDE.md](CLAUDE.md).
