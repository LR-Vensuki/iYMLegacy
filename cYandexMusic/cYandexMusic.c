/**
 * File              : cYandexMusic.c
 * Author            : Igor V. Sementsov <ig.kuzm@gmail.com>
 * Date              : 22.08.2023
 * Last Modified Date: 11.09.2023
 * Last Modified By  : Igor V. Sementsov <ig.kuzm@gmail.com>
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <curl/curl.h>
#include <time.h>
#include <stdint.h>
#include "cYandexMusic.h"
#include "cJSON.h"
#include "structures.h"
#include "ezxml.h"
#include "md5.h"
#include "uuid4.h"

//add strptime for winapi
#ifdef _WIN32
char * strptime(const char* s, const char* f, struct tm* tm);
#endif

#define API_URL "https://api.music.yandex.net"
#ifndef VERIFY_SSL
#define VERIFY_SSL 0
#endif

#define YM_CLIENT_HEADER "YandexMusicAndroid/24023621"
#define YM_USER_AGENT "iYMLegacy/2.0 (iOS 6)"

#define YD_ANSWER_LIMIT 20

static int lastpath(const char *filename) {
    const char *slash;
    if (!filename)
        return -1;
    slash = strrchr(filename, '/');
    if (!slash || slash == filename)
        return -1;
    return (int)(slash - filename);
}

/* Build an artwork URL without modifying the original string or using a
 * fixed-size temporary buffer. */
static char *ym_image_url(const char *uri, const char *size)
{
    if (!uri || !*uri)
        return NULL;
    if (!size || !*size)
        size = "orig";

    int slash = lastpath(uri);
    if (slash < 0)
        return strdup(uri);

    size_t prefix_len = (size_t)slash;
    size_t total = prefix_len + 1 + strlen(size) + strlen("https://") + 1;
    char *out = (char *)malloc(total);
    if (!out)
        return NULL;

    snprintf(out, total, "https://%.*s/%s", slash, uri, size);
    return out;
}

static void ym_replace_image_uri(char **field, const char *size)
{
    if (!field || !*field)
        return;
    char *replacement = ym_image_url(*field, size);
    if (!replacement)
        return;
    free(*field);
    *field = replacement;
}

struct str {
	char *ptr;
	size_t len;
};

void init_str(struct str *s) {
	s->len = 0;
	s->ptr = malloc(s->len+1);
	if (!s->ptr){
		perror("malloc");
		return;
	}
	s->ptr[0] = '\0';
}

size_t writefunc(void *ptr, size_t size, size_t nmemb, struct str *s)
{
    if (!s || !ptr || (nmemb && size > (SIZE_MAX - s->len) / nmemb))
        return 0;

    size_t bytes = size * nmemb;
    size_t new_len = s->len + bytes;
    char *new_ptr = realloc(s->ptr, new_len + 1);
    if (!new_ptr){
        perror("realloc");
        return 0;
    }

    s->ptr = new_ptr;
    memcpy(s->ptr + s->len, ptr, bytes);
    s->ptr[new_len] = '\0';
    s->len = new_len;

    return bytes;
}

static const char *ym_normalize_method(const char *method)
{
    while (method && *method == '/')
        ++method;
    return method ? method : "";
}

static char *ym_build_url(const char *method, va_list args)
{
    const char *clean = ym_normalize_method(method);
    size_t size = strlen(API_URL) + 1 + strlen(clean) + 1;

    va_list copy;
    va_copy(copy, args);
    const char *arg;
    int first = 1;
    while ((arg = va_arg(copy, const char *)) != NULL) {
        size += strlen(arg) + 2;
        first = 0;
    }
    va_end(copy);

    char *url = (char *)malloc(size + 1);
    if (!url)
        return NULL;

    int written = snprintf(url, size + 1, "%s/%s", API_URL, clean);
    if (written < 0) {
        free(url);
        return NULL;
    }

    size_t pos = (size_t)written;
    va_copy(copy, args);
    first = 1;
    while ((arg = va_arg(copy, const char *)) != NULL) {
        int n = snprintf(url + pos, size + 1 - pos,
                         first ? "?%s" : "&%s", arg);
        if (n < 0 || (size_t)n >= size + 1 - pos) {
            va_end(copy);
            free(url);
            return NULL;
        }
        pos += (size_t)n;
        first = 0;
    }
    va_end(copy);
    return url;
}

static const char *ym_json_error(cJSON *json)
{
    if (!json || !cJSON_IsObject(json))
        return NULL;
    cJSON *error = cJSON_GetObjectItem(json, "error");
    if (cJSON_IsString(error) && error->valuestring)
        return error->valuestring;
    if (error && cJSON_IsObject(error)) {
        cJSON *message = cJSON_GetObjectItem(error, "message");
        if (cJSON_IsString(message) && message->valuestring)
            return message->valuestring;
        cJSON *desc = cJSON_GetObjectItem(error, "description");
        if (cJSON_IsString(desc) && desc->valuestring)
            return desc->valuestring;
    }
    cJSON *desc = cJSON_GetObjectItem(json, "error_description");
    if (cJSON_IsString(desc) && desc->valuestring)
        return desc->valuestring;
    return NULL;
}

int c_yandex_music_run_method(
        const char *http_method,
        const char *token,
        const char *body,
        void *user_data,
        void (*callback)(void *user_data, const char *response_json, const char *error),
        const char *method,
        ...)
{
    if (!http_method || !method) {
        if (callback) callback(user_data, NULL, "Invalid API request");
        return -1;
    }
    if (!token || !*token) {
        if (callback) callback(user_data, NULL, "Missing OAuth token");
        return -1;
    }

    CURL *curl = curl_easy_init();
    if (!curl) {
        if (callback) callback(user_data, NULL, "curl_easy_init failed");
        return -1;
    }

    struct str response;
    init_str(&response);
    if (!response.ptr) {
        curl_easy_cleanup(curl);
        if (callback) callback(user_data, NULL, "Unable to allocate response buffer");
        return -1;
    }

    va_list args;
    va_start(args, method);
    char *url = ym_build_url(method, args);
    va_end(args);

    if (!url) {
        free(response.ptr);
        curl_easy_cleanup(curl);
        if (callback) callback(user_data, NULL, "Unable to build API URL");
        return -1;
    }

    char authorization[BUFSIZ];
    snprintf(authorization, sizeof(authorization), "Authorization: OAuth %s", token);

    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Accept: application/json");
    if (body)
        headers = curl_slist_append(headers, "Content-Type: application/x-www-form-urlencoded");
    headers = curl_slist_append(headers, "Accept-Language: ru");
    headers = curl_slist_append(headers, authorization);

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, http_method);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writefunc);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, VERIFY_SSL);
    if (body) {
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body);
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)strlen(body));
    }

    CURLcode result = curl_easy_perform(curl);
    long http_status = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_status);

    free(url);
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (result != CURLE_OK) {
        const char *err = curl_easy_strerror(result);
        if (callback) callback(user_data, NULL, err);
        free(response.ptr);
        return -1;
    }

    if (response.len == 0) {
        if (http_status >= 200 && http_status < 300) {
            if (callback) callback(user_data, "{}", NULL);
            free(response.ptr);
            return 0;
        }
        if (callback) callback(user_data, NULL, "Empty response from Yandex Music API");
        free(response.ptr);
        return -1;
    }

    cJSON *json = cJSON_ParseWithLength(response.ptr, response.len);
    if (!json) {
        char msg[BUFSIZ];
        snprintf(msg, sizeof(msg), "Can't parse JSON from Yandex Music (HTTP %ld)", http_status);
        if (callback) callback(user_data, NULL, msg);
        free(response.ptr);
        return -1;
    }

    const char *json_error = ym_json_error(json);
    if (http_status < 200 || http_status >= 300 || json_error) {
        char msg[1200];
        const char *detail = json_error;
        if (detail && *detail) {
            snprintf(msg, sizeof(msg), "Yandex Music HTTP %ld: %s", http_status, detail);
        } else if (response.ptr && *response.ptr) {
            snprintf(msg, sizeof(msg), "Yandex Music HTTP %ld: %.900s", http_status, response.ptr);
        } else {
            snprintf(msg, sizeof(msg), "Yandex Music HTTP error (HTTP %ld)", http_status);
        }
        if (callback)
            callback(user_data, NULL, msg);
        cJSON_Delete(json);
        free(response.ptr);
        return -1;
    }

    cJSON *payload = cJSON_GetObjectItem(json, "result");
    char *printed = NULL;
    if (payload)
        printed = cJSON_PrintUnformatted(payload);
    else
        printed = cJSON_PrintUnformatted(json);

    if (!printed) {
        if (callback) callback(user_data, NULL, "Can't serialize Yandex Music response");
        cJSON_Delete(json);
        free(response.ptr);
        return -1;
    }

    if (callback)
        callback(user_data, printed, NULL);
    free(printed);
    cJSON_Delete(json);
    free(response.ptr);
    return 0;
}

struct c_yandex_music_get_feed_data {
	void *user_data; 
	int (*callback)(void *, playlist_t *, track_t *, const char *);
	const char *image_size; 
};
static void c_yandex_music_get_feed_cb(
		void *data, const char *str, const char *error)
{
	struct c_yandex_music_get_feed_data *d = data;
	
	const char *size = "orig";
	if (d->image_size)
		size = d->image_size;

	if (error) {
		if (d->callback)
			d->callback(d->user_data, NULL, NULL, error);
		return;
	}
	if (str){
		cJSON *json = cJSON_Parse(str);
		if (json){
			//d->callback(d->user_data, NULL, NULL, cJSON_Print(json));
			//return;
			cJSON *generatedPlaylists = 
					cJSON_GetObjectItem(json, "generatedPlaylists");
			if (generatedPlaylists){
				cJSON *generatedPlaylist;
			 for (generatedPlaylist = generatedPlaylists->child;
					 generatedPlaylist;
					 generatedPlaylist = generatedPlaylist->next) 
			 {
				cJSON *data = 
						cJSON_GetObjectItem(generatedPlaylist, "data");
				if (data){
					playlist_t *p = 
							c_yandex_music_playlist_new_from_json(data);
					if (p){
						// fix image
					ym_replace_image_uri(&p->ogImage, size);
						int stop = d->callback ? d->callback(d->user_data, p, NULL, NULL) : 0;
						c_yandex_music_playlist_free(p);
						if (stop) {
							cJSON_Delete(json);
							return;
						}
					}
				}
			 }	
			}
			cJSON *days = 
				cJSON_GetObjectItem(json, "days");
			if (days){
				cJSON *day;
				for (day = days->child; day; day = day->next) 
				{
					cJSON *tracksToPlay = 
						cJSON_GetObjectItem(day, "tracksToPlay");
					if (tracksToPlay){
						cJSON *track;
						for (track = tracksToPlay->child; track; 
								track = track->next) 
						{
							track_t *p = 
								c_yandex_music_track_new_from_json(track);
							if (p){
								//fix uris
					ym_replace_image_uri(&p->coverUri, size);
					ym_replace_image_uri(&p->ogImage, size);

								int stop = d->callback ? d->callback(d->user_data, NULL, p, NULL) : 0;
								c_yandex_music_track_free(p);
								if (stop) {
									cJSON_Delete(json);
									return;
								}
							}
						}
					}
				}
			}
		} else {
			if (d->callback){
				char msg[BUFSIZ];
				snprintf(msg, sizeof(msg), "can't parse json from string: %s", str);
				d->callback(d->user_data, NULL, NULL, msg);
			}
		}
	}
}
int c_yandex_music_get_feed(
		const char *token,       
		const char *image_size,
		void *user_data, 
		int (*callback)         
				(void *user_data,
				 playlist_t * playlist,
				 track_t * track,
				 const char *error))
{
	struct c_yandex_music_get_feed_data d =
		{user_data, callback, image_size};
	return c_yandex_music_run_method(
			"GET", token, NULL, &d, c_yandex_music_get_feed_cb, "/feed", NULL);
}

struct c_yandex_music_get_download_url_data {
	void *user_data; 
	int (*callback)(void *, const char *, const char *);
	const char *token;
};
static void c_yandex_music_get_download_url_cb(
        void *data, const char *str, const char *error)
{
    struct c_yandex_music_get_download_url_data *d = data;
    if (error) {
        if (d->callback) d->callback(d->user_data, NULL, error);
        return;
    }
    if (!str) {
        if (d->callback) d->callback(d->user_data, NULL, "Empty download-info response");
        return;
    }

    cJSON *json = cJSON_Parse(str);
    if (!json || !cJSON_IsArray(json)) {
        if (json) cJSON_Delete(json);
        if (d->callback) d->callback(d->user_data, NULL, "Invalid download-info JSON");
        return;
    }

    cJSON *best = NULL;
    int best_score = -1;
    cJSON *item = NULL;
    cJSON_ArrayForEach(item, json) {
        cJSON *codec = cJSON_GetObjectItem(item, "codec");
        cJSON *bitrate = cJSON_GetObjectItem(item, "bitrateInKbps");
        cJSON *direct = cJSON_GetObjectItem(item, "direct");
        cJSON *url = cJSON_GetObjectItem(item, "downloadInfoUrl");
        if (!cJSON_IsString(codec) || !codec->valuestring ||
            !cJSON_IsString(url) || !url->valuestring)
            continue;

        /* We construct the final URL using the /get-mp3/ endpoint, so
         * never select AAC/FLAC/etc. for this code path. */
        if (strcmp(codec->valuestring, "mp3") != 0)
            continue;

        int score = cJSON_IsNumber(bitrate) ? bitrate->valueint : 0;
        if (cJSON_IsTrue(direct)) score += 10;
        if (!best || score > best_score) {
            best = item;
            best_score = score;
        }
    }

    if (!best) {
        cJSON_Delete(json);
        if (d->callback) d->callback(d->user_data, NULL, "No playable download format");
        return;
    }

    cJSON *url_json = cJSON_GetObjectItem(best, "downloadInfoUrl");
    const char *download_info_url = url_json->valuestring;

    CURL *curl = curl_easy_init();
    if (!curl) {
        cJSON_Delete(json);
        if (d->callback) d->callback(d->user_data, NULL, "curl_easy_init failed");
        return;
    }

    struct str xml_response;
    init_str(&xml_response);
    if (!xml_response.ptr) {
        curl_easy_cleanup(curl);
        cJSON_Delete(json);
        if (d->callback) d->callback(d->user_data, NULL, "Unable to allocate XML buffer");
        return;
    }

    struct curl_slist *headers = NULL;
    char authorization[BUFSIZ];
    snprintf(authorization, sizeof(authorization), "Authorization: OAuth %s", d->token ? d->token : "");
    headers = curl_slist_append(headers, authorization);
    headers = curl_slist_append(headers, "Accept: application/xml");

    curl_easy_setopt(curl, CURLOPT_URL, download_info_url);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writefunc);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &xml_response);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 20L);
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, VERIFY_SSL);

    CURLcode result = curl_easy_perform(curl);
    long status = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &status);
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (result != CURLE_OK || status < 200 || status >= 300) {
        const char *err = (result != CURLE_OK) ? curl_easy_strerror(result) : "Download info HTTP error";
        if (d->callback) d->callback(d->user_data, NULL, err);
        free(xml_response.ptr);
        cJSON_Delete(json);
        return;
    }

    ezxml_t root = ezxml_parse_str(xml_response.ptr, xml_response.len);
    if (!root) {
        free(xml_response.ptr);
        cJSON_Delete(json);
        if (d->callback) d->callback(d->user_data, NULL, "Invalid download-info XML");
        return;
    }

    ezxml_t host_node = ezxml_child(root, "host");
    ezxml_t path_node = ezxml_child(root, "path");
    ezxml_t ts_node = ezxml_child(root, "ts");
    ezxml_t s_node = ezxml_child(root, "s");

    const char *host = host_node ? ezxml_txt(host_node) : NULL;
    const char *path = path_node ? ezxml_txt(path_node) : NULL;
    const char *ts = ts_node ? ezxml_txt(ts_node) : NULL;
    const char *salt = s_node ? ezxml_txt(s_node) : NULL;

    if (!host || !*host || !path || !*path || !ts || !*ts || !salt || !*salt) {
        ezxml_free(root);
        free(xml_response.ptr);
        cJSON_Delete(json);
        if (d->callback) d->callback(d->user_data, NULL, "Incomplete download-info XML");
        return;
    }

    const char *path_without_slash = path[0] == '/' ? path + 1 : path;
    const char *salt_prefix = "XGRlBW9FXlekgbPrRHuSiA";

    size_t material_len = strlen(salt_prefix) + strlen(path_without_slash) + strlen(salt) + 1;
    char *material = (char *)malloc(material_len);
    if (!material) {
        ezxml_free(root);
        free(xml_response.ptr);
        cJSON_Delete(json);
        if (d->callback) d->callback(d->user_data, NULL, "Unable to allocate sign buffer");
        return;
    }
    snprintf(material, material_len, "%s%s%s", salt_prefix, path_without_slash, salt);

    unsigned char digest[16];
    md5String(material, digest);
    free(material);

    char sign[33];
    for (int i = 0; i < 16; ++i)
        snprintf(sign + i * 2, 3, "%02x", digest[i]);
    sign[32] = '\0';

    size_t final_len = strlen("https://") + strlen(host) + strlen("/get-mp3/") +
                       strlen(sign) + 1 + strlen(ts) + strlen(path) + 1;
    char *final_url = (char *)malloc(final_len);
    if (!final_url) {
        ezxml_free(root);
        free(xml_response.ptr);
        cJSON_Delete(json);
        if (d->callback) d->callback(d->user_data, NULL, "Unable to allocate download URL");
        return;
    }

    snprintf(final_url, final_len,
             "https://%s/get-mp3/%s/%s%s",
             host, sign, ts, path);

    if (d->callback)
        d->callback(d->user_data, final_url, NULL);

    free(final_url);
    ezxml_free(root);
    free(xml_response.ptr);
    cJSON_Delete(json);
}

int c_yandex_music_get_download_url(
        const char *token,
        const char *track_id,
        void *user_data,
        int (*callback)(void *user_data, const char *url, const char *error))
{
    if (!token || !*token || !track_id || !*track_id) {
        if (callback) callback(user_data, NULL, "Missing token or track_id");
        return -1;
    }

    struct c_yandex_music_get_download_url_data d = {user_data, callback, token};
    char method[BUFSIZ];
    snprintf(method, sizeof(method), "tracks/%s/download-info", track_id);
    return c_yandex_music_run_method("GET", token, NULL, &d,
                                     c_yandex_music_get_download_url_cb,
                                     method, "canGetLossless=false", NULL);
}

struct c_yandex_music_search_data {
	void *user_data; 
	int (*callback)(void *, playlist_t *, album_t *, track_t *, const char *);
	const char *token;
	const char *image_size;	 // NULL - for original
};
static void c_yandex_music_search_cb(
		void *data, const char *str, const char *error)
{
	struct c_yandex_music_search_data *d = data;
	if (error) {
		if (d->callback)
			d->callback(d->user_data, NULL, NULL, NULL, error);
		return;
	}
	if (str){
		cJSON *json = cJSON_Parse(str);
		if (json){
			//d->callback(d->user_data, NULL, NULL, NULL, cJSON_Print(json));
			//return;
			cJSON *best = cJSON_GetObjectItem(json, "best");
			if (best){
				cJSON *type = cJSON_GetObjectItem(best, "type");
				cJSON *result = cJSON_GetObjectItem(best, "result");
				const char *best_type =
					(cJSON_IsString(type) && type->valuestring) ? type->valuestring : NULL;
				const char *size = d->image_size ? d->image_size : "orig";
				int stop = 0;

				if (result && best_type){
					if (strcmp(best_type, "track") == 0 ||
						strcmp(best_type, "podcast_episode") == 0){
						track_t *p = c_yandex_music_track_new_from_json(result);
						if (p){
							if (p->type) free(p->type);
							p->type = strdup(strcmp(best_type, "podcast_episode") == 0 ?
								"podcast-episode" : "track");
							ym_replace_image_uri(&p->coverUri, size);
							ym_replace_image_uri(&p->ogImage, "orig");
							stop = d->callback ? d->callback(d->user_data, NULL, NULL, p, NULL) : 0;
							c_yandex_music_track_free(p);
						}
					} else if (strcmp(best_type, "album") == 0 ||
						strcmp(best_type, "podcast") == 0){
						album_t *p = c_yandex_music_album_new_from_json(result);
						if (p){
							if (p->type) free(p->type);
							p->type = strdup(strcmp(best_type, "podcast") == 0 ? "podcast" : "album");
							ym_replace_image_uri(&p->coverUri, size);
							ym_replace_image_uri(&p->ogImage, "orig");
							stop = d->callback ? d->callback(d->user_data, NULL, p, NULL, NULL) : 0;
							c_yandex_music_album_free(p);
						}
					} else if (strcmp(best_type, "playlist") == 0){
						playlist_t *p = c_yandex_music_playlist_new_from_json(result);
						if (p){
							ym_replace_image_uri(&p->ogImage, "orig");
							stop = d->callback ? d->callback(d->user_data, p, NULL, NULL, NULL) : 0;
							c_yandex_music_playlist_free(p);
						}
					}
				}
				if (stop){
					cJSON_Delete(json);
					return;
				}
			}

			cJSON *tracks = cJSON_GetObjectItem(json, "tracks");
			if (tracks){
				cJSON *results = cJSON_GetObjectItem(tracks, "results");
				cJSON *track;
				for (track = results ? results->child : NULL; track; track = track->next){
					track_t *p = c_yandex_music_track_new_from_json(track);
					if (p){
						// set type
						/*if (p->type)*/
							/*free(p->type);*/
						p->type = strdup("track");
						//fix uris
						const char *size = "orig";
						if (d->image_size)
							size = d->image_size;
					ym_replace_image_uri(&p->coverUri, size);
					ym_replace_image_uri(&p->ogImage, "orig");
						int stop = d->callback ? d->callback(d->user_data, NULL, NULL, p, NULL) : 0;
						 c_yandex_music_track_free(p);
						if (stop)
							break;
					}
				}
			}
			cJSON *albums = cJSON_GetObjectItem(json, "albums");
			if (albums){
				cJSON *results = cJSON_GetObjectItem(albums, "results");
				cJSON *album;
				for (album = results ? results->child : NULL; album; album = album->next){
					album_t *p = c_yandex_music_album_new_from_json(album);
					if (p){
						//fix uris
						const char *size = "orig";
						if (d->image_size)
							size = d->image_size;
					ym_replace_image_uri(&p->coverUri, size);
					ym_replace_image_uri(&p->ogImage, "orig");
						int stop = d->callback ? d->callback(d->user_data, NULL, p, NULL, NULL) : 0;
						c_yandex_music_album_free(p);
						if (stop)
							break;
					}
				}
			}
			cJSON *podcasts = cJSON_GetObjectItem(json, "podcasts");
			if (podcasts){
				cJSON *results = cJSON_GetObjectItem(podcasts, "results");
				cJSON *album;
				for (album = results ? results->child : NULL; album; album = album->next){
					album_t *p = c_yandex_music_album_new_from_json(album);
					if (p){
						// set type
						/*if (p->type)*/
							/*free(p->type);*/
						p->type = strdup("podcast");
						//fix uris
						const char *size = "orig";
						if (d->image_size)
							size = d->image_size;
					ym_replace_image_uri(&p->coverUri, size);
					ym_replace_image_uri(&p->ogImage, "orig");
						int stop = d->callback ? d->callback(d->user_data, NULL, p, NULL, NULL) : 0;
						c_yandex_music_album_free(p);
						if (stop)
							break;
					}
				}
			}
			cJSON *podcast_episodes = cJSON_GetObjectItem(json, "podcast_episodes");
			if (podcast_episodes){
				cJSON *results = cJSON_GetObjectItem(podcast_episodes, "results");
				cJSON *track;
				for (track = results ? results->child : NULL; track; track = track->next){
					track_t *p = c_yandex_music_track_new_from_json(track);
					if (p){
						// set type
						/*if (p->type)*/
							/*free(p->type);*/
						p->type = strdup("podcast-episode");
						//fix uris
						const char *size = "orig";
						if (d->image_size)
							size = d->image_size;
					ym_replace_image_uri(&p->coverUri, size);
					ym_replace_image_uri(&p->ogImage, "orig");
						int stop = d->callback ? d->callback(d->user_data, NULL, NULL, p, NULL) : 0;
						c_yandex_music_track_free(p);
						if (stop)
							break;
					}
				}
			}
			cJSON *playlists = cJSON_GetObjectItem(json, "playlists");
			if (playlists){
				cJSON *results = cJSON_GetObjectItem(playlists, "results");
				cJSON *playlist;
				for (playlist = results ? results->child : NULL; playlist; playlist = playlist->next){
					playlist_t *p = c_yandex_music_playlist_new_from_json(playlist);
					if (p){
						//fix uris
					ym_replace_image_uri(&p->ogImage, "orig");
						int stop = d->callback ? d->callback(d->user_data, p, NULL, NULL, NULL) : 0;
						c_yandex_music_playlist_free(p);
						if (stop)
							break;
					}
				}
			}

			cJSON_Delete(json);
		}
	}
}

int c_yandex_music_search(
		const char *token,       
		const char *search,    
		const char *image_size,	 // NULL - for original
		void *user_data, 
		int (*callback)
				(void *user_data,
				 playlist_t * playlist,
				 album_t * album,
				 track_t *track,
				 const char *error))
{
	if (!token || !*token || !search || !*search) {
		if (callback) callback(user_data, NULL, NULL, NULL, "Missing token or search text");
		return -1;
	}

	int ret = -1;
	struct c_yandex_music_search_data d =
		{user_data, callback, token, image_size};

	CURL *curl = curl_easy_init();
	if (curl){
		char *search_str = curl_easy_escape(curl, search, strlen(search));
		if (search_str){
			char text[BUFSIZ];
			snprintf(text, sizeof(text), "text=%s", search_str);
			ret =  c_yandex_music_run_method(
					"GET", token, NULL, &d, c_yandex_music_search_cb, 
					"search", text, "page=0", "type=all", "nocorrect=false", NULL);

			curl_free(search_str);
		}
		curl_easy_cleanup(curl);
	}
	return ret;
}

static void c_yandex_music_get_uid_cb(
		void *data, const char *str, const char *error)
{
	(void)error;
	long *puid = data;
	if (str){
		cJSON *json = cJSON_Parse(str);
		if (json){
			cJSON *account = cJSON_GetObjectItem(json, "account");
			if (account){
				cJSON *uid = cJSON_GetObjectItem(account, "uid");
				if (uid && cJSON_IsNumber(uid)){
					*puid = uid->valueint;
				}
			}
			cJSON_Delete(json);
		}
	}
}
	
long c_yandex_music_get_uid(const char *token){
	long uid = 0;
	c_yandex_music_run_method(
					"GET", token, NULL, &uid, c_yandex_music_get_uid_cb, 
					"account/status", NULL);
	return uid;
}

struct c_yandex_music_check_auth_data {
    void *user_data;
    void (*callback)(void *user_data, long uid, const char *error);
};

static void c_yandex_music_check_auth_cb(
        void *data, const char *str, const char *error)
{
    struct c_yandex_music_check_auth_data *d = data;
    long uid = 0;

    if (error) {
        if (d->callback)
            d->callback(d->user_data, 0, error);
        return;
    }

    cJSON *json = str ? cJSON_Parse(str) : NULL;
    if (!json) {
        if (d->callback)
            d->callback(d->user_data, 0, "Invalid account/status response");
        return;
    }

    cJSON *account = cJSON_GetObjectItem(json, "account");
    cJSON *uid_json = account ? cJSON_GetObjectItem(account, "uid") : NULL;
    if (uid_json && cJSON_IsNumber(uid_json))
        uid = (long)uid_json->valueint;

    if (d->callback) {
        if (uid > 0)
            d->callback(d->user_data, uid, NULL);
        else
            d->callback(d->user_data, 0, "Yandex Music account/status returned no UID");
    }

    cJSON_Delete(json);
}

int c_yandex_music_check_auth(
        const char *token,
        void *user_data,
        void (*callback)(void *user_data, long uid, const char *error))
{
    if (!token || !*token) {
        if (callback)
            callback(user_data, 0, "Missing OAuth token");
        return -1;
    }

    struct c_yandex_music_check_auth_data d = { user_data, callback };
    return c_yandex_music_run_method(
        "GET", token, NULL, &d, c_yandex_music_check_auth_cb,
        "account/status", NULL);
}

struct c_yandex_music_get_playlist_tracks_data {
	void *user_data; 
	int (*callback)(void *, track_t *, const char *);
	const char *image_size; 
};
static void c_yandex_music_get_playlist_tracks_cb(
		void *data, const char *str, const char *error)
{
	struct c_yandex_music_get_playlist_tracks_data *d = data;
	
	const char *size = "orig";
	if (d->image_size)
		size = d->image_size;

	if (error) {
		if (d->callback)
			d->callback(d->user_data, NULL, error);
		return;
	}
	if (str){
		cJSON *json = cJSON_Parse(str);
		if (json){
			//d->callback(d->user_data, NULL, cJSON_Print(json));
			//return;
			cJSON *tracks = 
				cJSON_GetObjectItem(json, "tracks");
			if (tracks){
				cJSON *child;
				for (child = tracks->child; child; child = child->next) 
				{
					cJSON *track = 
						cJSON_GetObjectItem(child, "track");
						if (track){
							track_t *p = 
								c_yandex_music_track_new_from_json(track);
							if (p){
								//fix uris
					ym_replace_image_uri(&p->coverUri, size);
					ym_replace_image_uri(&p->ogImage, size);

								if (d->callback)
									if (d->callback(d->user_data, p, NULL))
										return;
							}
						}
					}
				}
		} else {
			if (d->callback){
				char msg[BUFSIZ];
				snprintf(msg, sizeof(msg), "can't parse json from string: %s", str);
				d->callback(d->user_data, NULL, msg);
			}
		}

		cJSON_Delete(json);
	}
}


int c_yandex_music_get_playlist_tracks(
		const char *token,       // authorization token
		const char *image_size,	 // NULL - for original
		long playlist_uid,
		long playlist_kind,
		void *user_data, 
		int (*callback)          // callback for each track
														 // return non-zero to stop function
				(void *user_data,
				 track_t * track,
				 const char *error))
{
	if (!token || !*token || playlist_uid <= 0 || playlist_kind < 0) {
		if (callback) callback(user_data, NULL, "Invalid playlist parameters");
		return -1;
	}

	struct c_yandex_music_get_playlist_tracks_data d =
		{user_data, callback, image_size};
	
	char method[BUFSIZ];
	snprintf(method, sizeof(method), "users/%ld/playlists/%ld", playlist_uid, playlist_kind);
	return c_yandex_music_run_method(
			"GET", token, NULL, &d, c_yandex_music_get_playlist_tracks_cb, method, NULL);

}

struct c_yandex_music_get_track_by_id_data {
	void *user_data; 
	int (*callback)(void *, track_t *, const char *);
	const char *image_size; 
	const char *token;       
};

static void c_yandex_music_get_track_by_id_cb(
		void *data, const char *str, const char *error)
{
	struct c_yandex_music_get_track_by_id_data *d = data;
	
	const char *size = "orig";
	if (d->image_size)
		size = d->image_size;

	if (error) {
		if (d->callback)
			d->callback(d->user_data, NULL, error);
		return;
	}
	if (str){
		cJSON *tracks = cJSON_Parse(str);
		if (tracks){
			cJSON *track = tracks->child;
			if (track){
				track_t *p = 
					c_yandex_music_track_new_from_json(track);
				if (p){
					//fix uris
					ym_replace_image_uri(&p->coverUri, size);
					ym_replace_image_uri(&p->ogImage, size);

					if (d->callback)
						d->callback(d->user_data, p, NULL);
					c_yandex_music_track_free(p);
				}
			}
		} else {
			if (d->callback){
				char msg[BUFSIZ];
				snprintf(msg, sizeof(msg), "can't parse json from string: %s", str);
				d->callback(d->user_data, NULL, msg);
			}
		}
	
			cJSON_Delete(tracks);}
}


int c_yandex_music_get_track_by_id(
		const char *token,       // authorization token
		const char *image_size,	 // NULL - for original
		const char *trackId,
		void *user_data, 
		int (*callback)          // callback for each track
														 // return non-zero to stop function
				(void *user_data,
				 track_t * track,
				 const char *error))
{
	if (!token || !*token || !trackId || !*trackId) {
		if (callback) callback(user_data, NULL, "Missing token or track id");
		return -1;
	}

	struct c_yandex_music_get_track_by_id_data d =
		{user_data, callback, image_size, token};
	
	char method[BUFSIZ];
	snprintf(method, sizeof(method), "tracks/%s", trackId);
	return c_yandex_music_run_method(
			"GET", token, NULL, &d, c_yandex_music_get_track_by_id_cb, method, NULL);
}

struct c_yandex_music_get_favorites_data {
	void *user_data; 
	int (*callback)(void *, track_t *, const char *);
	const char *image_size; 
	const char *token;
};
static void c_yandex_music_get_favorites_cb(
		void *data, const char *str, const char *error)
{
	struct c_yandex_music_get_favorites_data *d = data;

	if (error) {
		if (d->callback)
			d->callback(d->user_data, NULL, error);
		return;
	}
	if (str){
		cJSON *json = cJSON_Parse(str);
		if (json){
			//d->callback(d->user_data, NULL, cJSON_Print(json));
			//return;
			cJSON *library = 
				cJSON_GetObjectItem(json, "library");
			if (library){
				cJSON *tracks = 
					cJSON_GetObjectItem(library, "tracks");
				if (tracks){
					cJSON *child;
					for (child = tracks->child; child; child = child->next) 
					{
						cJSON *id = 
								cJSON_GetObjectItem(child, "id");
						if (cJSON_IsString(id) && id->valuestring && *id->valuestring){
							// get track by id
							c_yandex_music_get_track_by_id(
									d->token, 
									d->image_size, 
									id->valuestring, 
									d->user_data, d->callback);

						}
					}
				}
			}
		} else {
			if (d->callback){
				char msg[BUFSIZ];
				snprintf(msg, sizeof(msg), "can't parse json from string: %s", str);
				d->callback(d->user_data, NULL, msg);
			}
		}

		cJSON_Delete(json);
	}
}


int c_yandex_music_get_favorites(
		const char *token,       // authorization token
		const char *image_size,	 // NULL - for original
		long uid,
		void *user_data, 
		int (*callback)          // callback for each track
														 // return non-zero to stop function
				(void *user_data,
				 track_t * track,
				 const char *error))
{
	if (!token || !*token || uid <= 0) {
		if (callback) callback(user_data, NULL, "Missing token or invalid uid");
		return -1;
	}

	struct c_yandex_music_get_favorites_data d =
		{user_data, callback, image_size, token};
	
	char method[BUFSIZ];
	snprintf(method, sizeof(method), "users/%ld/likes/tracks", uid);
	return c_yandex_music_run_method(
			"GET", token, NULL, &d, c_yandex_music_get_favorites_cb, method, NULL);
}

struct c_yandex_music_post_current_data {
	void *user_data; 
	void (*callback)(void *, const char *);
	const char *token;       
};

static void c_yandex_music_post_current_cb(
		void *data, const char *str, const char *error)
{
	(void)str;
	struct c_yandex_music_post_current_data *d = data;
	
	if (error)
		if (d->callback)
			d->callback(d->user_data, error);
}

char * c_yandex_music_post_current(
		const char *token,       // authorization token
		const char *uuid,
		const char *trackId,
		int track_length_seconds,
		int track_played_seconds,
		long uid,
		void *user_data, 
		void (*callback)         // response and error handler - NULL-able
				(void *user_data,
				 const char *error))
{
	if (!token || !*token || !trackId || !*trackId || uid <= 0) {
		if (callback)
			callback(user_data, "invalid play-audio parameters");
		return NULL;
	}

	char *uuid_str = NULL;
	if (!uuid){
		uuid_str = malloc(37);
		if (!uuid_str){
			if (callback)
				callback(user_data, "can't allocate memory");
			return NULL;
		}
		UUID4_STATE_T state; UUID4_T uuid_;
		uuid4_seed(&state);
		uuid4_gen(&state, &uuid_);
		if (!uuid4_to_s(uuid_, uuid_str, 37)){
			if (callback)
				callback(user_data, "can't generate uuid");
			free(uuid_str);
			return NULL;
		}
		uuid = uuid_str;
	}

	struct c_yandex_music_post_current_data d = 
		{user_data, callback, token};

	time_t t = time(NULL);
	struct tm *tp = gmtime(&t);
	char date[128] = "";
	//strftime(date, 128, "%Y-%m-%dT%H:%M:%SZ", tp);
	snprintf(date, sizeof(date), "%04d-%02d-%02dT%02d%%3A%02d%%3A%02d.000Z", 
			tp->tm_year + 1900, tp->tm_mon + 1, tp->tm_mday,
			tp->tm_hour, tp->tm_min, tp->tm_sec);

			char body[BUFSIZ] = "";
			snprintf(body, sizeof(body),
					"from=cYandexMusic"
					"&uid=%ld"
					"&track-id=%s"
					"&play-id=%s"
					"&track-length-seconds=%d"
					"&total-played-seconds=%d"
					"&client-now=%s"
					"&timestamp=%s",
					uid, trackId, uuid, track_length_seconds, 
					track_played_seconds, date, date);
		
		if (c_yandex_music_run_method(
					"POST", token, body, &d, 
					c_yandex_music_post_current_cb, "play-audio", NULL))
		{
			if (uuid_str)
				free(uuid_str);
			return NULL;
		}
		return uuid_str;
}
	
struct c_yandex_music_get_album_tracks_data {
	void *user_data; 
	int (*callback)(void *, track_t *, const char *);
	const char *image_size; 
};
static void c_yandex_music_get_album_tracks_cb(
		void *data, const char *str, const char *error)
{
	struct c_yandex_music_get_album_tracks_data *d = data;
	
	const char *size = "orig";
	if (d->image_size)
		size = d->image_size;

	if (error) {
		if (d->callback)
			d->callback(d->user_data, NULL, error);
		return;
	}
	if (str){
		cJSON *json = cJSON_Parse(str);
		if (json){
			//d->callback(d->user_data, NULL, cJSON_Print(json));
			//return;
			cJSON *volumes = cJSON_GetObjectItem(json, "volumes");
			if (volumes){
				cJSON *volume;
				for (volume = volumes->child;
						 volume;
						 volume = volume->next)
				{
					cJSON *track;
					for (track = volume->child;
							track;
							track = track->next)
					{
								track_t *p = 
									c_yandex_music_track_new_from_json(track);
								if (p){
									//fix uris
					ym_replace_image_uri(&p->coverUri, size);
					ym_replace_image_uri(&p->ogImage, size);

									if (d->callback)
										d->callback(d->user_data, p, NULL);
					c_yandex_music_track_free(p);
								}
							}
						}
			}
		}
	
			cJSON_Delete(json);}
}
	
int c_yandex_music_get_album_tracks(
		const char *token,       // authorization token
		const char *image_size,	 // NULL - for original
		long album_id,
		void *user_data, 
		int (*callback)          // callback for each track
														 // return non-zero to stop function
				(void *user_data,
				 track_t * track,
				 const char *error))
{
	if (!token || !*token || album_id <= 0) {
		if (callback) callback(user_data, NULL, "Missing token or invalid album id");
		return -1;
	}

	struct c_yandex_music_get_album_tracks_data d =
			{user_data, callback, image_size};
	
	char method[BUFSIZ];
	snprintf(method, sizeof(method), "albums/%ld/with-tracks", album_id);
	return c_yandex_music_run_method(
			"GET", token, NULL, &d, c_yandex_music_get_album_tracks_cb, method, NULL);
}

struct c_yandex_music_get_user_playlists_data {
	void *user_data; 
	int (*callback)(void *, playlist_t *, const char *);
	const char *image_size; 
};
static void c_yandex_music_get_user_playlists_cb(
		void *data, const char *str, const char *error)
{
	struct c_yandex_music_get_user_playlists_data *d = data;

	if (error) {
		if (d->callback)
			d->callback(d->user_data, NULL, error);
		return;
	}
	if (str){
		cJSON *json = cJSON_Parse(str);
		if (json){
			//d->callback(d->user_data, NULL, cJSON_Print(json));
			//return;
			cJSON *playlist;
			for (playlist=json->child; playlist; playlist = playlist->next){
				playlist_t *p = c_yandex_music_playlist_new_from_json(playlist);
				if (p){
					//fix uris
					ym_replace_image_uri(&p->ogImage, d->image_size ? d->image_size : "orig");
					int stop = d->callback ? d->callback(d->user_data, p, NULL) : 0;
					c_yandex_music_playlist_free(p);
					if (stop)
						break;
				}
			}
		}
	
			cJSON_Delete(json);}
}

int c_yandex_music_get_user_playlists(
		const char *token,       // authorization token
		const char *image_size,	 // NULL - for original
		long uid,                // user id
		void *user_data, 
		int (*callback)          // callback for each track
														 // return non-zero to stop function
				(void *user_data,
				 playlist_t * playlist,
				 const char *error))
{
	if (!token || !*token || uid <= 0) {
		if (callback) callback(user_data, NULL, "Missing token or invalid uid");
		return -1;
	}

	struct c_yandex_music_get_user_playlists_data d =
			{user_data, callback, image_size};
	
	char method[BUFSIZ];
	snprintf(method, sizeof(method), "users/%ld/playlists/list", uid);
	return c_yandex_music_run_method(
			"GET", token, NULL, &d, c_yandex_music_get_user_playlists_cb, method, NULL);
}

struct c_yandex_music_remove_playlist_data {
	void *user_data;
	void (*callback)(void *, const char *);
};

static void c_yandex_music_remove_playlist_cb(
		void *data, const char *str, const char *error)
{
	(void)str;
	struct c_yandex_music_remove_playlist_data *d = data;
	
	if (error)
		if (d->callback)
			d->callback(d->user_data, error);
}

int c_yandex_music_remove_playlist(
		const char *token,       // authorization token
		long playlist_uid,
		long playlist_kind,
		void *user_data, 
		void (*callback)          
				(void *user_data,
				 const char *error))
{
	if (!token || !*token || playlist_uid <= 0 || playlist_kind < 0) {
		if (callback) callback(user_data, "Invalid remove-playlist parameters");
		return -1;
	}

struct c_yandex_music_remove_playlist_data d =
		{user_data, callback};
	
	char method[BUFSIZ];
	snprintf(method, sizeof(method), "users/%ld/playlists/%ld/delete", playlist_uid, playlist_kind);
	return c_yandex_music_run_method(
			"POST", token, NULL, &d, c_yandex_music_remove_playlist_cb, method, NULL);
}

struct c_yandex_music_like_current_data {
	void *user_data; 
	void (*callback)(void *, const char *);
	const char *token;       
};

static void c_yandex_music_like_current_cb(
		void *data, const char *str, const char *error)
{
	(void)str;
	struct c_yandex_music_like_current_data *d = data;
	
	if (error)
		if (d->callback)
			d->callback(d->user_data, error);
}

int c_yandex_music_set_like_current(
		const char *token,       // authorization token
		long uid,
		const char *trackId,
		void *user_data, 
		void (*callback)         // response and error handler - NULL-able
				(void *user_data,
				 const char *error))
{
	if (!token || !*token || uid <= 0 || !trackId || !*trackId) {
		if (callback) callback(user_data, "Invalid like parameters");
		return -1;
	}

	struct c_yandex_music_like_current_data d = 
		{user_data, callback, token};
	
	char method[BUFSIZ] = "";
	snprintf(method, sizeof(method), "users/%ld/likes/tracks/add-multiple", uid);
	
	char body[BUFSIZ] = "";
	snprintf(body, sizeof(body), "track-ids=%s", trackId);
	//sprintf(body, "{'track-ids': [%s]}", trackId);
	
	return c_yandex_music_run_method(
			"POST", token, body, &d, c_yandex_music_like_current_cb, method, NULL);
}
	
int c_yandex_music_set_unlike_current(
		const char *token,       // authorization token
		long uid,
		const char *trackId,
		void *user_data, 
		void (*callback)         // response and error handler - NULL-able
				(void *user_data,
				 const char *error))
{
	if (!token || !*token || uid <= 0 || !trackId || !*trackId) {
		if (callback) callback(user_data, "Invalid unlike parameters");
		return -1;
	}

	struct c_yandex_music_like_current_data d = 
		{user_data, callback, token};
	
	char method[BUFSIZ] = "";
	snprintf(method, sizeof(method), "users/%ld/likes/tracks/remove", uid);
	
	char body[BUFSIZ] = "";
	snprintf(body, sizeof(body), "track-ids=%s", trackId);
	//sprintf(body, "{'track-ids': [%s]}", trackId);
	
	return c_yandex_music_run_method(
			"POST", token, body, &d, c_yandex_music_like_current_cb, method, NULL);
}
	

struct c_yandex_music_create_playlist_data {
	void *user_data; 
	void (*callback)(void *, const char *);
	const char *token;       
	playlist_t **p;
};

static void c_yandex_music_create_playlist_cb(
		void *data, const char *str, const char *error)
{
	(void)str;
	struct c_yandex_music_create_playlist_data *d = data;
	
	if (error) {
		if (d->callback)
			d->callback(d->user_data, error);
		return;
	}
	
	if (str){
		cJSON *json = cJSON_Parse(str);
		if (json){
			//d->callback(d->user_data, cJSON_Print(json));
			//return;
			playlist_t *p = 
					c_yandex_music_playlist_new_from_json(json);
			if (p){
				// fix image
				ym_replace_image_uri(&p->ogImage, "orig");
				d->p[0] = p;
			}
		}
	
			cJSON_Delete(json);}
}

playlist_t * c_yandex_music_create_playlist(
		const char *token,       // authorization token
		long uid,                // user id
		const char *title,
		void *user_data, 
		void (*callback)         // response and error handler - NULL-able
				(void *user_data,
				 const char *error))
{
	if (!token || !*token || uid <= 0 || !title || !*title) {
		if (callback) callback(user_data, "Invalid create-playlist parameters");
		return NULL;
	}

	playlist_t *p = NULL;
	struct c_yandex_music_create_playlist_data d = 
		{user_data, callback, token, &p};
	
	char method[BUFSIZ] = "";
	snprintf(method, sizeof(method), "users/%ld/playlists/create", uid);
	
	CURL *curl = curl_easy_init();
	if (curl){
		char *title_str = curl_easy_escape(curl, title, strlen(title));
		if (title_str){
			char body[BUFSIZ];
			snprintf(body, sizeof(body), "title=%s&visibility=public", title_str);
			c_yandex_music_run_method(
					"POST", token, body, &d, c_yandex_music_create_playlist_cb, 
					method, NULL);

			curl_free(title_str);
		}
		curl_easy_cleanup(curl);
	}
	return p;
}

struct c_yandex_music_playlist_add_tracks_data {
	void *user_data; 
	void (*callback)(void *, const char *);
	const char *token;       
};

static void c_yandex_music_playlist_add_tracks_cb(
		void *data, const char *str, const char *error)
{
	(void)str;
	struct c_yandex_music_playlist_add_tracks_data *d = data;
	
	if (error)
		if (d->callback)
			d->callback(d->user_data, error);
}

struct c_yandex_music_playlist_revision_data {
    int revision;
    const char *error;
};

static void c_yandex_music_playlist_revision_cb(
        void *data, const char *str, const char *error)
{
    struct c_yandex_music_playlist_revision_data *d = data;
    d->revision = 0;
    d->error = error;

    if (!str || error)
        return;

    cJSON *json = cJSON_Parse(str);
    if (!json)
        return;

    cJSON *revision = cJSON_GetObjectItem(json, "revision");
    if (cJSON_IsNumber(revision))
        d->revision = revision->valueint;

    cJSON_Delete(json);
}

int c_yandex_music_playlist_add_tracks(
        const char *token,
        long uid,
        long kind,
        long *track_ids,
        long *album_ids,
        int count,
        void *user_data,
        void (*callback)(void *user_data, const char *error))
{
    (void)album_ids;

    if (!token || !*token || uid <= 0 || kind < 0 ||
        !track_ids || count <= 0) {
        if (callback) callback(user_data, "Invalid playlist track list");
        return -1;
    }

    /* The current API requires the playlist's current revision. */
    struct c_yandex_music_playlist_revision_data revision_data = {0, NULL};
    char playlist_method[BUFSIZ];
    snprintf(playlist_method, sizeof(playlist_method),
             "users/%ld/playlists/%ld", uid, kind);

    int ret = c_yandex_music_run_method(
        "GET", token, NULL,
        &revision_data,
        c_yandex_music_playlist_revision_cb,
        playlist_method, NULL);

    if (ret != 0 || revision_data.error) {
        if (callback) callback(user_data,
            revision_data.error ? revision_data.error : "Unable to read playlist revision");
        return -1;
    }

    cJSON *diff = cJSON_CreateArray();
    if (!diff) {
        if (callback) callback(user_data, "Unable to allocate playlist diff");
        return -1;
    }

    cJSON *operation = cJSON_CreateObject();
    cJSON *tracks = cJSON_CreateArray();
    if (!operation || !tracks) {
        if (operation) cJSON_Delete(operation);
        if (tracks) cJSON_Delete(tracks);
        cJSON_Delete(diff);
        if (callback) callback(user_data, "Unable to allocate playlist JSON");
        return -1;
    }

    cJSON_AddStringToObject(operation, "op", "insert");
    cJSON_AddNumberToObject(operation, "at", 0);
    cJSON_AddItemToObject(operation, "tracks", tracks);
    cJSON_AddItemToArray(diff, operation);

    for (int i = 0; i < count; ++i) {
        char id[64];
        snprintf(id, sizeof(id), "%ld", track_ids[i]);

        cJSON *track = cJSON_CreateObject();
        if (!track) {
            cJSON_Delete(diff);
            if (callback) callback(user_data, "Unable to allocate playlist track JSON");
            return -1;
        }

        cJSON_AddStringToObject(track, "id", id);
        cJSON_AddItemToArray(tracks, track);
    }

    char *diff_json = cJSON_PrintUnformatted(diff);
    cJSON_Delete(diff);
    if (!diff_json) {
        if (callback) callback(user_data, "Unable to serialize playlist diff");
        return -1;
    }

    CURL *curl = curl_easy_init();
    if (!curl) {
        free(diff_json);
        if (callback) callback(user_data, "curl_easy_init failed");
        return -1;
    }

    char *encoded = curl_easy_escape(curl, diff_json, 0);
    free(diff_json);
    if (!encoded) {
        curl_easy_cleanup(curl);
        if (callback) callback(user_data, "Unable to encode playlist diff");
        return -1;
    }

    size_t body_len = strlen("diff=") + strlen(encoded) +
                      strlen("&revision=") + 32 + 1;
    char *body = malloc(body_len);
    if (!body) {
        curl_free(encoded);
        curl_easy_cleanup(curl);
        if (callback) callback(user_data, "Unable to allocate playlist body");
        return -1;
    }

    snprintf(body, body_len,
             "diff=%s&revision=%d",
             encoded, revision_data.revision);

    curl_free(encoded);
    curl_easy_cleanup(curl);

    struct c_yandex_music_playlist_add_tracks_data d =
        {user_data, callback, token};

    char method[BUFSIZ];
    snprintf(method, sizeof(method),
             "users/%ld/playlists/%ld/change-relative", uid, kind);

    ret = c_yandex_music_run_method(
        "POST", token, body, &d,
        c_yandex_music_playlist_add_tracks_cb,
        method, NULL);

    free(body);
    return ret;
}
