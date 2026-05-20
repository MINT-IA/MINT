# MINT — Icon pack

L'icône MINT est un « m. » composé en *Gambarino italic*, dans un carré-squircle iOS (rayon ≈ 22.37 %).

## Ce qu'il y a dans le dossier

```
icons/
├─ menthe/         ← primaire (mint vif sur fond menthe)
├─ acide/          ← jaune acide
├─ encre/          ← noir, dot acide
├─ paper/          ← fond blanc, encre noire (print, monochrome)
│
│  Chaque variante contient :
│   ├─ icon.svg              Master vectoriel — carré plein (à donner au système OS)
│   ├─ icon-rounded.svg      Master vectoriel — squircle découpé (favicon, web)
│   ├─ flat-1024.png         ★ Master iOS App Store / Play Store source
│   ├─ flat-512.png          Play Store listing
│   ├─ flat-192.png          PWA, divers
│   ├─ flat-180.png          iOS app icon (legacy taille fixe)
│   ├─ rounded-512.png       PWA maskable, social previews
│   ├─ rounded-192.png       PWA
│   ├─ rounded-180.png       apple-touch-icon
│   ├─ rounded-32.png        favicon
│   └─ rounded-16.png        favicon
│
└─ README.md (ce fichier)
```

## Où poser quoi

### iOS (app native)

Dans `Assets.xcassets/AppIcon.appiconset/`, dépose **`menthe/flat-1024.png`** comme « App Store » 1024 pt. Xcode 14+ génère automatiquement toutes les tailles de runtime à partir de ce 1024.

Si Xcode demande toutes les tailles manuellement, utilise les autres `flat-*.png` (180 = 60pt @3x, 120 = 60pt @2x, etc.). **Toujours en `flat`** — iOS applique son propre masque squircle.

### Android

Dans `android/app/src/main/res/`, dépose **`menthe/flat-192.png`** comme `mipmap-xxxhdpi/ic_launcher.png`. Génère les densités plus petites avec ton outil habituel (Android Studio → Image Asset Studio, à partir du SVG ou du PNG 512).

Pour le Play Store listing : **`menthe/flat-512.png`**.

### Web

Dans `<head>` :

```html
<link rel="icon" type="image/svg+xml" href="/icons/menthe/icon-rounded.svg">
<link rel="icon" type="image/png" sizes="32x32" href="/icons/menthe/rounded-32.png">
<link rel="icon" type="image/png" sizes="16x16" href="/icons/menthe/rounded-16.png">
<link rel="apple-touch-icon" href="/icons/menthe/rounded-180.png">
```

Manifest PWA :

```json
{
  "icons": [
    { "src": "/icons/menthe/rounded-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icons/menthe/rounded-512.png", "sizes": "512x512", "type": "image/png" },
    { "src": "/icons/menthe/flat-512.png",    "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}
```

## Une note sur les SVG

Les `icon.svg` utilisent un `<foreignObject>` HTML pour rendre la composition (italique + dot positionné) exactement comme dans le brand book. Ça fonctionne :

- ✅ Tous les navigateurs modernes (favicon.svg, balise `<img>`, CSS `background-image`)
- ✅ Figma (import natif comme image)
- ⚠️ Illustrator / Sketch : ouvre en bitmap (le foreignObject n'est pas vectorisé)
- ❌ Outils CLI type `librsvg` : pas de support foreignObject

**Pour vectoriser le glyphe « m » en chemin** (cas Illustrator, ImageMagick) : ouvre le `.svg` dans Inkscape → sélectionne le texte → `Path > Object to Path` → ré-exporte. Ou utilise les PNG `flat-1024.png` comme source vectorielle (rétro-ingénierie via traceur d'images).

## Variantes — quand utiliser quoi

| Variante | Usage |
|---|---|
| **menthe** | Défaut. iOS, Android, web. |
| **acide**  | Éditoriale, accent — campagnes, splash, easter eggs |
| **encre**  | Mode sombre, accent fort, contraste élevé |
| **paper**  | Print, monochrome, contextes où la couleur n'est pas dispo |
