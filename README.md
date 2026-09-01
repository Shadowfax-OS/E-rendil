# GlowCursor

Gratis cursor-highlighter voor macOS — voor live presentaties en screensharing.
Systeembreed: highlight-ring, spotlight-dimming en live schermannotaties.
Nul permissies nodig (geen Accessibility, geen Screen Recording).

## Sneltoetsen

| Toets | Actie |
|---|---|
| ⌃⌥H | Highlight-ring aan/uit |
| ⌃⌥S | Spotlight aan/uit |
| ⌃⌥D | Tekenmodus aan/uit (slepen = tekenen, ⇧+slepen = marker-rechthoek) |
| ⌃⌥Z | Laatste streek ongedaan maken |
| ⌃⌥C | Alle annotaties wissen |
| ESC | Alles uit: ring, spotlight én tekenmodus uit + alle tekeningen weg |

Kleur, ringgrootte en dim-sterkte stel je in via het menubar-icoon.

**ESC = paniekknop.** Eén druk zet elk actief effect uit en wist de tekeningen —
terug naar de kale muiscursor. ESC wordt alléén afgevangen zolang er een effect
actief is; staat alles uit, dan werkt ESC overal gewoon normaal.

## Starten

    Scripts/install.sh

Bouwt de app en zet 'm in `/Applications`, zodat Spotlight/Raycast 'm als gewone
app vinden. Open 'm daarna één keer en zet in het menubalk-menu **Start bij
inloggen** aan — dan draait GlowCursor voortaan vanzelf op de achtergrond.

> "Start bij inloggen" werkt alleen vanuit een echte app-bundle in `/Applications`
> (via `SMAppService`), niet vanuit `swift run`.

## Belangrijk: schermdeling

De effecten zijn zichtbaar wanneer je je **volledige scherm** deelt (Teams,
Zoom, Meet). Deel je slechts één **venster**, dan ziet je publiek de effecten
niet — de overlay is technisch een apart venster. Dit geldt voor alle tools
van dit type.

## Bouwen (geen Xcode nodig, wel Command Line Tools)

    Scripts/bundle.sh

Resultaat: `build/GlowCursor.app`. `Scripts/install.sh` bouwt hetzelfde en
kopieert direct naar `/Applications`.
Ontwikkelen: `swift run` · Tests: `Scripts/test.sh`

Let op: bare `swift test` bouwt wél maar draait **nul** tests op deze
CLT-only setup (geen Xcode) — gebruik altijd `Scripts/test.sh`.
