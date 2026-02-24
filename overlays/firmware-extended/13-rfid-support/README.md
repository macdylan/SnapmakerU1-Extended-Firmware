# 13-rfid-support (Internal API)

This overlay extends U1 RFID behavior in Klipper extras and is intended as an **internal integration API**.

## Scope

Patch set in `overlays/firmware-extended/13-rfid-support/patches`:

- `01-add-ntag215-support.patch`
  - Extends `fm175xx_reader.py` card handling for NTAG cards.
- `02-add-ndef-protocol.patch`
  - Extends `filament_detect.py` parsing to support NDEF payloads.
- `03-fm175xx-reader-enabled-guard.patch`
  - Adds `self.enabled = config.getboolean('enabled', True)` and early `return` in `FM175XXReader.__init__`.
  - Set `enabled: false` in `[fm175xx_reader]` to skip all hardware init and event registration.
- `04-filament-detect-reader-enabled-guard.patch`
  - Guards `filament_detect.py` against a disabled reader:
    - `_ready`: sets `_fm175xx_reader = None` when `enabled` is false.
    - `request_update_filament_info`: moves state update before the reader `None` check.
    - `request_clear_filament_info`: falls back to clearing via `_filament_info_update` when reader is `None`.
    - `cmd_FILAMENT_DT_SELF_TEST`: raises early error when reader is disabled.
- `05-add-filament-detect-set-endpoint.patch`
  - Adds webhook endpoint `filament_detect/set`.

## Internal API Contract

### Webhook: `filament_detect/set`

- Required request fields:
  - `channel` (int)
  - `info` (dict)
- `info` keys:
  - `vendor` (string), `type` (string), `subtype` (string)
  - `color` (`RRGGBB` hex string), `alpha` (`AA` hex string)
  - `min_temp` (int), `max_temp` (int), `bed_temp` (int)
  - `card_uid` (hex string with even number of digits)
- Only these lower-case names are accepted for webhook `info`.
- Type policy:
  - Values are parsed with Python conversions (`int(...)`, `bytes.fromhex(...)`).
  - `ARGB_COLOR` is recalculated from `alpha` and `color`.
  - Unknown keys are rejected as `unsupported fields: ...`.
- Behavior:
  - Builds an updated filament info object from defaults plus provided keys.
  - Sets state to idle and calls `_filament_info_update(channel, info, True)`.
  - Returns `{'state': 'success'}` or `{'state': 'error', 'message': ...}`.

Example request body:
```json
{
  "channel": 0,
  "info": {
    "vendor": "Generic",
    "type": "PLA",
    "subtype": "Basic",
    "color": "FFAA33",
    "alpha": "CC",
    "min_temp": 200,
    "max_temp": 230,
    "bed_temp": 60,
    "card_uid": "A1B2C3D4"
  }
}
```

### Client Observability Contract

- Clients should read `filament_detect` status via:
  - `/printer/objects/query?filament_detect`
- `filament_detect.state` is the source of truth for RFID update lifecycle.
- If `state[channel] == 1`, the printer is requesting an update for that channel.

## Compatibility Notes

- Target files in this tree are often CRLF. Patch application is expected after LF normalization.
- `pre-scripts/01_klippy_fix_lf.sh` is used to run `dos2unix` on relevant files before patching.

## Stability

- This is internal and may change without backward-compatibility guarantees.
- Clients are expected to understand and track the running software version.
- Command names, endpoint shape, and strict typing are tied to the overlay version in use.
