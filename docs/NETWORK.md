# Road Kernel — Verifiable Data Network (direction)

The long-term idea: Road Kernel produces structured **data blocks** that link to
other people's blocks, forming a private, encrypted network of collected road
knowledge that becomes more useful as more independent observers corroborate it.

This document records the design decisions so the foundation we build now points
the right way.

## Not a blockchain — and why

A real blockchain (global consensus, miners/validators, an immutable public
ledger) solves exactly one problem: getting mutually-distrusting strangers to
agree on a single global state. Road Kernel doesn't have that problem, and a
chain would fight its core values — it's public by default, slow, expensive, and
drags in a coin/economy. **We skip it.**

What we actually want decomposes into four properties, none needing a chain:

| Property | Tool |
| --- | --- |
| Tamper-evident blocks that link together | Content addressing + hash links (Merkle DAG) |
| "This came from me, provably" | Per-record signing (Ed25519) |
| Merge data from many people, no server | Signed append-only logs / CRDTs |
| Private | End-to-end encryption (per record/group) |

The blockchain-*adjacent* good idea here is a **web of attestations**: an
observation's confidence rises as *independent* keys sign corroborating blocks.

## The block

Every shareable record becomes a `SignedRecord` (see
`RoadKernel/Crypto/SignedRecord.swift`):

- `payload` — the data (e.g. a signal).
- `contentHash` — SHA-256 over the canonical payload + parents. This is the
  **address**; identical data ⇒ identical hash ⇒ automatic dedupe on merge.
- `parentHashes` — links to prior blocks → a Merkle DAG, not a single chain.
- `authorPublicKey` + `signature` — pseudonymous Ed25519 identity; verifiable
  offline by anyone, no central authority.

All built on **CryptoKit** (`SHA256`, `Curve25519.Signing`), no dependencies.
The per-install key lives in the Keychain (`KeychainIdentity`).

## The privacy firewall (non-negotiable)

- **Shareable commons:** traffic signals + timing observations only.
- **Never networked:** the personal/contact layer (homes, contacts, notes,
  medical/VA locations, trajectories) — or, at most, explicit end-to-end shares
  to specific named people.
- **Minimize even the shareable:** publish the signal, not your path to it.
  Identity is a pseudonymous key, never your name.

## Phased path

1. **Foundation (done now):** per-install keypair; content-addressed, signed
   records; a signed, verifiable export bundle (`JSONExporter.signedBundle`).
2. **Manual sharing:** import another person's signed bundle (AirDrop a file),
   verify signatures, dedupe by `contentHash`, merge. A real network, zero backend.
3. **Local sync:** automatic gossip over MultipeerConnectivity between nearby devices.
4. **Optional relay:** discovery/transport for non-local peers — the only point a
   managed service (e.g. CloudKit shared DB) vs. P2P trade-off arises.

Confidence then becomes: how many independent keys signed corroborating
observations of a signal.

## Known risks

- **Key loss = identity loss** — needs a backup/recovery story.
- **Sybil attacks** — one person, many keys faking "independent" corroboration;
  attestation-counting helps but isn't a full defense.
- **Moderation / bad data** in a shared commons.
- **Legal/privacy** — the moment location data leaves the device. Opt-in,
  minimized, encrypted, always.
