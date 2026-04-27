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

typedef struct mikan_lt_torrent_stats {
    int torrent_id;
    int state;
    int is_paused;
    int has_metadata;
    int progress_milli;
    long long total_wanted;
    long long total_done;
    int download_rate;
    int upload_rate;
    int num_peers;
    int num_seeds;
} mikan_lt_torrent_stats_t;

MIKAN_LT_API const char* mikan_lt_version(void);

MIKAN_LT_API mikan_lt_session_t mikan_lt_session_create(
    const char* listen_interfaces,
    int download_limit_bytes_per_sec,
    int upload_limit_bytes_per_sec,
    char* error,
    int error_len);

MIKAN_LT_API void mikan_lt_session_destroy(mikan_lt_session_t session);

MIKAN_LT_API int mikan_lt_add_magnet(
    mikan_lt_session_t session,
    const char* magnet_uri,
    const char* save_path,
    char* error,
    int error_len);

MIKAN_LT_API int mikan_lt_add_magnet_ex(
    mikan_lt_session_t session,
    const char* magnet_uri,
    const char* save_path,
    const char* resume_path,
    int seed_mode,
    char* error,
    int error_len);

MIKAN_LT_API int mikan_lt_save_resume_data(
    mikan_lt_session_t session,
    int torrent_id,
    const char* resume_path,
    char* error,
    int error_len);

MIKAN_LT_API int mikan_lt_wait_metadata(
    mikan_lt_session_t session,
    int torrent_id,
    int timeout_ms,
    char* error,
    int error_len);

MIKAN_LT_API int mikan_lt_get_files_count(
    mikan_lt_session_t session,
    int torrent_id,
    char* error,
    int error_len);

MIKAN_LT_API int mikan_lt_get_file_info(
    mikan_lt_session_t session,
    int torrent_id,
    int file_index,
    char* name,
    int name_len,
    long long* size,
    int* is_streamable,
    char* error,
    int error_len);

MIKAN_LT_API int mikan_lt_set_file_priorities(
    mikan_lt_session_t session,
    int torrent_id,
    const int* priorities,
    int priorities_len,
    char* error,
    int error_len);

MIKAN_LT_API int mikan_lt_pause_torrent(
    mikan_lt_session_t session,
    int torrent_id,
    char* error,
    int error_len);

MIKAN_LT_API int mikan_lt_resume_torrent(
    mikan_lt_session_t session,
    int torrent_id,
    char* error,
    int error_len);

MIKAN_LT_API int mikan_lt_remove_torrent(
    mikan_lt_session_t session,
    int torrent_id,
    int delete_files,
    char* error,
    int error_len);

MIKAN_LT_API int mikan_lt_get_torrent_stats_count(
    mikan_lt_session_t session,
    char* error,
    int error_len);

MIKAN_LT_API int mikan_lt_get_torrent_stats_item(
    mikan_lt_session_t session,
    int index,
    mikan_lt_torrent_stats_t* out_stats,
    char* out_name,
    int out_name_len,
    char* out_info_hash,
    int out_info_hash_len,
    char* out_error_msg,
    int out_error_msg_len,
    char* error,
    int error_len);

MIKAN_LT_API int mikan_lt_configure_session(
    mikan_lt_session_t session,
    int download_limit_bytes_per_sec,
    int upload_limit_bytes_per_sec,
    int connections_limit,
    int enable_dht,
    int enable_lsd,
    int enable_upnp,
    int enable_natpmp,
    int alert_queue_size,
    char* error,
    int error_len);

MIKAN_LT_API int mikan_lt_start_stream(
    mikan_lt_session_t session,
    int torrent_id,
    int file_index,
    int max_cache_bytes,
    char* out_url,
    int out_url_len,
    char* error,
    int error_len);

MIKAN_LT_API int mikan_lt_stop_stream(
    mikan_lt_session_t session,
    int stream_id,
    char* error,
    int error_len);

MIKAN_LT_API int mikan_lt_set_stream_cache(
    mikan_lt_session_t session,
    int stream_id,
    int capacity,
    int read_ahead_pct,
    int connections_limit,
    char* error,
    int error_len);

MIKAN_LT_API int mikan_lt_preload_stream(
    mikan_lt_session_t session,
    int stream_id,
    long long preload_bytes,
    char* error,
    int error_len);

#ifdef __cplusplus
}
#endif

#endif  // MIKAN_LIBTORRENT_H_
