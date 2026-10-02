# iYMLegacy — build and install

## 1. Requirements

This repository is a legacy iOS 6 / 32-bit project and has no `.xcodeproj`. Build it with a legacy iOS cross-toolchain and an iPhoneOS SDK compatible with the source (the original project targets iOS 6-era APIs).

The repository ships old `libcurl`, OpenSSL and `libgcc` dylibs under `libs/`. They are kept for compatibility with the original app.

## 2. Configure Yandex OAuth

Edit `src/iYMLegacyConfig.h` and replace the two placeholders with the credentials of your own Yandex OAuth application:

```c
#define IYMLEGACY_YANDEX_CLIENT_ID "..."
#define IYMLEGACY_YANDEX_CLIENT_SECRET "..."
```

Do not publish the secret.

The app uses Yandex OAuth device flow. It requests a device code, shows the server-provided verification URL and user code, polls `/token`, and persists the access/refresh tokens.

## 3. Build

On a matching legacy Mac/Xcode toolchain:

```sh
cd iYMLegacy-main
./autogen.sh

export SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
export CC=clang
export OBJC=clang

CC="$CC" OBJC="$OBJC" \
CFLAGS="-arch armv7 -isysroot $SDK -miphoneos-version-min=6.0" \
LDFLAGS="-arch armv7 -isysroot $SDK -miphoneos-version-min=6.0" \
./configure --host=arm-apple-darwin11

make -C src iYMLegacy
make -C src iYMLegacy.app
make -C src iYMLegacy.ipa
```

If your toolchain uses a prefixed cross compiler, set `CC`, `OBJC`, `CXX`, `INSTALL_NAME_TOOL` to those tools instead.

## 4. Bundle identifier

`src/Info.plist` contains the original identifier:

```xml
<key>CFBundleIdentifier</key>
<string>kuzm.ig.iYMLegacy</string>
```

For a normally signed build, change it to the App ID used by your provisioning profile.

## 5. Signing

The Makefile prepares the `.app` and IPA but does not create an Apple code signature. For a normal device installation, embed the provisioning profile and sign the nested dylibs before signing the main executable/app bundle with a certificate that matches the bundle identifier.

Do not sign before the `install_name_tool` paths are finalized.

## 6. First-run test

Test in this order:

1. Launch app.
2. Tap Connect.
3. Confirm that a `user_code` and `verification_url` appear.
4. Complete authorization at the URL supplied by Yandex.
5. Wait for `access_token` to be received.
6. Confirm the app stores the token and loads the account.
7. Test feed/search/favorites/playlists.
8. Test playback only after the account/API calls work.

## 7. If authentication fails

The app now reports the OAuth server's error text.

- `invalid_client` / `unauthorized_client`: check the Yandex OAuth application and credentials.
- `authorization_pending`: normal while the user has not finished authorization.
- `slow_down`: the poll interval is increased.
- `expired_token` / `invalid_grant`: restart device authorization.

## 8. Static checks performed on this source tree

`autoreconf -fi` completes successfully in a Linux environment. The C sources also pass `clang -fsyntax-only` with the available libcurl headers; the actual iOS link/sign/install step requires the legacy Apple SDK/toolchain and a compatible device.

## 9. Known external dependency

Yandex Music is not a stable public API surface for third-party clients. This project uses the current request shapes and headers used by contemporary unofficial Yandex Music clients, but server-side changes can still break individual endpoints without a source-code compilation error.


## Финальная проверка перед сборкой

1. Откройте `src/iYMLegacyConfig.h`.\n2. Вставьте `client_id` и `client_secret` своего OAuth-приложения Яндекса.\n3. Проверьте `CFBundleIdentifier` в `src/Info.plist` и используйте тот же App ID в provisioning profile.\n4. Выполните `./VERIFY_SOURCE.sh`.

## Важное ограничение

Этот репозиторий рассчитан на старый iOS toolchain/SDK. Здесь проверяются исходники, autotools и структура IPA, но конечную линковку против Apple iOS 6 SDK и установку на физический iOS 6.x аппарат нужно выполнить на соответствующей системе.

## OAuth

Приложение использует device-flow: `/device/code` -> `user_code` + `verification_url` -> `/token` -> `access_token`. URL страницы подтверждения берётся из ответа сервера и не захардкожен.

## Подпись

Собранный `.app` должен быть подписан для конкретного устройства/профиля. Сначала меняется `CFBundleIdentifier` при необходимости, затем в `.app` добавляется provisioning profile и выполняется code signing. Вложенные dylib должны быть подписаны до основного приложения.

## Тестирование после установки

Проверяйте по порядку:

- открывается приложение;\n- Connect выдаёт `user_code`;\n- страница Яндекса принимает код;\n- появляется `connected!`;\n- поиск возвращает треки;\n- открывается альбом/плейлист;\n- у трека появляется URL воспроизведения;\n- воспроизведение стартует;\n- избранное/плейлисты загружаются.\n
