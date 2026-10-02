# OAuth troubleshooting

The original iYMLegacy UI showed the device code in a UIAlertView. That alert
was never dismissed when the device authorization completed. When the token
arrived, the app displayed a second "connected!" UIAlertView. On old iOS this
can leave the original code dialog underneath the success dialog, making it
look as though the application asked for the same code again.

The patched version retains the authorization alert in `YandexConnect` and
dismisses it before displaying the success message and dismissing the OAuth
controller.

The device-flow itself is still the Yandex `device_code` -> `/token` polling
flow. A browser "success" page is not delivered to the app directly; the app
learns about the completed authorization from the next `/token` response.
