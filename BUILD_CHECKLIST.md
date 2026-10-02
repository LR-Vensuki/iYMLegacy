# iYMLegacy — Theos build checklist

1. Put your own Yandex OAuth `client_id` and `client_secret` in `src/iYMLegacyConfig.h`.
2. Confirm `$THEOS/sdks/iPhoneOS6.1.sdk` exists.
3. Run `./THEOS_DIAG.sh`.
4. Run `make clean && make`.
5. Run `make package FINALPACKAGE=1`.

## Fixes in this build

- Device OAuth POST construction and polling repaired.
- Persistent Yandex `device_id` added.
- Refresh-token handling added.
- Host curl development headers are no longer required; a minimal libcurl 7.58 compatibility header is bundled under `cYandexMusic/curl/curl.h`.
- Legacy GNU statement-expression warnings are disabled explicitly.
- PlayerViewController build errors fixed.
- RecentsViewController's declared initializer implemented.
- ActionSheet retain-cycle warnings fixed.
- Legacy ARM subtype linker compatibility enabled for the bundled ARM curl library.
- Missing `iTunesArtwork` is no longer required for the application build.

## Limits of this validation

The source and C portions can be statically checked in this environment, but the actual final link, code signing, installation, and live Yandex requests must be performed on the machine containing the iPhoneOS 6.1 SDK and appropriate signing/device setup.
