#ifndef MIKAN_LIBTORRENT_H_
#define MIKAN_LIBTORRENT_H_

#ifdef _WIN32
#ifdef MIKAN_LIBTORRENT_BUILDING
#define MIKAN_LT_API __declspec(dllexport)
#else
#define MIKAN_LT_API __declspec(dllimport)
#endif
#else
#define MIKAN_LT_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef void* mikan_lt_session_t;

MIKAN_LT_API const char* mikan_lt_version(void);

MIKAN_LT_API mikan_lt_session_t mikan_lt_session_create(
    const char* listen_interfaces,
    int download_limit_bytes_per_sec,
    int upload_limit_bytes_per_sec,
    char* error,
    int error_len);

MIKAN_LT_API void mikan_lt_session_destroy(mikan_lt_session_t session);

#ifdef __cplusplus
}
#endif

#endif  // MIKAN_LIBTORRENT_H_
