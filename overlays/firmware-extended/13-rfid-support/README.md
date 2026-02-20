# 13-rfid-support (Internal API)

This overlay extends U1 RFID behavior in Klipper extras and is intended as an **internal integration API**.

## Scope

Patch set in `overlays/firmware-extended/13-rfid-support/patches`:

- `01-add-ntag215-support.patch`
  - Extends `fm175xx_reader.py` card handling for NTAG cards.
- `02-add-ndef-protocol.patch`
  - Extends `filament_detect.py` parsing to support NDEF payloads.
- `03-add-filament-dt-set.patch`
  - Adds gcode command `FILAMENT_DT_SET`.
- `04-add-filament-detect-set-endpoint.patch`
  - Adds webhook endpoint `filament_detect/set`.
- `05-fm175xx-reader-enabled-guard.patch`
  - Adds config gate for FM175XX event handler registration:
    - `if config.getboolean('enabled', True): ...`
  - Set `enabled: false` in `[fm175xx_reader]` to disable built-in FM175XX reader usage.

## Internal API Contract

### GCode: `FILAMENT_DT_SET`

- Required: `CHANNEL=<int>`
- Optional: any key from `filament_protocol.FILAMENT_INFO_STRUCT`
- Type policy:
  - No value conversion is performed.
  - Type must exactly match the type in `FILAMENT_INFO_STRUCT`.
  - Invalid type raises an error.
- Behavior:
  - Builds a deep copy from `FILAMENT_INFO_STRUCT`.
  - Applies provided fields.
  - Sets state to idle and calls `_filament_info_update(channel, info, True)`.

### Webhook: `filament_detect/set`

- Required request fields:
  - `channel` (int)
  - `info` (dict)
- `info` keys:
  - Any subset of `filament_protocol.FILAMENT_INFO_STRUCT`.
- Type policy:
  - Same as `FILAMENT_DT_SET` (exact type required, no conversion).
- Behavior:
  - Builds a deep copy from `FILAMENT_INFO_STRUCT`.
  - Applies provided fields.
  - Sets state to idle and calls `_filament_info_update(channel, info, True)`.
  - Returns `{'state': 'success'}` or `{'state': 'error', 'message': ...}`.

### Client Observability Contract

- Clients should read `filament_detect` status via:
  - `/printer/objects/query?filament_detect`
- `filament_detect.state` is the source of truth for RFID update lifecycle.
- If `state[channel] == 1`, the printer is requesting an update for that channel.

## Compatibility Notes

- Target files in this tree are often CRLF. Patch application is expected after LF normalization.
- `pre-scripts/01_klippy_fix_lf.sh` is used to run `dos2unix` on relevant files before patching.
- `04` is incremental over `03` and should be applied after it.

## Stability

- This is internal and may change without backward-compatibility guarantees.
- Clients are expected to understand and track the running software version.
- Command names, endpoint shape, and strict typing are tied to the overlay version in use.
