# iYMLegacy maximal repair pass

Updated in this build:

- Yandex OAuth device-code request construction and validation
- stable persisted device_id
- OAuth token polling and refresh-token support
- URL-encoding of OAuth form parameters
- Yandex Music API base URL, Authorization and X-Yandex-Music-Client headers
- network connect/request timeouts
- HTTP/JSON error handling
- modern track download-info URL signing flow
- current playlist relative-change request shape and revision lookup
- null-safe JSON result handling
- multiple cJSON cleanup/leak fixes
- album/normalization memory cleanup
- play-audio input validation
- like/unlike input validation
- legacy build/IPA packaging robustness
- local OAuth configuration template
- token refresh persistence and token-update notifications in the Objective-C layer
- background work for several UI-triggered network calls

Not end-to-end verified here: compilation/linking against Apple's legacy iOS SDK, code signing, installation on a physical iOS 6 device, and live Yandex account/API behavior.
\n\n## Статическая проверка финальной версии\n\n- `autoreconf -fi` проходит без ошибок.\n- `Info.plist` проходит `plutil -lint`.\n- Все C-файлы проходят `clang -fsyntax-only -std=gnu11`.\n- Старая пара OAuth credentials удалена из исходников и заменена placeholders.\n- `arm-aple-darwin11` исправлено на `arm-apple-darwin11`.\n- Добавлен `VERIFY_SOURCE.sh`.\n\nЭто не заменяет сборку в Apple iOS 6 SDK и тест на физическом устройстве.\n
- fixed search `best` parsing to read `type`/`result` from the `best` object;
- freed temporary track/album/playlist structures after callbacks;
- added input validation for search/favorites/playlist-track methods;
- removed the strong AppDelegate back-reference from PlayerController to avoid a retain cycle;
- removed synchronous UID lookup from Favorites initialization;
- added super-view lifecycle calls to legacy view controllers;
