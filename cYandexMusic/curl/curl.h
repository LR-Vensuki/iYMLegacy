#ifndef IYMLEGACY_CURL_COMPAT_H
#define IYMLEGACY_CURL_COMPAT_H

/*
 * Minimal libcurl 7.58.0 application header for the bundled legacy iOS
 * libcurl.dylib. This deliberately exposes only the public API used by
 * iYMLegacy, avoiding a dependency on a host-machine curl SDK.
 */

#include <stddef.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void CURL;
typedef int CURLcode;
typedef int CURLoption;
typedef int CURLINFO;

struct curl_slist {
    char *data;
    struct curl_slist *next;
};

typedef size_t (*curl_write_callback)(char *buffer,
                                      size_t size,
                                      size_t nitems,
                                      void *outstream);

/* libcurl 7.58.0 option values. */
#define CURLOPT_WRITEDATA       10001
#define CURLOPT_URL             10002
#define CURLOPT_POST            47
#define CURLOPT_POSTFIELDS      10015
#define CURLOPT_WRITEFUNCTION   20011
#define CURLOPT_TIMEOUT         13
#define CURLOPT_HTTPHEADER      10023
#define CURLOPT_CUSTOMREQUEST   10036
#define CURLOPT_FOLLOWLOCATION  52
#define CURLOPT_POSTFIELDSIZE   60
#define CURLOPT_SSL_VERIFYPEER  64
#define CURLOPT_CONNECTTIMEOUT  78
#define CURLOPT_NOSIGNAL        99

/* libcurl 7.58.0 CURLINFO_RESPONSE_CODE. */
#define CURLINFO_RESPONSE_CODE  0x200002

#define CURLE_OK 0

CURL *curl_easy_init(void);
CURLcode curl_easy_setopt(CURL *handle, CURLoption option, ...);
CURLcode curl_easy_perform(CURL *handle);
CURLcode curl_easy_getinfo(CURL *handle, CURLINFO info, ...);
void curl_easy_cleanup(CURL *handle);
const char *curl_easy_strerror(CURLcode code);

struct curl_slist *curl_slist_append(struct curl_slist *list,
                                     const char *data);
void curl_slist_free_all(struct curl_slist *list);

char *curl_easy_escape(CURL *handle, const char *string, int length);
void curl_free(void *p);

#ifdef __cplusplus
}
#endif

#endif /* IYMLEGACY_CURL_COMPAT_H */
