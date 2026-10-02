# Runtime diagnostics

The main OAuth connector no longer opens the verification URL automatically. On iOS 6, doing so launches the legacy Safari. The user code is copied to the clipboard.

After `/token` succeeds, iYMLegacy validates the token with `GET https://api.music.yandex.net/account/status` before declaring `connected!`. The returned UID is saved for Favorites and Playlists.

Errors from the Feed, Favorites, Playlists, Search, and Track List API calls are shown as alerts instead of only being sent to NSLog. This makes an expired/unauthorized token or a server/API response problem visible on-device.
