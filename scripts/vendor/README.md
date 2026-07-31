# Vendored third-party schemas

## `zmeta-event-1.1.0.schema.json`

The ZMeta event schema, vendored **verbatim** from
[JTC-byte/zmeta-spec](https://github.com/JTC-byte/zmeta-spec) at schema version
`1.1.0` (`$id: https://praesens.io/schemas/zmeta-event-1.1.0.schema.json`).
Apache-2.0, same licence as this repository.

It is here so `scripts/test_spectrum_survey.py` can validate
`aryaos-spectrum-survey --zmeta` output against the **real** schema rather than
against our reading of it. A hand-written approximation would happily accept
output the actual consumer rejects, which is the whole failure mode the test
exists to prevent.

**Do not edit.** Re-vendor from upstream when moving to a new schema version,
and update the version in the filename so a stale copy is obvious.
