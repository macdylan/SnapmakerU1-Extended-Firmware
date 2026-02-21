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
- Optional fixed keys:
  - `VENDOR=<string>`: any non-empty vendor text.
  - `TYPE=<string>`: material family text, for example `PLA`, `PETG`, `ABS`, `TPU`, `PVA`.
  - `SUBTYPE=<string>`: subtype text, for example `Basic`, `Matte`, `SnapSpeed`, `Silk`, `Support`, `HF`, `95A`, `95A HF`.
  - `COLOR=<RRGGBB hex>`: raw hex string.
  - `ALPHA=<AA hex>`: raw hex string.
  - `MIN_TEMP=<int>`: decimal integer hotend minimum temperature.
  - `MAX_TEMP=<int>`: decimal integer hotend maximum temperature.
  - `BED_TEMP=<int>`: decimal integer bed temperature.
  - `CARD_UID=<HEX string>`: raw hex string.
- Only these upper-case names are accepted for gcode.
- Type/conversion policy:
  - `COLOR` and `ALPHA` are parsed from hex strings.
  - `CARD_UID` is parsed from a hex string and split into byte values.
  - `ARGB_COLOR` is always recalculated from current `ALPHA` and `COLOR`.
  - Parsing relies on Python conversions (`int(...)`, `bytes.fromhex(...)`).
  - Unknown keys are reported as `unsupported fields: ...`.
- Behavior:
  - Builds an updated filament info object from defaults plus provided keys.
  - Sets state to idle and calls `_filament_info_update(channel, info, True)`.

Example:
```gcode
FILAMENT_DT_SET CHANNEL=0 VENDOR=Generic TYPE=PLA SUBTYPE=Basic COLOR=FFAA33 ALPHA=CC MIN_TEMP=200 MAX_TEMP=230 BED_TEMP=60 CARD_UID=A1B2C3D4
```

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
  - Same as `FILAMENT_DT_SET` fixed keys and value rules.
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
- `04` is incremental over `03` and should be applied after it.

## Stability

- This is internal and may change without backward-compatibility guarantees.
- Clients are expected to understand and track the running software version.
- Command names, endpoint shape, and strict typing are tied to the overlay version in use.
