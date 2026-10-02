# iYMLegacy

Клиент **Яндекс Музыки** для iOS 6 (armv7): лента, поиск, избранное, плейлисты
и воспроизведение, в том числе в фоне.

Это форк одноимённого проекта [iYMLegacy](https://github.com/igkuzm/iYMLegacy)
от igkuzm (Igor V. Sementsov), доработанный **LegacyReborn Project**. Оригинал
написан на Objective-C и C (`cYandexMusic` — клиент API Яндекс Музыки на libcurl).

**Установка**

- Cydia-репозиторий LegacyReborn — `http://repo.legacyreborn.cfd/`, пакет
  `com.legacyreborn.iymlegacy` (приложение ставится в `/Applications`);
- `.deb` или `.ipa` со [страницы релизов](https://github.com/LR-Vensuki/iYMLegacy/releases).
  IPA ставится на джейлбрейкнутое устройство с AppSync или подписывается своим
  сертификатом.

## Что изменено по сравнению с оригиналом

- Вход через Яндекс OAuth по коду устройства (`/device/code` → `/token`): код
  копируется в буфер, адрес страницы подтверждения приходит от Яндекса и не
  открывается сам; постоянный `device_id`, обновление токена по refresh token.
  После входа токен проверяется запросом `account/status`.
- Заголовки и базовый адрес API как у современных клиентов Яндекс Музыки,
  новая схема подписи ссылок на скачивание трека, исправлены изменение плейлистов,
  разбор лучшего результата поиска, тайм-ауты.
- Ошибки ленты, избранного, плейлистов, поиска и списков треков показываются в
  приложении, а не только в журнале.
- Исправлены утечки памяти (cJSON, структуры треков и альбомов), цикл
  удержания в `PlayerController`, синхронный запрос в «Избранном».
- Сборка через Theos в IPA и в `.deb`; встроенные libcurl и OpenSSL
  переподписываются после правки путей загрузки.

Подробности — в `PATCH_NOTES.md`, `OAUTH_TROUBLESHOOTING.md`,
`API_RUNTIME_DIAGNOSTICS.md`.

## Сборка (Theos)

Нужны [Theos](https://theos.dev) и `iPhoneOS6.1.sdk` в `$THEOS/sdks`.

```sh
make package FINALPACKAGE=1                      # packages/com.legacyreborn.iymlegacy_<версия>.ipa
make package FINALPACKAGE=1 PACKAGE_FORMAT=deb   # packages/com.legacyreborn.iymlegacy_<версия>_iphoneos-arm.deb
```

Версия берётся из `control`. Встроенные `libs/*.dylib` (libcurl, OpenSSL 0.9.8)
копируются в `iYMLegacy.app/libs`; `tools/patch-install-names.sh` переписывает
их пути загрузки, после чего Theos подписывает их заново (ldid).

OAuth: `src/iYMLegacyConfig.h` — публичный OAuth-клиент Яндекс Музыки, который
используют неофициальные клиенты; свой создать нельзя.

Сборка autotools из оригинала (`./autogen.sh && ./configure …`) тоже осталась,
см. `BUILD_AND_INSTALL.md`; `./configure` перезапишет `Makefile` Theos.

## Ограничения

У Яндекс Музыки нет стабильного открытого API для сторонних клиентов:
изменения на стороне Яндекса могут ломать отдельные функции без ошибок сборки.

## Авторы и лицензия

Оригинальный код — © Igor V. Sementsov ([igkuzm](https://github.com/igkuzm)).
В оригинальном репозитории нет файла лицензии, поэтому этот репозиторий —
форк на GitHub, а не самостоятельная копия. Изменения — LegacyReborn Project.
