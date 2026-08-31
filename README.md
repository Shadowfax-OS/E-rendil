# GlowCursor

Gratis cursor-highlighter voor macOS — voor live presentaties en screensharing.
Systeembreed: highlight-ring, spotlight-dimming en live schermannotaties.
Nul permissies nodig (geen Accessibility, geen Screen Recording).

## Sneltoetsen

| Toets | Actie |
|---|---|
| ⌃⌥H | Highlight-ring aan/uit |
| ⌃⌥S | Spotlight aan/uit |
| ⌃⌥D | Tekenmodus aan/uit (slepen = tekenen, ⇧+slepen = marker-rechthoek, ESC = stoppen) |
| ⌃⌥Z | Laatste streek ongedaan maken |
| ⌃⌥C | Alle annotaties wissen |

Kleur, ringgrootte en dim-sterkte stel je in via het menubar-icoon.

## Belangrijk: schermdeling

De effecten zijn zichtbaar wanneer je je **volledige scherm** deelt (Teams,
Zoom, Meet). Deel je slechts één **venster**, dan ziet je publiek de effecten
niet — de overlay is technisch een apart venster. Dit geldt voor alle tools
van dit type.

## Bouwen (geen Xcode nodig, wel Command Line Tools)

    Scripts/bundle.sh

Resultaat: `build/GlowCursor.app`. Sleep naar /Applications.
Ontwikkelen: `swift run` · Tests: `Scripts/test.sh`
