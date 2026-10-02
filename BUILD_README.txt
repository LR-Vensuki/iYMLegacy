iYMLegacy Theos build
=====================

Build from the directory containing this Makefile:

  ./THEOS_DIAG.sh
  make clean
  make
  make package FINALPACKAGE=1

The project targets iPhoneOS 6.1 and armv7. The source tree contains a minimal
libcurl 7.58-compatible public header because the bundled libcurl dylib is
shipped without development headers.

Yandex OAuth credentials: edit src/iYMLegacyConfig.h and replace both
placeholders with the credentials of your own OAuth application.

The app persists yandex_device_id, access token, refresh token and token expiry.
The device flow uses /device/code and /token.


Build error fixes included for Theos/modern Clang:
- bundled minimal curl/curl.h removes the dependency on a host libcurl development package;
- GNU statement-expression warning in legacy structures.c is disabled explicitly;
- PlayerViewController unused variables and NSString numeric conversion fixed;
- RecentsViewController initWithTitle: implemented;
- ActionSheet block retain cycle fixed with weak capture;
- linker allows the legacy ARM subtype used by the bundled libcurl.dylib.
