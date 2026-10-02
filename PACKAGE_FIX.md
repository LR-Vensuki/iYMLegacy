# Packaging fix

Theos requires a `control` file in the project root when `make package` is used.
This project now contains one matching the existing bundle identifier:
`kuzm.ig.iYMLegacy`.

The `plutil`/`ply` notice is non-fatal. `FINALPACKAGE=1` may optimize XML plists
when one of those utilities is available, but absence does not prevent packaging.
