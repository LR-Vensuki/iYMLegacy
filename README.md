# iYMLegacy

Клиент **Яндекс Музыки** для iOS 6 (armv7): Моя волна, лента, поиск, избранное,
плейлисты и воспроизведение, в том числе в фоне.

Это форк одноимённого проекта [iYMLegacy](https://github.com/igkuzm/iYMLegacy)
от igkuzm (Igor V. Sementsov), доработанный **LegacyReborn Project**. Оригинал
написан на Objective-C и C (`cYandexMusic` — клиент API Яндекс Музыки на libcurl).

**Установка**

- Cydia-репозиторий LegacyReborn — `http://repo.legacyreborn.cfd/`, пакет
  `com.legacyreborn.iymlegacy` (приложение ставится в `/Applications`);
- `.deb` или `.ipa` со [страницы релизов](https://github.com/LR-Vensuki/iYMLegacy/releases).
  IPA ставится на джейлбрейкнутое устройство с AppSync или подписывается своим
  сертификатом.

## Интерфейс (2.0)

- Скевоморфный интерфейс, вся графика рисуется Core Graphics (`src/YMDraw.m`), поэтому
  её перекрашивают темы (`src/YMTheme.m`): **Классика** (голубой с белым, как iOS 6),
  **Яндекс** (жёлтый с белым), **Яндекс Дарк** (жёлтый с чёрным) и **Ориджинал**
  (кожа со строчкой, как на иконке). Тема выбирается шестерёнкой на главной.
- Окно входа (`src/YandexConnect.m`): QR-код на страницу подтверждения Яндекса
  (ya.ru/device) и поле с кодом; QR рисуется встроенным
  [QR Code generator](https://www.nayuki.io/page/qr-code-generator-library) от
  Project Nayuki (MIT, `qrcodegen/`).
- Главная (`src/HomeViewController.m`): Моя волна (rotor API, станция
  `user:onyourwave`), карусель Cover Flow с треками для вас (`src/YMCoverFlowView.m`)
  и полка сгенерированных плейлистов.
- Как в Apple Music: нажатие на трек сразу включает его и открывает «Сейчас играет»,
  которое смахивается вниз в мини-плеер над вкладками (`src/YMMiniPlayer.m`,
  `src/RootViewController.m`). Долгое нажатие на трек открывает меню (играть
  следующей, добавить в очередь).
- Продолжение как в Яндекс Музыке: трек из плейлиста, альбома или избранного играет
  дальше по списку; одиночный трек (поиск) и конец списка продолжаются Моей волной
  по последнему треку (станция `track:<id>`).
- «Сейчас играет» (`src/PlayerViewController.m`): очередь каруселью Cover Flow, слева
  сыгранное, справа то, что будет дальше (Моя волна или плейлист, подписано над
  названием); свайп или нажатие на соседнюю обложку включает трек, нажатие на
  обложку в центре переворачивает её к списку очереди,
  перемотка, перемешивание, повтор (всё/один трек), лайк, громкость.
- Иконки: [Material Symbols](https://fonts.google.com/icons) (Rounded) от Google,
  Apache License 2.0. Исходные SVG лежат в `icons/material-symbols/`, в
  `src/YMIcons.inc` их превращает `tools/gen_icons.py`.

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
