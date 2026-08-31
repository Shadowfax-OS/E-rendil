# GlowCursor — ontwerpspecificatie

**Datum:** 2026-08-31
**Status:** goedgekeurd ontwerp, wacht op implementatieplan
**Werktitel:** GlowCursor (naam vrij te wijzigen)

## 1. Doel

Een gratis macOS-tool in de stijl van Pointerly/CursorPro voor **live presentaties en screensharing**: de muiscursor laten opvallen en live op het scherm annoteren, systeembreed over alle apps heen.

## 2. Scope

### v1-functies

1. **Highlight-ring** — gekleurde cirkel/halo die de cursor permanent volgt.
2. **Spotlight** — rest van het scherm gedimd; een heldere cirkel rond de cursor volgt de muis.
3. **Marker-highlight** — in tekenmodus met ⇧+slepen een translucente marker-rechthoek trekken (vulkleur met alpha ≈ 0,35; een echte multiply-blend met onderliggende schermcontent is onmogelijk zonder schermopname-permissie — de overlay kan alleen met zijn eigen vensterinhoud blenden).
4. **Freehand tekenen** — in tekenmodus vrij tekenen (highlight-randen om schermelementen).
5. **Undo laatste streek** en **alles wissen** via sneltoets.
6. **Menubar-app** (geen dock-icoon) met menu: toggles, kleurkeuze, ringdiameter, dim-sterkte, wissen, afsluiten.
7. **Globale sneltoetsen** (hardcoded in v1).

### Buiten scope v1

Klik-animaties, keystroke-overlay, zoom, zwevend bedieningspaneel, voorkeurenvenster, configureerbare sneltoetsen, Windows-ondersteuning, kant-en-klare distributie/notarisatie.

### Randvoorwaarden

- **Platform:** macOS 14+ (ontwikkeld/getest op macOS 26, Apple Silicon).
- **Build zonder Xcode:** alleen Command Line Tools + Swift 6.3 via Swift Package Manager. Geen `.xcodeproj`.
- **Nul permissies:** geen Screen Recording (er wordt geen schermcontent gelezen), geen Accessibility of Input Monitoring (Carbon-hotkeys en `NSEvent.mouseLocation`-polling vereisen die niet). Geen enkele TCC-prompt.
- **Puur AppKit.** Geen SwiftUI (voorkomt het mixen van twee app-lifecycles voor één menubar-menu), geen externe dependencies.
- **Distributie:** lokaal eigen gebruik; ad-hoc gesigneerde `.app` via bundle-script.

## 3. Bekende beperking (bewust geaccepteerd)

De effecten zijn zichtbaar bij het delen van het **volledige scherm**. Bij "deel alleen dit venster" in Teams/Zoom ziet het publiek de overlay **niet** — de overlay is een apart venster. Dit geldt voor alle tools van dit type en hoort prominent in de README.

## 4. Architectuur

### Overlay-strategie

Eén borderless, transparante `NSPanel` per `NSScreen`:

- styleMask `.borderless` + `.nonactivatingPanel` — muis-events ontvangen in tekenmodus **zonder** de frontmost app (Keynote/Teams) te deactiveren;
- window level `.screenSaver` (boven alles, inclusief menubalk — die dimt mee tijdens spotlight, acceptabel tijdens presentaties);
- `collectionBehavior`: `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`, `.ignoresCycle` — zichtbaar op alle Spaces en over fullscreen-apps;
- `sharingType = .readOnly` — zichtbaar in schermopname/schermdeling;
- `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`;
- `ignoresMouseEvents = true` (click-through) behalve in tekenmodus;
- `canBecomeKey` retourneert alleen `true` in tekenmodus (nodig om ESC te vangen).

### Renderlagen (per panel, van onder naar boven)

1. **SpotlightLayer** — schermvullende zwarte `CALayer` (opacity instelbaar) met een `CAShapeLayer`-mask (even-odd pad met cirkelvormig gat rond de cursor).
2. **AnnotationView** — `NSView` die freehand-strokes en marker-rechthoeken tekent met `NSBezierPath`; marker-rechthoeken als translucente vulling (alpha ≈ 0,35).
3. **RingLayer** — `CAShapeLayer`-cirkel die de cursor volgt.

Zo blijft de ring zichtbaar binnen het spotlight-gat en dimmen annotaties mee buiten het gat.

**Kritiek renderdetail:** alle per-frame updates (maskerpad, ringpositie) binnen `CATransaction` met `setDisableActions(true)`, anders animeert Core Animation elke update impliciet (0,25 s) en smeert het effect achter de cursor aan.

### Cursor volgen

`CADisplayLink` via `NSScreen.displayLink(target:selector:)` (de moderne opvolger van het deprecated `CVDisplayLink`). Per tick wordt `NSEvent.mouseLocation` gelezen. De display-link draait **alleen** als ring of spotlight actief is; effecten uit = 0% CPU.

### Coördinaten

`NSEvent.mouseLocation` levert globale AppKit-coördinaten (origin linksonder op het hoofdscherm). `CoordinateMapper` (pure functies, unit-getest) bepaalt op welk scherm de cursor staat en rekent om naar panel-lokale view-coördinaten. Panels op schermen zonder cursor verbergen ring en spotlight-gat (volledig gedimd bij actieve spotlight).

## 5. Componenten

| Component | Verantwoordelijkheid | Tests |
|---|---|---|
| `AppDelegate` | Wiring, `NSApp.setActivationPolicy(.accessory)`, luistert op `didChangeScreenParametersNotification` | handmatig |
| `EffectsState` | Bron van waarheid: actieve effecten, kleur, ringdiameter, dim-opacity, tekengereedschap; persistentie via `UserDefaults`; observatie via delegates (geen externe deps) | unit |
| `CursorTracker` | `CADisplayLink`-beheer, publiceert globale muispositie, pauzeert bij inactiviteit | deels |
| `OverlayController` | Beheert één `OverlayPanel` per scherm; herbouwt bij schermwijzigingen; schakelt `ignoresMouseEvents` bij tekenmodus | handmatig |
| `OverlayPanel` | Het `NSPanel`-subtype zoals hierboven gespecificeerd | handmatig |
| `SpotlightLayer` / `RingLayer` | CALayer-rendering zonder impliciete animaties | handmatig |
| `AnnotationView` | Tekeninteractie (drag = freehand, ⇧+drag = marker-rechthoek), rendering van `StrokeStore` | model: unit |
| `StrokeStore` | Model: array van strokes/rects per scherm; append, undo (laatste verwijderen), clear | unit |
| `CoordinateMapper` | Globaal ↔ scherm/view-coördinaten, schermdetectie | unit |
| `HotKeyManager` | Carbon `RegisterEventHotKey`-wrapper; mapping toets → actie | mapping: unit |
| `MenuBarController` | `NSStatusItem` + `NSMenu`: toggles (met vinkjes), kleursubmenu, groottesubmenu's, wissen, afsluiten | handmatig |

## 6. Sneltoetsen (v1, hardcoded)

| Toets | Actie |
|---|---|
| ⌃⌥H | Highlight-ring aan/uit |
| ⌃⌥S | Spotlight aan/uit |
| ⌃⌥D | Tekenmodus aan/uit |
| ⌃⌥Z | Laatste streek ongedaan maken |
| ⌃⌥C | Alle annotaties wissen |
| ESC | Tekenmodus verlaten (alleen actief ín tekenmodus) |

In tekenmodus: slepen = freehand; ⇧+slepen = marker-rechthoek; cursor wordt crosshair.

## 7. Gedragsregels

- Annotaties **blijven staan** na het verlaten van de tekenmodus, tot ⌃⌥C of een wijziging van de schermconfiguratie (dan vervallen álle annotaties, zie §8).
- Spotlight en tekenmodus kunnen tegelijk actief zijn; lagen zijn onafhankelijk.
- Tekenmodus geldt op alle schermen tegelijk (elk panel wordt interactief); strokes horen bij het scherm waarop ze getekend zijn.
- Instellingen (kleur, ringdiameter, dim-opacity) worden bij wijziging direct in `UserDefaults` opgeslagen en bij start hersteld. Effecten starten altijd **uit**.

## 8. Foutafhandeling

- **Hotkey-registratie faalt** (conflict met andere app): loggen via `os_log`, functie blijft via het menubar-menu bereikbaar, geen crash.
- **Schermconfiguratie wijzigt** (monitor los/vast, resolutie): alle panels afbreken en opnieuw opbouwen; álle annotaties vervallen; actieve effecten blijven actief.
- **Slaap/ontwaken:** display-link herstart bij eerstvolgende activering; geen speciale afhandeling nodig.

## 9. Teststrategie

### Geautomatiseerd (SPM-testtarget, TDD)

- `EffectsState`: toggle-overgangen, persistentie-round-trip, delegate-notificaties.
- `StrokeStore`: append/undo/clear-semantiek, per-scherm-scheiding, undo op lege store.
- `CoordinateMapper`: globaal→lokaal op hoofdscherm, tweede scherm met negatieve offset, cursor precies op schermrand, schermdetectie.
- `HotKeyManager`: mapping toetscode+modifiers → actie (registratie zelf is OS-afhankelijk en valt buiten unit-scope).

### Handmatige testchecklist (visueel, niet zinvol te automatiseren)

1. Ring volgt cursor vloeiend (120 Hz-scherm), geen smeer/lag.
2. Spotlight dimt alles inclusief menubalk; gat volgt cursor strak.
3. Click-through: met actieve ring/spotlight normaal kunnen klikken/typen in onderliggende apps.
4. Tekenmodus: frontmost app verliest **geen** focus bij activeren; freehand en ⇧-rechthoek werken; ESC verlaat de modus.
5. Undo en wissen werken; annotaties blijven staan na verlaten tekenmodus.
6. Fullscreen-app (Keynote-presentatie): effecten zichtbaar.
7. Tweede monitor aan-/afkoppelen: geen crash, effecten blijven werken, ring op juiste scherm.
8. Schermdeling volledig scherm in Teams/Zoom: publiek ziet effecten. Vensterdeling: publiek ziet ze niet (verwacht).
9. Effecten uit → CPU-gebruik app ~0% (Activiteitenweergave).
10. App herstarten: kleur/groottes hersteld, effecten uit.

## 10. Projectstructuur & build

```
~/Projects/GlowCursor/
├── Package.swift                 # executable target GlowCursor, platform macOS 14+
├── Sources/GlowCursor/           # componenten uit §5, één bestand per component
├── Tests/GlowCursorTests/
├── Scripts/bundle.sh             # swift build -c release → GlowCursor.app
├── Resources/Info.plist          # LSUIElement=true, bundle-id, versie
└── docs/superpowers/specs/       # dit document
```

`Scripts/bundle.sh`: `swift build -c release`, assembleert `GlowCursor.app` (Contents/MacOS/ + Info.plist), signeert ad-hoc (`codesign --force -s -`), en plaatst het resultaat in `build/`. Gebruiker sleept het naar /Applications en voegt het desgewenst toe aan inlogonderdelen. Geen Xcode, Developer-account of notarisatie nodig (eigen build op eigen machine).
