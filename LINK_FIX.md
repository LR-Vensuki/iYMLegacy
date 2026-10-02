# Linker fix

The previous build failed because the Theos source list omitted two source files that are required by symbols referenced elsewhere:

- `src/Item.m` provides `_OBJC_CLASS_$_Item`.
- `cYandexMusic/md5.c` provides `md5String`.

They are now included in `iYMLegacy_FILES` in the root `Makefile`.
