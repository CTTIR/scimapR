# Package artwork

The registered display logos are the approved CTTIR v5 masters from hexmakR
0.2.0 or later. Names remain inside the hex in light, dark and monochrome
modes. Symbol aliases and favicons use the compact artwork-only variant.

Render all registered masters and platform icons into a review directory:

```sh
Rscript tools/branding/render.R /path/to/review
```

Apply the paths listed in `assets.csv` to this repository:

```sh
Rscript tools/branding/render.R --apply
```

`packages.csv` selects this package identity. Standard masters and 32, 48,
64, 128 and 256 pixel icons are copied byte-for-byte from hexmakR, preserving
the approved outlines. The bundled native R motifs generate additional
16, 96, 180, 192 and 512 pixel icons with Cairo. The renderer also creates
ICO, ICNS and an opaque maskable icon; only destinations in `assets.csv`
are applied. No runtime dependency is added to this package.

The checked-in `pkgdown/favicon/site.webmanifest` uses this package's name,
relative icon URLs and `purpose: any` for the transparent 192 and 512 pixel
icons. These files are not claimed to be maskable. Keep the manifest's size
entries aligned with `assets.csv` when changing registered icon sizes.

Required build tools are R with Cairo support and hexmakR >= 0.2.0. All other
rendering uses base R, grid, grDevices and utils. Editable geometry and design
tokens are bundled under `R/` and `design_tokens.csv`; font licences are in
`fonts/OFL.txt` and `fonts/JetBrainsMono-OFL.txt`.
