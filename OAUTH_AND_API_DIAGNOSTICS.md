# OAuth/API diagnostics

The current build uses the public Yandex Music OAuth client ID used by current unofficial Yandex Music client documentation. That documentation states that a separate OAuth application cannot be created and shows client ID `23cabbbdc6cd418abb4b39c32c41195d` for the Music flow.

After OAuth device authorization, the app calls:

`GET https://api.music.yandex.net/account/status`

with:

`Authorization: OAuth <access_token>`

and `Accept-Language: ru`.

The app now reports the actual HTTP status and response body when `/account/status` fails, instead of the generic `Yandex Music HTTP error` message. It also forces HTTP/1.1 and TLS 1.2 where supported by the bundled libcurl.
