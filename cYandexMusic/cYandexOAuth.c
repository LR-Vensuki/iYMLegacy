/**
 * File              : cYandexOAuth.c
 * Patched for iYMLegacy legacy iOS client.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <curl/curl.h>
#include "uuid4.h"
#include "cJSON.h"
#include <unistd.h>
#include <stdint.h>
#include <time.h>

#include "cYandexOAuth.h"

struct string {
    char *ptr;
    size_t len;
};

static void init_string(struct string *s)
{
    s->len = 0;
    s->ptr = (char *)malloc(1);
    if (!s->ptr) {
        return;
    }
    s->ptr[0] = '\0';
}

static size_t writefunc(void *ptr, size_t size, size_t nmemb, struct string *s)
{
    if (!s || (!ptr && nmemb))
        return 0;
    if (nmemb && size > (SIZE_MAX - s->len) / nmemb)
        return 0;

    size_t incoming = size * nmemb;
    if (incoming > SIZE_MAX - s->len - 1)
        return 0;

    size_t new_len = s->len + incoming;
    char *new_ptr = (char *)realloc(s->ptr, new_len + 1);
    if (!new_ptr) {
        return 0;
    }
    s->ptr = new_ptr;
    memcpy(s->ptr + s->len, ptr, incoming);
    s->len = new_len;
    s->ptr[s->len] = '\0';
    return incoming;
}

static void oauth_callback_error(
    void *user_data,
    int (*callback)(void *, const char *, const char *, const char *, int, int, const char *),
    const char *error)
{
    if (callback)
        callback(user_data, NULL, NULL, NULL, 0, 0, error);
}

/* Legacy authorization URL path retained for compatibility. */
char *c_yandex_oauth_code_on_page(const char *client_id)
{
    if (!client_id)
        return NULL;

    CURL *curl = curl_easy_init();
    if (!curl)
        return NULL;

    char *encoded = curl_easy_escape(curl, client_id, 0);
    if (!encoded) {
        curl_easy_cleanup(curl);
        return NULL;
    }

    size_t len = strlen("https://oauth.yandex.ru/authorize?response_type=code&client_id=")
               + strlen(encoded) + 1;
    char *url = (char *)malloc(len);
    if (url)
        snprintf(url, len, "https://oauth.yandex.ru/authorize?response_type=code&client_id=%s", encoded);

    curl_free(encoded);
    curl_easy_cleanup(curl);
    return url;
}

/* Legacy HTML parser retained for old auth flow. */
char *c_yandex_oauth_code_from_html(const char *html)
{
    if (!html)
        return NULL;

    const char *patterns[] = {
        "verification_code%3Fcode%3D",
        "class=\"verification-code-code\">"
    };
    const char *ends[] = { "&", "<" };

    for (int i = 0; i < 2; ++i) {
        const char *start = strstr(html, patterns[i]);
        if (!start)
            continue;
        start += strlen(patterns[i]);
        const char *end = strchr(start, ends[i][0]);
        if (!end || end <= start)
            continue;

        size_t len = (size_t)(end - start);
        char *code = (char *)malloc(len + 1);
        if (!code)
            return NULL;
        memcpy(code, start, len);
        code[len] = '\0';
        return code;
    }

    return NULL;
}

void c_yandex_oauth_code_from_user(
    const char *client_id,
    const char *device_id,
    const char *device_name,
    void *user_data,
    int (*callback)(
        void *user_data,
        const char *device_code,
        const char *user_code,
        const char *verification_url,
        int interval,
        int expires_in,
        const char *error))
{
    if (!callback)
        return;

    if (!client_id || !*client_id) {
        oauth_callback_error(user_data, callback, "Missing client_id");
        return;
    }

    if (!device_name)
        device_name = "iYMLegacy";

    if (!device_id || !*device_id) {
        oauth_callback_error(user_data, callback, "Missing device_id");
        return;
    }

    CURL *curl = curl_easy_init();
    if (!curl) {
        oauth_callback_error(user_data, callback, "curl_easy_init failed");
        return;
    }

    struct string response;
    init_string(&response);
    if (!response.ptr) {
        curl_easy_cleanup(curl);
        oauth_callback_error(user_data, callback, "Unable to allocate response buffer");
        return;
    }

    char *cid = curl_easy_escape(curl, client_id, 0);
    char *did = curl_easy_escape(curl, device_id, 0);
    char *dname = curl_easy_escape(curl, device_name, 0);

    if (!cid || !did || !dname) {
        if (cid) curl_free(cid);
        if (did) curl_free(did);
        if (dname) curl_free(dname);
        free(response.ptr);
        curl_easy_cleanup(curl);
        oauth_callback_error(user_data, callback, "Unable to encode OAuth request");
        return;
    }

    size_t body_len = strlen("client_id=") + strlen(cid) +
                      strlen("&device_id=") + strlen(did) +
                      strlen("&device_name=") + strlen(dname) + 1;
    char *body = (char *)malloc(body_len);
    if (!body) {
        curl_free(cid); curl_free(did); curl_free(dname);
        free(response.ptr);
        curl_easy_cleanup(curl);
        oauth_callback_error(user_data, callback, "Unable to allocate POST buffer");
        return;
    }

    snprintf(body, body_len, "client_id=%s&device_id=%s&device_name=%s", cid, did, dname);
    curl_free(cid); curl_free(did); curl_free(dname);

    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/x-www-form-urlencoded");
    headers = curl_slist_append(headers, "Accept: application/json");

    curl_easy_setopt(curl, CURLOPT_URL, "https://oauth.yandex.ru/device/code");
    curl_easy_setopt(curl, CURLOPT_POST, 1L);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)strlen(body));
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writefunc);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 20L);
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, VERIFY_SSL);

    CURLcode result = curl_easy_perform(curl);
    long http_status = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_status);

    free(body);
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (result != CURLE_OK) {
        const char *error = curl_easy_strerror(result);
        free(response.ptr);
        callback(user_data, NULL, NULL, NULL, 0, 0, error);
        return;
    }

    cJSON *json = cJSON_ParseWithLength(response.ptr, response.len);
    free(response.ptr);

    if (!json || !cJSON_IsObject(json)) {
        if (json) cJSON_Delete(json);
        callback(user_data, NULL, NULL, NULL, 0, 0, "Invalid JSON response from Yandex OAuth");
        return;
    }

    cJSON *error_description = cJSON_GetObjectItem(json, "error_description");
    if (cJSON_IsString(error_description) && error_description->valuestring) {
        callback(user_data, NULL, NULL, NULL, 0, 0, error_description->valuestring);
        cJSON_Delete(json);
        return;
    }

    if (http_status < 200 || http_status >= 300) {
        callback(user_data, NULL, NULL, NULL, 0, 0, "Yandex OAuth HTTP error");
        cJSON_Delete(json);
        return;
    }

    cJSON *device_code = cJSON_GetObjectItem(json, "device_code");
    cJSON *user_code = cJSON_GetObjectItem(json, "user_code");
    cJSON *verification_url = cJSON_GetObjectItem(json, "verification_url");
    cJSON *interval = cJSON_GetObjectItem(json, "interval");
    cJSON *expires_in = cJSON_GetObjectItem(json, "expires_in");

    if (!cJSON_IsString(device_code) || !device_code->valuestring ||
        !cJSON_IsString(user_code) || !user_code->valuestring ||
        !cJSON_IsString(verification_url) || !verification_url->valuestring ||
        !cJSON_IsNumber(interval) || !cJSON_IsNumber(expires_in)) {
        callback(user_data, NULL, NULL, NULL, 0, 0,
                 "Invalid device authorization response");
        cJSON_Delete(json);
        return;
    }

    callback(user_data,
             device_code->valuestring,
             user_code->valuestring,
             verification_url->valuestring,
             interval->valueint,
             expires_in->valueint,
             NULL);

    cJSON_Delete(json);
}

void c_yandex_oauth_get_token_from_user(
    const char *device_code,
    const char *client_id,
    const char *client_secret,
    int interval,
    int expires_in,
    void *user_data,
    int (*callback)(
        void *user_data,
        const char *access_token,
        int expires_in,
        const char *refresh_token,
        const char *error))
{
    if (!callback)
        return;
    if (!device_code || !*device_code) {
        callback(user_data, NULL, 0, NULL, "No device_code");
        return;
    }
    if (!client_id || !*client_id) {
        callback(user_data, NULL, 0, NULL, "No client_id");
        return;
    }
    if (!client_secret || !*client_secret) {
        callback(user_data, NULL, 0, NULL, "No client_secret");
        return;
    }

    if (interval <= 0) interval = 5;
    if (expires_in <= 0) expires_in = 600;

    int elapsed = 0;
    while (elapsed < expires_in) {
        sleep((unsigned int)interval);
        elapsed += interval;

        CURL *curl = curl_easy_init();
        if (!curl) {
            callback(user_data, NULL, 0, NULL, "curl_easy_init failed");
            return;
        }

        struct string response;
        init_string(&response);
        if (!response.ptr) {
            curl_easy_cleanup(curl);
            callback(user_data, NULL, 0, NULL, "Unable to allocate response buffer");
            return;
        }

        char *code = curl_easy_escape(curl, device_code, 0);
        char *cid = curl_easy_escape(curl, client_id, 0);
        char *secret = curl_easy_escape(curl, client_secret, 0);
        if (!code || !cid || !secret) {
            if (code) curl_free(code);
            if (cid) curl_free(cid);
            if (secret) curl_free(secret);
            free(response.ptr);
            curl_easy_cleanup(curl);
            callback(user_data, NULL, 0, NULL, "Unable to encode token request");
            return;
        }

        size_t body_len = strlen("grant_type=device_code&code=&client_id=&client_secret=") +
                          strlen(code) + strlen(cid) + strlen(secret) + 1;
        char *body = (char *)malloc(body_len);
        if (!body) {
            curl_free(code); curl_free(cid); curl_free(secret);
            free(response.ptr);
            curl_easy_cleanup(curl);
            callback(user_data, NULL, 0, NULL, "Unable to allocate POST buffer");
            return;
        }

        snprintf(body, body_len,
                 "grant_type=device_code&code=%s&client_id=%s&client_secret=%s",
                 code, cid, secret);
        curl_free(code); curl_free(cid); curl_free(secret);

        struct curl_slist *headers = NULL;
        headers = curl_slist_append(headers, "Content-Type: application/x-www-form-urlencoded");
        headers = curl_slist_append(headers, "Accept: application/json");

        curl_easy_setopt(curl, CURLOPT_URL, "https://oauth.yandex.ru/token");
        curl_easy_setopt(curl, CURLOPT_POST, 1L);
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body);
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)strlen(body));
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writefunc);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
        curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);
        curl_easy_setopt(curl, CURLOPT_TIMEOUT, 20L);
        curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
        curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, VERIFY_SSL);

        CURLcode result = curl_easy_perform(curl);
        long http_status = 0;
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_status);

        free(body);
        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);

        if (result != CURLE_OK) {
            free(response.ptr);
            continue;
        }

        /* Log only the token endpoint status/error payload, never the request body.
         * This is useful on legacy devices when authorization succeeds in the browser
         * but the app cannot exchange the device_code for a token.
         */
        if (http_status < 200 || http_status >= 300) {
            fprintf(stderr, "Yandex OAuth /token HTTP %ld: %s\n",
                    http_status, response.ptr ? response.ptr : "");
        }

        cJSON *json = cJSON_ParseWithLength(response.ptr, response.len);
        free(response.ptr);
        if (!json || !cJSON_IsObject(json)) {
            if (json) cJSON_Delete(json);
            continue;
        }

        cJSON *access_token = cJSON_GetObjectItem(json, "access_token");
        if (cJSON_IsString(access_token) && access_token->valuestring) {
            cJSON *expires = cJSON_GetObjectItem(json, "expires_in");
            cJSON *refresh = cJSON_GetObjectItem(json, "refresh_token");
            int token_expires = cJSON_IsNumber(expires) ? expires->valueint : 0;
            const char *refresh_value =
                (cJSON_IsString(refresh) && refresh->valuestring) ? refresh->valuestring : NULL;
            callback(user_data, access_token->valuestring,
                     token_expires, refresh_value, NULL);
            cJSON_Delete(json);
            return;
        }

        cJSON *error = cJSON_GetObjectItem(json, "error");
        cJSON *description = cJSON_GetObjectItem(json, "error_description");
        const char *error_code = (cJSON_IsString(error) ? error->valuestring : NULL);
        const char *error_text = (cJSON_IsString(description) ? description->valuestring : NULL);

        if (error_code && strcmp(error_code, "authorization_pending") == 0) {
            cJSON_Delete(json);
            continue;
        }
        if (error_text && strcmp(error_text, "User has not yet authorized your application") == 0) {
            cJSON_Delete(json);
            continue;
        }
        if (error_code && strcmp(error_code, "slow_down") == 0) {
            interval += 5;
            cJSON_Delete(json);
            continue;
        }

        if (http_status >= 200 && http_status < 300 && !error_code && !error_text) {
            cJSON_Delete(json);
            continue;
        }

        callback(user_data, NULL, 0, NULL,
                 error_text ? error_text :
                 (error_code ? error_code : "Yandex OAuth token request failed"));
        cJSON_Delete(json);
        return;
    }

    callback(user_data, NULL, 0, NULL, "Device authorization code expired");
}

/* Authorization-code flow retained for compatibility. */
void c_yandex_oauth_get_token(
    const char *verification_code,
    const char *client_id,
    const char *client_secret,
    const char *device_name,
    void *user_data,
    int (*callback)(
        void *user_data,
        const char *access_token,
        int expires_in,
        const char *refresh_token,
        const char *error))
{
    if (!callback)
        return;
    if (!verification_code || !*verification_code) {
        callback(user_data, NULL, 0, NULL, "No verification_code");
        return;
    }
    if (!client_id || !*client_id) {
        callback(user_data, NULL, 0, NULL, "No client_id");
        return;
    }
    if (!client_secret || !*client_secret) {
        callback(user_data, NULL, 0, NULL, "No client_secret");
        return;
    }

    CURL *curl = curl_easy_init();
    if (!curl) {
        callback(user_data, NULL, 0, NULL, "curl_easy_init failed");
        return;
    }

    struct string response;
    init_string(&response);
    if (!response.ptr) {
        curl_easy_cleanup(curl);
        callback(user_data, NULL, 0, NULL, "Unable to allocate response buffer");
        return;
    }

    char *code = curl_easy_escape(curl, verification_code, 0);
    char *cid = curl_easy_escape(curl, client_id, 0);
    char *secret = curl_easy_escape(curl, client_secret, 0);
    char *dname = curl_easy_escape(curl, device_name ? device_name : "iYMLegacy", 0);
    if (!code || !cid || !secret || !dname) {
        if (code) curl_free(code);
        if (cid) curl_free(cid);
        if (secret) curl_free(secret);
        if (dname) curl_free(dname);
        free(response.ptr);
        curl_easy_cleanup(curl);
        callback(user_data, NULL, 0, NULL, "Unable to encode token request");
        return;
    }

    size_t body_len = strlen("grant_type=authorization_code&code=&client_id=&client_secret=&device_name=") +
                      strlen(code) + strlen(cid) + strlen(secret) + strlen(dname) + 1;
    char *body = (char *)malloc(body_len);
    if (!body) {
        curl_free(code); curl_free(cid); curl_free(secret); curl_free(dname);
        free(response.ptr);
        curl_easy_cleanup(curl);
        callback(user_data, NULL, 0, NULL, "Unable to allocate POST buffer");
        return;
    }

    snprintf(body, body_len,
             "grant_type=authorization_code&code=%s&client_id=%s&client_secret=%s&device_name=%s",
             code, cid, secret, dname);
    curl_free(code); curl_free(cid); curl_free(secret); curl_free(dname);

    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/x-www-form-urlencoded");
    headers = curl_slist_append(headers, "Accept: application/json");

    curl_easy_setopt(curl, CURLOPT_URL, "https://oauth.yandex.ru/token");
    curl_easy_setopt(curl, CURLOPT_POST, 1L);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)strlen(body));
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writefunc);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 20L);
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, VERIFY_SSL);

    CURLcode result = curl_easy_perform(curl);
    free(body);
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (result != CURLE_OK) {
        callback(user_data, NULL, 0, NULL, curl_easy_strerror(result));
        free(response.ptr);
        return;
    }

    cJSON *json = cJSON_ParseWithLength(response.ptr, response.len);
    free(response.ptr);
    if (!json || !cJSON_IsObject(json)) {
        if (json) cJSON_Delete(json);
        callback(user_data, NULL, 0, NULL, "Invalid JSON response from Yandex OAuth");
        return;
    }

    cJSON *access = cJSON_GetObjectItem(json, "access_token");
    if (!cJSON_IsString(access) || !access->valuestring) {
        cJSON *desc = cJSON_GetObjectItem(json, "error_description");
        callback(user_data, NULL, 0, NULL,
                 (cJSON_IsString(desc) && desc->valuestring) ? desc->valuestring : "Yandex OAuth token error");
        cJSON_Delete(json);
        return;
    }

    cJSON *expires = cJSON_GetObjectItem(json, "expires_in");
    cJSON *refresh = cJSON_GetObjectItem(json, "refresh_token");
    callback(user_data,
             access->valuestring,
             cJSON_IsNumber(expires) ? expires->valueint : 0,
             (cJSON_IsString(refresh) ? refresh->valuestring : NULL),
             NULL);
    cJSON_Delete(json);
}


void c_yandex_oauth_refresh_token(
    const char *refresh_token,
    const char *client_id,
    const char *client_secret,
    void *user_data,
    void (*callback)(
        void *user_data,
        const char *access_token,
        int expires_in,
        const char *refresh_token,
        const char *error))
{
    if (!callback) return;
    if (!refresh_token || !*refresh_token) {
        callback(user_data, NULL, 0, NULL, "No refresh_token");
        return;
    }
    if (!client_id || !*client_id) {
        callback(user_data, NULL, 0, NULL, "No client_id");
        return;
    }
    if (!client_secret || !*client_secret) {
        callback(user_data, NULL, 0, NULL, "No client_secret");
        return;
    }

    CURL *curl = curl_easy_init();
    if (!curl) {
        callback(user_data, NULL, 0, NULL, "curl_easy_init failed");
        return;
    }

    struct string response;
    init_string(&response);
    if (!response.ptr) {
        curl_easy_cleanup(curl);
        callback(user_data, NULL, 0, NULL, "Unable to allocate response buffer");
        return;
    }

    char *rt = curl_easy_escape(curl, refresh_token, 0);
    char *cid = curl_easy_escape(curl, client_id, 0);
    char *secret = curl_easy_escape(curl, client_secret, 0);
    if (!rt || !cid || !secret) {
        if (rt) curl_free(rt);
        if (cid) curl_free(cid);
        if (secret) curl_free(secret);
        free(response.ptr);
        curl_easy_cleanup(curl);
        callback(user_data, NULL, 0, NULL, "Unable to encode refresh request");
        return;
    }

    size_t body_len = strlen("grant_type=refresh_token&refresh_token=&client_id=&client_secret=") +
                      strlen(rt) + strlen(cid) + strlen(secret) + 1;
    char *body = (char *)malloc(body_len);
    if (!body) {
        curl_free(rt); curl_free(cid); curl_free(secret);
        free(response.ptr);
        curl_easy_cleanup(curl);
        callback(user_data, NULL, 0, NULL, "Unable to allocate POST buffer");
        return;
    }

    snprintf(body, body_len,
             "grant_type=refresh_token&refresh_token=%s&client_id=%s&client_secret=%s",
             rt, cid, secret);
    curl_free(rt); curl_free(cid); curl_free(secret);

    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/x-www-form-urlencoded");
    headers = curl_slist_append(headers, "Accept: application/json");

    curl_easy_setopt(curl, CURLOPT_URL, "https://oauth.yandex.ru/token");
    curl_easy_setopt(curl, CURLOPT_POST, 1L);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)strlen(body));
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writefunc);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 20L);
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, VERIFY_SSL);

    CURLcode result = curl_easy_perform(curl);
    free(body);
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (result != CURLE_OK) {
        callback(user_data, NULL, 0, NULL, curl_easy_strerror(result));
        free(response.ptr);
        return;
    }

    cJSON *json = cJSON_ParseWithLength(response.ptr, response.len);
    free(response.ptr);
    if (!json || !cJSON_IsObject(json)) {
        if (json) cJSON_Delete(json);
        callback(user_data, NULL, 0, NULL, "Invalid JSON response from Yandex OAuth");
        return;
    }

    cJSON *access = cJSON_GetObjectItem(json, "access_token");
    if (!cJSON_IsString(access) || !access->valuestring) {
        cJSON *desc = cJSON_GetObjectItem(json, "error_description");
        callback(user_data, NULL, 0, NULL,
                 (cJSON_IsString(desc) && desc->valuestring) ? desc->valuestring : "Yandex OAuth refresh error");
        cJSON_Delete(json);
        return;
    }

    cJSON *expires = cJSON_GetObjectItem(json, "expires_in");
    cJSON *new_refresh = cJSON_GetObjectItem(json, "refresh_token");
    callback(user_data,
             access->valuestring,
             cJSON_IsNumber(expires) ? expires->valueint : 0,
             (cJSON_IsString(new_refresh) && new_refresh->valuestring) ? new_refresh->valuestring : refresh_token,
             NULL);
    cJSON_Delete(json);
}
