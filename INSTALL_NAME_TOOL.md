# Packaging

The app links successfully. Packaging additionally patches legacy Mach-O
dylib load paths.

The helper searches for an install-name editor in this order:
1. `INSTALL_NAME_TOOL`
2. `install_name_tool` in `PATH`
3. `llvm-install-name-tool` in `PATH`
4. executable tools under `$THEOS/toolchain`

Manual override:

    export INSTALL_NAME_TOOL=/full/path/to/install_name_tool
    make package FINALPACKAGE=1

Diagnostics:

    ./THEOS_DIAG.sh
