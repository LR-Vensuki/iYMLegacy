#include "cYandexOAuth.h"

char *c_yandex_oauth_url(const char *client_id)
{
    return c_yandex_oauth_code_on_page(client_id);
}

char *c_yandex_oauth_token_from_html(const char *html)
{
    return c_yandex_oauth_code_from_html(html);
}
