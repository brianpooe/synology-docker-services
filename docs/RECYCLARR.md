# Recyclarr Configuration Guide (v8)

Recyclarr syncs TRaSH Guides quality profiles and custom formats to Sonarr and Radarr.
This repository now uses Recyclarr **v8** with guide-backed quality profiles (no include templates).

## Quick Start

### 1. Generate `recyclarr.yml`

```bash
./substitute_env.sh docker-compose-files/recyclarr_template.yml /volume1/docker/appdata/recyclarr/recyclarr.yml
nano /volume1/docker/appdata/recyclarr/recyclarr.yml
```

### 2. Add API Keys

- Sonarr: Settings -> General -> Security -> API Key
- Radarr: Settings -> General -> Security -> API Key

### 3. Keep Docker Service URLs

Use service names, not localhost:

```yaml
sonarr:
  sonarr-main:
    base_url: http://sonarr:8989

radarr:
  radarr-main:
    base_url: http://radarr:7878
```

## Template Behavior (v8)

The included template configures:

- Sonarr quality definition: `series`
- Sonarr guide-backed profiles:
  - `WEB-1080p` (`72dae194fc92bf828f32cde7744e51a1`)
  - `WEB-2160p` (`d1498e7d189fbe6c7110ceaabb7473e6`)
- Radarr quality definition: `movie`
- Radarr guide-backed profiles:
  - `UHD Bluray + WEB` (`64fb5f9858489bdac2af690e27c8f42f`)
  - `HD Bluray + WEB` (`d1d67249d3890e49bc12e275d989a7e9`)
- Language CF override for non-English audio with `-10000` score:
  - Sonarr: `69aa1e159f97d860440b04cd6d590c4f`
  - Radarr: `0dc8aec3bd1c47cd6c40c46ecd27e846`
- Sonarr DSCP is explicitly managed at score `75`:
  - Sonarr: `dc5f2bb0e0262155b5fedd0f6c5d2b55`

## Example v8 Configuration

This is the same shape used by `docker-compose-files/recyclarr_template.yml`:

```yaml
sonarr:
  sonarr-main:
    base_url: http://sonarr:8989
    api_key: your_sonarr_api_key
    delete_old_custom_formats: true
    quality_definition:
      type: series
    quality_profiles:
      - trash_id: 72dae194fc92bf828f32cde7744e51a1
        name: WEB-1080p
        reset_unmatched_scores:
          enabled: true
      - trash_id: d1498e7d189fbe6c7110ceaabb7473e6
        name: WEB-2160p
        reset_unmatched_scores:
          enabled: true
    custom_formats:
      - trash_ids:
          - 69aa1e159f97d860440b04cd6d590c4f
        assign_scores_to:
          - name: WEB-1080p
            score: -10000
          - name: WEB-2160p
            score: -10000
      - trash_ids:
          - dc5f2bb0e0262155b5fedd0f6c5d2b55
        assign_scores_to:
          - name: WEB-1080p
            score: 75
          - name: WEB-2160p
            score: 75

radarr:
  radarr-main:
    base_url: http://radarr:7878
    api_key: your_radarr_api_key
    delete_old_custom_formats: true
    quality_definition:
      type: movie
    quality_profiles:
      - trash_id: 64fb5f9858489bdac2af690e27c8f42f
        name: UHD Bluray + WEB
        reset_unmatched_scores:
          enabled: true
      - trash_id: d1d67249d3890e49bc12e275d989a7e9
        name: HD Bluray + WEB
        reset_unmatched_scores:
          enabled: true
    custom_formats:
      - trash_ids:
          - 0dc8aec3bd1c47cd6c40c46ecd27e846
        assign_scores_to:
          - name: UHD Bluray + WEB
            score: -10000
          - name: HD Bluray + WEB
            score: -10000
```

## Validate and Sync

```bash
# Confirm instance names from config
docker exec recyclarr recyclarr config list

# Dry run first
docker exec recyclarr recyclarr sync --preview

# Apply
docker exec recyclarr recyclarr sync
```

## Common Issues

### `base_url must start with 'http' or 'https'`

Cause: malformed URL or empty value.

Fix:

```yaml
# Wrong
base_url: localhost:8989
base_url:

# Correct
base_url: http://sonarr:8989
```

### `Unable to find include template with name ...`

Cause: old pre-v8 config using `include: - template:`.

Fix:

```bash
# Regenerate v8 config from current template
./substitute_env.sh docker-compose-files/recyclarr_template.yml /volume1/docker/appdata/recyclarr/recyclarr.yml

# Recreate recyclarr with v8 image from compose template
./substitute_env.sh docker-compose-files/arr-stack_template.yaml docker-compose.arr-stack.yml
docker-compose -f docker-compose.arr-stack.yml pull recyclarr
docker-compose -f docker-compose.arr-stack.yml up -d recyclarr
```

### `replace_existing_custom_formats` validation error

Cause: this key was removed in v8.

Fix: remove `replace_existing_custom_formats` from your config.

## Upgrade Notes

- This repository pins Recyclarr to `ghcr.io/recyclarr/recyclarr:8.4.0`.
- Always run `sync --preview` before `sync` after changing quality/profile settings.

## References

- Recyclarr v8 upgrade guide: https://recyclarr.dev/guide/upgrade-guide/v8.0/
- Quality profiles reference: https://recyclarr.dev/reference/configuration/quality-profiles/
- Custom formats reference: https://recyclarr.dev/reference/configuration/custom-formats/
- Quality definition reference: https://recyclarr.dev/reference/configuration/quality-definition/
