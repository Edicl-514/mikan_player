#include "mikan_libtorrent.h"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <mutex>
#include <memory>
#include <string>
#include <thread>
#include <unordered_map>
#include <utility>
#include <vector>

#include <libtorrent/download_priority.hpp>
#include <libtorrent/hex.hpp>
#include <libtorrent/magnet_uri.hpp>
#include <libtorrent/session.hpp>
#include <libtorrent/settings_pack.hpp>
#include <libtorrent/torrent_flags.hpp>
#include <libtorrent/torrent_handle.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/version.hpp>

namespace {

namespace lt = libtorrent;

struct MikanSession {
  explicit MikanSession(lt::settings_pack settings) : session(std::move(settings)) {}

  std::mutex mutex;
  lt::session session;
  int next_torrent_id = 1;
  std::unordered_map<int, lt::torrent_handle> torrents;
};

void write_error(char* error, int error_len, const std::string& message) {
  if (error == nullptr || error_len <= 0) {
    return;
  }
  const auto size = std::min<int>(static_cast<int>(message.size()), error_len - 1);
  if (size > 0) {
    std::memcpy(error, message.data(), static_cast<size_t>(size));
  }
  error[size] = '\0';
}

void clear_error(char* error, int error_len) {
  write_error(error, error_len, "");
}

void write_output(char* out, int out_len, const std::string& value) {
  if (out == nullptr || out_len <= 0) {
    return;
  }
  const auto size = std::min<int>(static_cast<int>(value.size()), out_len - 1);
  if (size > 0) {
    std::memcpy(out, value.data(), static_cast<size_t>(size));
  }
  out[size] = '\0';
}

std::string to_lower(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
    return static_cast<char>(std::tolower(c));
  });
  return value;
}

std::string hash_to_string(const lt::torrent_handle& handle) {
  const auto hashes = handle.info_hashes();
  const auto best = hashes.get_best();
  return lt::aux::to_hex(best.to_string());
}

bool is_streamable_file(const std::string& path) {
  const auto lower = to_lower(path);
  const auto dot_pos = lower.find_last_of('.');
  if (dot_pos == std::string::npos) {
    return false;
  }
  const std::string ext = lower.substr(dot_pos + 1);
  static const char* kVideoExts[] = {
      "mkv", "mp4", "avi", "mov", "wmv", "flv", "m4v", "ts", "webm", "mpg", "mpeg", "m2ts", "3gp", "vob"};
  return std::find(std::begin(kVideoExts), std::end(kVideoExts), ext) != std::end(kVideoExts);
}

MikanSession* as_session(mikan_lt_session_t session, char* error, int error_len) {
  auto* ptr = static_cast<MikanSession*>(session);
  if (ptr == nullptr) {
    write_error(error, error_len, "session is null");
    return nullptr;
  }
  return ptr;
}

lt::torrent_handle find_torrent_handle(MikanSession* session, int torrent_id, char* error, int error_len) {
  const auto it = session->torrents.find(torrent_id);
  if (it == session->torrents.end() || !it->second.is_valid()) {
    write_error(error, error_len, "torrent id not found");
    return lt::torrent_handle();
  }
  return it->second;
}

std::vector<std::pair<int, lt::torrent_handle>> collect_valid_torrents(MikanSession* session) {
  std::vector<std::pair<int, lt::torrent_handle>> items;
  items.reserve(session->torrents.size());
  for (const auto& kv : session->torrents) {
    if (kv.second.is_valid()) {
      items.emplace_back(kv.first, kv.second);
    }
  }
  std::sort(items.begin(), items.end(), [](const auto& lhs, const auto& rhs) {
    return lhs.first < rhs.first;
  });
  return items;
}

lt::settings_pack make_settings(
    const char* listen_interfaces,
    int download_limit_bytes_per_sec,
    int upload_limit_bytes_per_sec) {
  lt::settings_pack settings;

  const char* interfaces =
      (listen_interfaces != nullptr && listen_interfaces[0] != '\0')
          ? listen_interfaces
          : "0.0.0.0:6881";

  settings.set_str(lt::settings_pack::listen_interfaces, interfaces);
  settings.set_bool(lt::settings_pack::enable_dht, true);
  settings.set_bool(lt::settings_pack::enable_lsd, true);
  settings.set_bool(lt::settings_pack::enable_upnp, true);
  settings.set_bool(lt::settings_pack::enable_natpmp, true);
  settings.set_bool(lt::settings_pack::announce_to_all_trackers, true);
  settings.set_bool(lt::settings_pack::announce_to_all_tiers, true);
  settings.set_int(lt::settings_pack::alert_queue_size, 10000);

  if (download_limit_bytes_per_sec > 0) {
    settings.set_int(
        lt::settings_pack::download_rate_limit,
        download_limit_bytes_per_sec);
  }
  if (upload_limit_bytes_per_sec > 0) {
    settings.set_int(
        lt::settings_pack::upload_rate_limit,
        upload_limit_bytes_per_sec);
  }

  return settings;
}

}  // namespace

extern "C" {

const char* mikan_lt_version(void) {
  return LIBTORRENT_VERSION;
}

mikan_lt_session_t mikan_lt_session_create(
    const char* listen_interfaces,
    int download_limit_bytes_per_sec,
    int upload_limit_bytes_per_sec,
    char* error,
    int error_len) {
  try {
    auto settings = make_settings(
        listen_interfaces,
        download_limit_bytes_per_sec,
        upload_limit_bytes_per_sec);
    auto session = std::make_unique<MikanSession>(std::move(settings));
    write_error(error, error_len, "");
    return session.release();
  } catch (const std::exception& e) {
    write_error(error, error_len, e.what());
  } catch (...) {
    write_error(error, error_len, "unknown error");
  }
  return nullptr;
}

void mikan_lt_session_destroy(mikan_lt_session_t session) {
  delete static_cast<MikanSession*>(session);
}

int mikan_lt_add_magnet(
    mikan_lt_session_t session,
    const char* magnet_uri,
    const char* save_path,
    char* error,
    int error_len) {
  try {
    auto* s = as_session(session, error, error_len);
    if (s == nullptr) {
      return -1;
    }
    if (magnet_uri == nullptr || magnet_uri[0] == '\0') {
      write_error(error, error_len, "magnet uri is empty");
      return -1;
    }

    lt::error_code ec;
    auto params = lt::parse_magnet_uri(magnet_uri, ec);
    if (ec) {
      write_error(error, error_len, ec.message());
      return -1;
    }
    if (save_path != nullptr && save_path[0] != '\0') {
      params.save_path = save_path;
    }
    // Do NOT set auto_managed — it causes the torrent to be queued by
    // libtorrent's internal scheduler instead of starting immediately.
    // We manage start/stop explicitly via pause/resume calls.

    std::scoped_lock lock(s->mutex);
    auto handle = s->session.add_torrent(std::move(params), ec);
    if (ec || !handle.is_valid()) {
      write_error(error, error_len, ec ? ec.message() : "failed to add magnet");
      return -1;
    }
    const int torrent_id = s->next_torrent_id++;
    s->torrents[torrent_id] = handle;
    clear_error(error, error_len);
    return torrent_id;
  } catch (const std::exception& e) {
    write_error(error, error_len, e.what());
  } catch (...) {
    write_error(error, error_len, "unknown error");
  }
  return -1;
}

int mikan_lt_wait_metadata(
    mikan_lt_session_t session,
    int torrent_id,
    int timeout_ms,
    char* error,
    int error_len) {
  try {
    auto* s = as_session(session, error, error_len);
    if (s == nullptr) {
      return 0;
    }
    if (timeout_ms <= 0) {
      timeout_ms = 90000;
    }

    auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(timeout_ms);
    while (std::chrono::steady_clock::now() < deadline) {
      lt::torrent_handle handle;
      {
        std::scoped_lock lock(s->mutex);
        handle = find_torrent_handle(s, torrent_id, error, error_len);
      }
      if (!handle.is_valid()) {
        return 0;
      }

      auto st = handle.status();
      if (st.has_metadata) {
        clear_error(error, error_len);
        return 1;
      }
      if (st.errc) {
        write_error(error, error_len, st.errc.message());
        return 0;
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(120));
    }

    write_error(error, error_len, "timed out waiting for metadata");
  } catch (const std::exception& e) {
    write_error(error, error_len, e.what());
  } catch (...) {
    write_error(error, error_len, "unknown error");
  }
  return 0;
}

int mikan_lt_get_files_count(
    mikan_lt_session_t session,
    int torrent_id,
    char* error,
    int error_len) {
  try {
    auto* s = as_session(session, error, error_len);
    if (s == nullptr) {
      return -1;
    }
    lt::torrent_handle handle;
    {
      std::scoped_lock lock(s->mutex);
      handle = find_torrent_handle(s, torrent_id, error, error_len);
    }
    if (!handle.is_valid()) {
      return -1;
    }

    auto ti = handle.torrent_file();
    if (!ti) {
      write_error(error, error_len, "torrent metadata not available");
      return -1;
    }

    clear_error(error, error_len);
    return ti->files().num_files();
  } catch (const std::exception& e) {
    write_error(error, error_len, e.what());
  } catch (...) {
    write_error(error, error_len, "unknown error");
  }
  return -1;
}

int mikan_lt_get_file_info(
    mikan_lt_session_t session,
    int torrent_id,
    int file_index,
    char* name,
    int name_len,
    long long* size,
    int* is_streamable,
    char* error,
    int error_len) {
  try {
    auto* s = as_session(session, error, error_len);
    if (s == nullptr) {
      return 0;
    }
    lt::torrent_handle handle;
    {
      std::scoped_lock lock(s->mutex);
      handle = find_torrent_handle(s, torrent_id, error, error_len);
    }
    if (!handle.is_valid()) {
      return 0;
    }

    auto ti = handle.torrent_file();
    if (!ti) {
      write_error(error, error_len, "torrent metadata not available");
      return 0;
    }

    const auto& fs = ti->files();
    if (file_index < 0 || file_index >= fs.num_files()) {
      write_error(error, error_len, "file index out of range");
      return 0;
    }

    const auto idx = lt::file_index_t{file_index};
    const std::string path = fs.file_path(idx);
    write_output(name, name_len, path);
    if (size != nullptr) {
      *size = static_cast<long long>(fs.file_size(idx));
    }
    if (is_streamable != nullptr) {
      *is_streamable = is_streamable_file(path) ? 1 : 0;
    }
    clear_error(error, error_len);
    return 1;
  } catch (const std::exception& e) {
    write_error(error, error_len, e.what());
  } catch (...) {
    write_error(error, error_len, "unknown error");
  }
  return 0;
}

int mikan_lt_set_file_priorities(
    mikan_lt_session_t session,
    int torrent_id,
    const int* priorities,
    int priorities_len,
    char* error,
    int error_len) {
  try {
    auto* s = as_session(session, error, error_len);
    if (s == nullptr) {
      return 0;
    }
    if (priorities == nullptr || priorities_len <= 0) {
      write_error(error, error_len, "priorities is empty");
      return 0;
    }

    lt::torrent_handle handle;
    {
      std::scoped_lock lock(s->mutex);
      handle = find_torrent_handle(s, torrent_id, error, error_len);
    }
    if (!handle.is_valid()) {
      return 0;
    }

    std::vector<lt::download_priority_t> values;
    values.reserve(static_cast<size_t>(priorities_len));
    for (int i = 0; i < priorities_len; ++i) {
      const int clamped = std::clamp(priorities[i], 0, 7);
      values.push_back(lt::download_priority_t{static_cast<std::uint8_t>(clamped)});
    }

    handle.prioritize_files(values);
    clear_error(error, error_len);
    return 1;
  } catch (const std::exception& e) {
    write_error(error, error_len, e.what());
  } catch (...) {
    write_error(error, error_len, "unknown error");
  }
  return 0;
}

int mikan_lt_pause_torrent(
    mikan_lt_session_t session,
    int torrent_id,
    char* error,
    int error_len) {
  try {
    auto* s = as_session(session, error, error_len);
    if (s == nullptr) {
      return 0;
    }
    lt::torrent_handle handle;
    {
      std::scoped_lock lock(s->mutex);
      handle = find_torrent_handle(s, torrent_id, error, error_len);
    }
    if (!handle.is_valid()) {
      return 0;
    }

    handle.pause();
    clear_error(error, error_len);
    return 1;
  } catch (const std::exception& e) {
    write_error(error, error_len, e.what());
  } catch (...) {
    write_error(error, error_len, "unknown error");
  }
  return 0;
}

int mikan_lt_resume_torrent(
    mikan_lt_session_t session,
    int torrent_id,
    char* error,
    int error_len) {
  try {
    auto* s = as_session(session, error, error_len);
    if (s == nullptr) {
      return 0;
    }
    lt::torrent_handle handle;
    {
      std::scoped_lock lock(s->mutex);
      handle = find_torrent_handle(s, torrent_id, error, error_len);
    }
    if (!handle.is_valid()) {
      return 0;
    }

    handle.resume();
    clear_error(error, error_len);
    return 1;
  } catch (const std::exception& e) {
    write_error(error, error_len, e.what());
  } catch (...) {
    write_error(error, error_len, "unknown error");
  }
  return 0;
}

int mikan_lt_remove_torrent(
    mikan_lt_session_t session,
    int torrent_id,
    int delete_files,
    char* error,
    int error_len) {
  try {
    auto* s = as_session(session, error, error_len);
    if (s == nullptr) {
      return 0;
    }
    lt::torrent_handle handle;
    {
      std::scoped_lock lock(s->mutex);
      handle = find_torrent_handle(s, torrent_id, error, error_len);
      if (!handle.is_valid()) {
        return 0;
      }
      if (delete_files != 0) {
        s->session.remove_torrent(handle, lt::session_handle::delete_files);
      } else {
        s->session.remove_torrent(handle);
      }
      s->torrents.erase(torrent_id);
    }
    clear_error(error, error_len);
    return 1;
  } catch (const std::exception& e) {
    write_error(error, error_len, e.what());
  } catch (...) {
    write_error(error, error_len, "unknown error");
  }
  return 0;
}

int mikan_lt_get_torrent_stats_count(
    mikan_lt_session_t session,
    char* error,
    int error_len) {
  try {
    auto* s = as_session(session, error, error_len);
    if (s == nullptr) {
      return -1;
    }

    std::scoped_lock lock(s->mutex);
    const auto items = collect_valid_torrents(s);
    clear_error(error, error_len);
    return static_cast<int>(items.size());
  } catch (const std::exception& e) {
    write_error(error, error_len, e.what());
  } catch (...) {
    write_error(error, error_len, "unknown error");
  }
  return -1;
}

int mikan_lt_get_torrent_stats_item(
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
    int error_len) {
  try {
    auto* s = as_session(session, error, error_len);
    if (s == nullptr) {
      return 0;
    }
    if (out_stats == nullptr) {
      write_error(error, error_len, "out_stats is null");
      return 0;
    }

    lt::torrent_handle handle;
    int torrent_id = -1;
    {
      std::scoped_lock lock(s->mutex);
      const auto items = collect_valid_torrents(s);
      if (index < 0 || index >= static_cast<int>(items.size())) {
        write_error(error, error_len, "stats index out of range");
        return 0;
      }
      torrent_id = items[static_cast<size_t>(index)].first;
      handle = items[static_cast<size_t>(index)].second;
    }

    if (!handle.is_valid()) {
      write_error(error, error_len, "torrent handle is invalid");
      return 0;
    }

    const auto flags = lt::torrent_handle::query_name
        | lt::torrent_handle::query_save_path
        | lt::torrent_handle::query_accurate_download_counters;
    const auto st = handle.status(flags);

    out_stats->torrent_id = torrent_id;
    out_stats->state = static_cast<int>(st.state);
    out_stats->is_paused = st.flags & lt::torrent_flags::paused ? 1 : 0;
    out_stats->has_metadata = st.has_metadata ? 1 : 0;
    out_stats->progress_milli = static_cast<int>(std::clamp(st.progress, 0.0f, 1.0f) * 100000.0f + 0.5f);
    out_stats->total_wanted = static_cast<long long>(st.total_wanted);
    out_stats->total_done = static_cast<long long>(st.total_done);
    out_stats->download_rate = st.download_rate;
    out_stats->upload_rate = st.upload_rate;
    out_stats->num_peers = st.num_peers;
    out_stats->num_seeds = st.num_seeds;

    write_output(out_name, out_name_len, st.name);
    write_output(out_info_hash, out_info_hash_len, hash_to_string(handle));
    write_output(out_error_msg, out_error_msg_len, st.errc ? st.errc.message() : "");
    clear_error(error, error_len);
    return 1;
  } catch (const std::exception& e) {
    write_error(error, error_len, e.what());
  } catch (...) {
    write_error(error, error_len, "unknown error");
  }
  return 0;
}

int mikan_lt_configure_session(
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
    int error_len) {
  try {
    auto* s = as_session(session, error, error_len);
    if (s == nullptr) {
      return 0;
    }

    lt::settings_pack settings;
    if (download_limit_bytes_per_sec >= 0) {
      settings.set_int(lt::settings_pack::download_rate_limit, download_limit_bytes_per_sec);
    }
    if (upload_limit_bytes_per_sec >= 0) {
      settings.set_int(lt::settings_pack::upload_rate_limit, upload_limit_bytes_per_sec);
    }
    if (connections_limit > 0) {
      settings.set_int(lt::settings_pack::connections_limit, connections_limit);
    }
    if (enable_dht >= 0) {
      settings.set_bool(lt::settings_pack::enable_dht, enable_dht != 0);
    }
    if (enable_lsd >= 0) {
      settings.set_bool(lt::settings_pack::enable_lsd, enable_lsd != 0);
    }
    if (enable_upnp >= 0) {
      settings.set_bool(lt::settings_pack::enable_upnp, enable_upnp != 0);
    }
    if (enable_natpmp >= 0) {
      settings.set_bool(lt::settings_pack::enable_natpmp, enable_natpmp != 0);
    }
    if (alert_queue_size > 0) {
      settings.set_int(lt::settings_pack::alert_queue_size, alert_queue_size);
    }

    std::scoped_lock lock(s->mutex);
    s->session.apply_settings(settings);
    clear_error(error, error_len);
    return 1;
  } catch (const std::exception& e) {
    write_error(error, error_len, e.what());
  } catch (...) {
    write_error(error, error_len, "unknown error");
  }
  return 0;
}

int mikan_lt_start_stream(
    mikan_lt_session_t,
    int,
    int,
    int,
    char* out_url,
    int out_url_len,
    char* error,
    int error_len) {
  write_output(out_url, out_url_len, "");
  write_error(error, error_len, "streaming api is not implemented yet");
  return -1;
}

int mikan_lt_stop_stream(
    mikan_lt_session_t,
    int,
    char* error,
    int error_len) {
  write_error(error, error_len, "streaming api is not implemented yet");
  return 0;
}

int mikan_lt_set_stream_cache(
    mikan_lt_session_t,
    int,
    int,
    int,
    int,
    char* error,
    int error_len) {
  write_error(error, error_len, "streaming api is not implemented yet");
  return 0;
}

int mikan_lt_preload_stream(
    mikan_lt_session_t,
    int,
    long long,
    char* error,
    int error_len) {
  write_error(error, error_len, "streaming api is not implemented yet");
  return 0;
}

}  // extern "C"
