# AryaOS Product Suite — design package

**v1.0 · July 2026 · Sensors & Signals LLC**

Ten properties, two mark systems, one set of rules. Open
`AryaOS-Suite-Design-Guide.html` for the full guide — it is self-contained and
works offline. Everything below is what that guide points at.

---

## Contents

```
AryaOS-Suite-Design-Guide.html   the guide, self-contained
logo/                            SVG marks and tokens, light and reverse
logo/png/                        Signal Blocks rastered at 512 and 1024
tokens/suite-tokens.css          CSS custom properties, one block per property
tokens/suite-tokens.json         the same data, machine-readable
```

---

## The two families

| Family | Mark | Accent sits on | Properties |
| --- | --- | --- | --- |
| **Arya** | Signal Block — KNOW in morse, `-.- -. --- .--` | the opening dot of row four | AryaOS, AryaAir, AryaUAS, AryaSea, DragonEgg |
| **&kit** | Bracket token — a glyph or short word in `[ ]` | the brackets | &kit, OneCOP, FireCOP, Cambot, DroneCase |

A property belongs to exactly one family and carries exactly one mark. No
Signal Block inside brackets; no bracket token on an Arya property.

## The ten properties

| Property | Family | Mark file | Accent |
| --- | --- | --- | --- |
| AryaOS | Arya | `mark-aryaos` | `#E4610F` Signal Orange |
| AryaAir | Arya | `mark-aryaair` | `#0FA8CE` Sky Cyan |
| AryaUAS | Arya | `mark-aryauas` | `#7C52E8` Signal Violet |
| AryaSea | Arya | `mark-aryasea` | `#1F5BD1` Marine Blue |
| DragonEgg | Arya | `mark-dragonegg` | `#C4161C` Crimson |
| &kit | &kit | `token-andkit` | `#D7FF3F` Lime |
| OneCOP | &kit | `token-onecop` | `#0E9A94` Signal Teal |
| FireCOP | &kit | `token-firecop` | `#E8A80F` Ember Gold |
| Cambot | &kit | `token-cambot` | `#23C48E` Phosphor |
| DroneCase | &kit | `token-dronecase` | `#CE2E86` Magenta |

Every file has a `-rev` twin for dark grounds. FireCOP is a **child of
OneCOP** — it carries its own token, accent and lockup, inherits every OneCOP
layout and map pattern, and shows its parentage as one line under the lockup:
`A ONECOP PICTURE`. The `COP` suffix is reserved for OneCOP children.

## Grounds

Console dark (`#0B1512`, or `#0B0C0A` for the &kit family) for anything an
operator drives. Paper (`#F2EFE7` / `#F2F4EE`) for anything printed or read. A
property never mixes the two on one screen. DragonEgg has no light mode.

## Non-negotiables

- 8px unit, 12 columns, 24px gutter, 2px rules, **radius 0**, 44px hit targets.
- Flush left everywhere — headings, copy, and the label inside a wide button.
- Mono means machine: commands, ports, frequencies, callsigns, hex, morse, tokens.
- One accent per surface, roughly 5% of it. Two visible accents means one is wrong.
- Status colours (`#3F7D57` / `#A8811C` / `#A32820`) are fixed and never borrow an accent.
- No shadows. A 2px rule does the separating.

## Before anything leaves

Token SVGs are **live type** and, in two cases, a live emoji. Outline the
brackets and convert the glyph to a path before sending to a printer or a third
party — an emoji rendered by someone else's font is not the mark. The Arya
Signal Blocks are pure geometry and need no such treatment.

Archivo and JetBrains Mono are both open licence. Ship them; don't link them.

---

Questions: info@snstac.com

---

## AryaOS deviations from this kit

Recorded here so they read as deliberate rather than as drift.

**Hit targets on operator surfaces: 48px, not 44px.** The kit sets a 44px
minimum. AryaOS Cockpit plugins use 3rem (48px) because they are driven in the
field with gloves on, and that standard predates this kit and was set from use.
Documentation is a *read* surface, so it follows the kit at 44px.

**Fonts are not yet shipped.** The kit is explicit — Archivo and JetBrains Mono
are open licence, ship them rather than linking them. The kit package does not
include the font binaries, so the docs site currently declares the stack and
falls back to system faces. Material's Google Fonts loader is disabled
(`font: false` in `mkdocs.yml`) rather than quietly adding third-party requests
to the site. Vendoring the WOFF2 files is outstanding.
