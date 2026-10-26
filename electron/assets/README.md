# ClinicOS application icon

The icon uses the same Lucide `Stethoscope` mark as the sidebar, in white on the Stormy Morning slate `#384959`. `icon.svg` is the vector source; `icon.png` is the transparent 1024px desktop image, `icon.icns` contains the macOS size variants, and `icon.ico` contains Windows sizes from 16px to 256px. The Lucide attribution is in `lucide-LICENSE`.

The desktop packager uses the platform icons. Electron also sets the window and macOS Dock image, including in development. Icon generation uses SVG rendering followed by the standard macOS `iconutil` tool; the generated assets are checked in so normal builds need no extra image dependencies.
