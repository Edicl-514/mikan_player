#include "mikan_libtorrent.h"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <memory>
#include <string>
#include <thread>
#include <unordered_map>
#include <utility>
#include <vector>

#include "httplib.h"

#include <libtorrent/download_priority.hpp>
#include <libtorrent/hex.hpp>
#include <libtorrent/magnet_uri.hpp>
#include <libtorrent/peer_request.hpp>
#include <libtorrent/read_resume_data.hpp>
#include <libtorrent/session.hpp>
#include <libtorrent/settings_pack.hpp>
#include <libtorrent/torrent_flags.hpp>
#include <libtorrent/torrent_handle.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/version.hpp>
#include <libtorrent/write_resume_data.hpp>

namespace {

namespace lt = libtorrent;

struct StreamContext;

struct MikanSession {
  explicit MikanSession(lt::settings_pack settings) : session(std::move(settings)) {}

  std::mutex mutex;
  lt::session session;
  int next_torrent_id = 1;
  std::unordered_map<int, lt::torrent_handle> torrents;
  std::unordered_map<int, std::string> save_paths;  // torrent_id -> save_path

  // Streaming state (lazily initialized)
  std::unique_ptr<httplib::Server> http_server;
  std::thread http_thread;
  int http_port = 0;
  int next_stream_id = 1;
  std::unordered_map<int, std::shared_ptr<StreamContext>> streams;  // stream_id -> context
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

void make_params_manually_active(lt::add_torrent_params& params) {
  params.flags &= ~lt::torrent_flags::paused;
  params.flags &= ~lt::torrent_flags::auto_managed;
  params.flags &= ~lt::torrent_flags::stop_when_ready;
}

template <typename T>
void append_unique(std::vector<T>& target, const std::vector<T>& source) {
  for (const auto& item : source) {
    if (std::find(target.begin(), target.end(), item) == target.end()) {
      target.push_back(item);
    }
  }
}

void append_unique_trackers(
    lt::add_torrent_params& target,
    const lt::add_torrent_params& source) {
  for (std::size_t i = 0; i < source.trackers.size(); ++i) {
    const auto& tracker = source.trackers[i];
    if (std::find(target.trackers.begin(), target.trackers.end(), tracker) != target.trackers.end()) {
      continue;
    }
    target.trackers.push_back(tracker);
    const int tier = i < source.tracker_tiers.size() ? source.tracker_tiers[i] : 0;
    target.tracker_tiers.push_back(tier);
  }
}

void merge_magnet_sources(
    lt::add_torrent_params& target,
    const lt::add_torrent_params& magnet) {
  if (!target.info_hashes.has_v1() && magnet.info_hashes.has_v1()) {
    target.info_hashes.v1 = magnet.info_hashes.v1;
  }
  if (!target.info_hashes.has_v2() && magnet.info_hashes.has_v2()) {
    target.info_hashes.v2 = magnet.info_hashes.v2;
  }
  if (target.name.empty()) {
    target.name = magnet.name;
  }
  append_unique_trackers(target, magnet);
  append_unique(target.dht_nodes, magnet.dht_nodes);
  append_unique(target.http_seeds, magnet.http_seeds);
  append_unique(target.url_seeds, magnet.url_seeds);
  append_unique(target.peers, magnet.peers);

  // A stale or partial resume file may carry these flags. For magnet recovery
  // they are especially harmful, because metadata download depends on DHT/PEX.
  target.flags &= ~lt::torrent_flags::disable_dht;
  target.flags &= ~lt::torrent_flags::disable_lsd;
  target.flags &= ~lt::torrent_flags::disable_pex;
}

lt::settings_pack make_settings(
    const char* listen_interfaces,
    int download_limit_bytes_per_sec,
    int upload_limit_bytes_per_sec) {
  lt::settings_pack settings;

  // Use a high port by default.  The legacy 6881-6889 range is widely
  // throttled or blocked by ISPs; port 49152 is in the IANA dynamic range.
  const char* interfaces =
      (listen_interfaces != nullptr && listen_interfaces[0] != '\0')
          ? listen_interfaces
          : "0.0.0.0:49152";

  settings.set_str(lt::settings_pack::listen_interfaces, interfaces);
  settings.set_bool(lt::settings_pack::enable_dht, true);
  settings.set_bool(lt::settings_pack::enable_lsd, true);
  settings.set_bool(lt::settings_pack::enable_upnp, true);
  settings.set_bool(lt::settings_pack::enable_natpmp, true);
  settings.set_bool(lt::settings_pack::announce_to_all_trackers, true);
  settings.set_bool(lt::settings_pack::announce_to_all_tiers, true);
  settings.set_int(lt::settings_pack::alert_queue_size, 10000);

  // uTP transport — uses UDP so it's less susceptible to ISP TCP-based
  // traffic shaping, and its LEDBAT congestion control backs off when
  // the network is congested (better for streaming alongside other traffic).
  settings.set_bool(lt::settings_pack::enable_incoming_utp, true);
  settings.set_bool(lt::settings_pack::enable_outgoing_utp, true);

  // Opportunistic protocol encryption keeps compatibility with plain peers
  // while still negotiating encrypted connections when peers support them.
  settings.set_int(lt::settings_pack::in_enc_policy, lt::settings_pack::pe_enabled);
  settings.set_int(lt::settings_pack::out_enc_policy, lt::settings_pack::pe_enabled);
  settings.set_int(lt::settings_pack::allowed_enc_level, lt::settings_pack::pe_both);

  // Connection and active torrent limits — the libtorrent defaults are
  // very conservative (3 active downloads, 200 connections).  For a
  // personal streaming client we want more headroom.
  settings.set_int(lt::settings_pack::connections_limit, 200);
#if TORRENT_ABI_VERSION == 1
  settings.set_int(lt::settings_pack::half_open_limit, 100);
#endif
  settings.set_int(lt::settings_pack::active_downloads, 10);
  settings.set_int(lt::settings_pack::active_seeds, 10);
  settings.set_int(lt::settings_pack::active_limit, 20);

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

// ---------------------------------------------------------------------------
// Streaming support
// ---------------------------------------------------------------------------

struct StreamContext {
  int stream_id;
  int torrent_id;
  int file_index;
  int64_t file_size;
  std::string file_path;       // absolute path on disk
  std::atomic<int64_t> read_ahead_bytes{0};  // how far ahead to set piece deadlines
  std::atomic<bool> active{true};

  // Track which pieces we have set deadlines for, so we can clear them on stop.
  std::mutex deadlines_mutex;
  std::vector<int> deadline_pieces;
  int deadline_first_piece = -1;
  int deadline_last_piece = -1;
};

// Compute the absolute torrent offset for a given file + file-relative offset.
int64_t file_offset_in_torrent(
    const std::shared_ptr<const lt::torrent_info>& ti,
    int file_index,
    int64_t offset) {
  const auto& fs = ti->files();
  return fs.file_offset(lt::file_index_t{file_index}) + offset;
}

// Compute the piece range [first_piece, last_piece] that covers
// [file_offset, file_offset + length) within the torrent.
bool piece_range_for_offset(
    const std::shared_ptr<const lt::torrent_info>& ti,
    int64_t torrent_offset,
    int64_t length,
    int& out_first,
    int& out_last) {
  if (!ti || length <= 0) return false;
  const int piece_size = ti->piece_length();
  const int num_pieces = ti->num_pieces();
  out_first = static_cast<int>(torrent_offset / piece_size);
  out_last = static_cast<int>((torrent_offset + length - 1) / piece_size);
  if (out_first < 0) out_first = 0;
  if (out_last >= num_pieces) out_last = num_pieces - 1;
  return out_first <= out_last;
}

// Set piece deadlines for the playback window starting at `torrent_offset`.
// Pieces closer to the current position get tighter deadlines.
void set_playback_deadlines(
    lt::torrent_handle& handle,
    const std::shared_ptr<const lt::torrent_info>& ti,
    int64_t torrent_offset,
    int64_t read_ahead,
    StreamContext* ctx) {
  auto st = handle.status();
  if (st.is_seeding || st.is_finished) {
    return;
  }

  constexpr int64_t kMinReadAheadBytes = 2 * 1024 * 1024;
  constexpr int64_t kMaxReadAheadBytes = 16 * 1024 * 1024;
  read_ahead = std::clamp(read_ahead, kMinReadAheadBytes, kMaxReadAheadBytes);

  int first_piece, last_piece;
  if (!piece_range_for_offset(ti, torrent_offset, read_ahead, first_piece, last_piece)) {
    return;
  }

  std::vector<int> old_pieces;
  {
    std::scoped_lock lock(ctx->deadlines_mutex);
    if (ctx->deadline_first_piece >= 0 &&
        first_piece >= ctx->deadline_first_piece &&
        first_piece <= ctx->deadline_last_piece) {
      const int remaining_pieces = ctx->deadline_last_piece - first_piece + 1;
      const int covered_pieces = ctx->deadline_last_piece - ctx->deadline_first_piece + 1;
      if (remaining_pieces > covered_pieces / 2) {
        return;
      }
    }
    old_pieces = ctx->deadline_pieces;
  }

  for (int p : old_pieces) {
    handle.reset_piece_deadline(lt::piece_index_t{p});
  }

  std::vector<int> pieces;
  for (int p = first_piece; p <= last_piece; ++p) {
    handle.set_piece_deadline(lt::piece_index_t{p}, (p - first_piece) * 100,
                              lt::torrent_handle::alert_when_available);
    pieces.push_back(p);
  }

  // Record deadline pieces so stop_stream can clear them.
  {
    std::scoped_lock lock(ctx->deadlines_mutex);
    ctx->deadline_first_piece = first_piece;
    ctx->deadline_last_piece = last_piece;
    ctx->deadline_pieces = std::move(pieces);
  }
}

// Clear all piece deadlines that were set for a stream.
void clear_playback_deadlines(
    lt::torrent_handle& handle,
    StreamContext* ctx) {
  std::vector<int> pieces;
  {
    std::scoped_lock lock(ctx->deadlines_mutex);
    pieces = std::move(ctx->deadline_pieces);
    ctx->deadline_first_piece = -1;
    ctx->deadline_last_piece = -1;
  }
  for (int p : pieces) {
    handle.reset_piece_deadline(lt::piece_index_t{p});
  }
}

// Check if all pieces in [first_piece, last_piece] are downloaded and hash-verified.
bool are_pieces_ready(
    lt::torrent_handle& handle,
    int first_piece,
    int last_piece) {
  if (first_piece > last_piece) return true;
  auto st = handle.status(lt::torrent_handle::query_pieces);
  if (st.is_seeding || st.is_finished) return true;
  const auto& pieces = st.pieces;
  if (pieces.empty()) return false;
  for (int p = first_piece; p <= last_piece; ++p) {
    if (p >= static_cast<int>(pieces.size())) return false;
    if (!pieces[lt::piece_index_t{p}]) return false;
  }
  return true;
}

// Read a chunk of data from the file on disk.
// Returns the number of bytes actually read, or -1 on error.
int read_file_chunk(
    const std::string& file_path,
    int64_t offset,
    int64_t length,
    char* buffer) {
  if (length <= 0) return 0;
  std::ifstream f(file_path, std::ios::binary);
  if (!f.is_open()) return -1;
  f.seekg(offset, std::ios::beg);
  if (!f) return -1;
  f.read(buffer, static_cast<std::streamsize>(length));
  const auto count = f.gcount();
  return static_cast<int>(count);
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
  auto* s = static_cast<MikanSession*>(session);
  if (s == nullptr) return;

  // Stop HTTP server if running.
  if (s->http_server) {
    s->http_server->stop();
  }
  if (s->http_thread.joinable()) {
    s->http_thread.join();
  }

  delete s;
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
    make_params_manually_active(params);

    std::scoped_lock lock(s->mutex);
    auto handle = s->session.add_torrent(std::move(params), ec);
    if (ec || !handle.is_valid()) {
      write_error(error, error_len, ec ? ec.message() : "failed to add magnet");
      return -1;
    }
    const int torrent_id = s->next_torrent_id++;
    s->torrents[torrent_id] = handle;
    if (save_path != nullptr && save_path[0] != '\0') {
      s->save_paths[torrent_id] = save_path;
    }
    clear_error(error, error_len);
    return torrent_id;
  } catch (const std::exception& e) {
    write_error(error, error_len, e.what());
  } catch (...) {
    write_error(error, error_len, "unknown error");
  }
  return -1;
}

int mikan_lt_add_magnet_ex(
    mikan_lt_session_t session,
    const char* magnet_uri,
    const char* save_path,
    const char* resume_path,
    int seed_mode,
    char* error,
    int error_len) {
  try {
    auto* s = as_session(session, error, error_len);
    if (s == nullptr) {
      return -1;
    }

    lt::add_torrent_params params;
    lt::add_torrent_params magnet_params;
    bool has_magnet = false;
    if (magnet_uri != nullptr && magnet_uri[0] != '\0') {
      lt::error_code ec;
      magnet_params = lt::parse_magnet_uri(magnet_uri, ec);
      if (!ec) {
        has_magnet = true;
      } else if (resume_path == nullptr || resume_path[0] == '\0') {
        write_error(error, error_len, ec.message());
        return -1;
      }
    }

    // Try to load resume data first — if available it includes metadata + piece
    // bitfield, skipping both the DHT metadata download and full hash checking.
    bool has_resume = false;
    if (resume_path != nullptr && resume_path[0] != '\0') {
      std::ifstream file(resume_path, std::ios::binary | std::ios::ate);
      if (file.is_open()) {
        auto file_size = file.tellg();
        file.seekg(0);
        std::vector<char> buf(static_cast<size_t>(file_size));
        file.read(buf.data(), file_size);
        if (file.good() && file_size > 0) {
          lt::error_code ec;
          params = lt::read_resume_data(buf, ec);
          if (!ec) {
            has_resume = true;
          }
        }
      }
    }

    if (!has_resume) {
      // No resume data — parse magnet as usual.
      if (!has_magnet) {
        write_error(error, error_len, "magnet uri is empty");
        return -1;
      }
      params = std::move(magnet_params);
    } else if (has_magnet) {
      merge_magnet_sources(params, magnet_params);
    }

    if (save_path != nullptr && save_path[0] != '\0') {
      params.save_path = save_path;
    }

    if (seed_mode != 0) {
      params.flags |= lt::torrent_flags::seed_mode;
    }
    make_params_manually_active(params);

    lt::error_code ec;
    std::scoped_lock lock(s->mutex);
    auto handle = s->session.add_torrent(std::move(params), ec);
    if (ec || !handle.is_valid()) {
      write_error(error, error_len, ec ? ec.message() : "failed to add magnet");
      return -1;
    }
    const int torrent_id = s->next_torrent_id++;
    s->torrents[torrent_id] = handle;
    if (save_path != nullptr && save_path[0] != '\0') {
      s->save_paths[torrent_id] = save_path;
    }
    clear_error(error, error_len);
    return torrent_id;
  } catch (const std::exception& e) {
    write_error(error, error_len, e.what());
  } catch (...) {
    write_error(error, error_len, "unknown error");
  }
  return -1;
}

int mikan_lt_save_resume_data(
    mikan_lt_session_t session,
    int torrent_id,
    const char* resume_path,
    char* error,
    int error_len) {
  try {
    auto* s = as_session(session, error, error_len);
    if (s == nullptr) {
      return 0;
    }
    if (resume_path == nullptr || resume_path[0] == '\0') {
      write_error(error, error_len, "resume_path is empty");
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

    auto params = handle.get_resume_data(lt::torrent_handle::save_info_dict);
    if (params.ti == nullptr
        && !params.info_hashes.has_v1()
        && !params.info_hashes.has_v2()) {
      write_error(error, error_len, "resume data is empty");
      return 0;
    }

    auto buf = lt::write_resume_data_buf(params);
    const std::filesystem::path path(resume_path);
    if (path.has_parent_path()) {
      std::filesystem::create_directories(path.parent_path());
    }
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    if (!file.is_open()) {
      write_error(error, error_len, "failed to open resume file");
      return 0;
    }
    file.write(buf.data(), static_cast<std::streamsize>(buf.size()));
    file.close();
    clear_error(error, error_len);
    return 1;
  } catch (const std::exception& e) {
    write_error(error, error_len, e.what());
  } catch (...) {
    write_error(error, error_len, "unknown error");
  }
  return 0;
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
      s->save_paths.erase(torrent_id);
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
    mikan_lt_session_t session,
    int torrent_id,
    int file_index,
    int max_cache_bytes,
    char* out_url,
    int out_url_len,
    char* error,
    int error_len) {
  try {
    auto* s = as_session(session, error, error_len);
    if (s == nullptr) {
      write_output(out_url, out_url_len, "");
      return -1;
    }

    // Resolve torrent handle and metadata.
    lt::torrent_handle handle;
    std::shared_ptr<const lt::torrent_info> ti;
    std::string save_path;
    {
      std::scoped_lock lock(s->mutex);
      handle = find_torrent_handle(s, torrent_id, error, error_len);
      if (!handle.is_valid()) {
        write_output(out_url, out_url_len, "");
        return -1;
      }
      ti = handle.torrent_file();
      if (!ti) {
        write_error(error, error_len, "torrent metadata not available");
        write_output(out_url, out_url_len, "");
        return -1;
      }
      auto sp_it = s->save_paths.find(torrent_id);
      if (sp_it != s->save_paths.end()) {
        save_path = sp_it->second;
      } else {
        // Fallback: query from torrent status.
        auto st = handle.status(lt::torrent_handle::query_save_path);
        save_path = st.save_path;
      }
    }

    // Validate file index and compute absolute file path.
    const auto& fs = ti->files();
    if (file_index < 0 || file_index >= fs.num_files()) {
      write_error(error, error_len, "file index out of range");
      write_output(out_url, out_url_len, "");
      return -1;
    }
    const auto fidx = lt::file_index_t{file_index};
    const int64_t file_size = fs.file_size(fidx);
    const std::string relative_path = fs.file_path(fidx);
    std::filesystem::path abs_path = std::filesystem::path(save_path) / relative_path;
    const std::string abs_path_str = abs_path.string();

    // Lazily start the HTTP server on first stream.
    if (!s->http_server) {
      auto srv = std::make_unique<httplib::Server>();
      srv->set_payload_max_length(0);  // No POST body needed.

      // Bind to 127.0.0.1:0 → OS picks a random port.
      s->http_port = srv->bind_to_any_port("127.0.0.1");
      if (s->http_port <= 0) {
        write_error(error, error_len, "failed to bind HTTP server");
        write_output(out_url, out_url_len, "");
        return -1;
      }

      // Start server in a background thread.
      s->http_server = std::move(srv);
      s->http_thread = std::thread([&s_ref = *s]() {
        s_ref.http_server->listen_after_bind();
      });

      // Wait briefly for the server to start.
      std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    // Allocate a new stream context.
    int stream_id;
    auto ctx = std::make_shared<StreamContext>();
    ctx->torrent_id = torrent_id;
    ctx->file_index = file_index;
    ctx->file_size = file_size;
    ctx->file_path = abs_path_str;
    ctx->read_ahead_bytes.store(
        max_cache_bytes > 0
            ? static_cast<int64_t>(max_cache_bytes)
            : 4 * 1024 * 1024);  // default 4MB read-ahead
    ctx->active.store(true);

    {
      std::scoped_lock lock(s->mutex);
      stream_id = s->next_stream_id++;
      ctx->stream_id = stream_id;
      s->streams[stream_id] = ctx;
    }

    // Set initial deadlines for the beginning of the file.
    {
      int64_t torrent_off = file_offset_in_torrent(ti, file_index, 0);
      set_playback_deadlines(handle, ti, torrent_off, ctx->read_ahead_bytes.load(), ctx.get());
    }

    // Register the HTTP route: GET /stream/<stream_id>
    std::string route = "/stream/" + std::to_string(stream_id);

    s->http_server->Get(route, [s, stream_id](const httplib::Request& req, httplib::Response& res) {
      std::shared_ptr<StreamContext> ctx;
      {
        std::scoped_lock lock(s->mutex);
        auto it = s->streams.find(stream_id);
        if (it != s->streams.end()) {
          ctx = it->second;
        }
      }

      if (!ctx || !ctx->active.load()) {
        res.status = 404;
        res.set_content("stream not found", "text/plain");
        return;
      }

      const int64_t file_size = ctx->file_size;
      int64_t playback_offset = 0;
      if (!req.ranges.empty()) {
        const auto first_range = req.ranges.front();
        if (first_range.first >= 0) {
          playback_offset = first_range.first;
        } else if (first_range.second > 0) {
          playback_offset = std::max<int64_t>(0, file_size - first_range.second);
        }
      }

      // Update piece deadlines for the new playback position.
      {
        lt::torrent_handle handle;
        std::shared_ptr<const lt::torrent_info> ti;
        {
          std::scoped_lock lock(s->mutex);
          handle = find_torrent_handle(s, ctx->torrent_id, nullptr, 0);
          if (handle.is_valid()) {
            ti = handle.torrent_file();
          }
        }
        if (handle.is_valid() && ti) {
          int64_t torrent_off = file_offset_in_torrent(ti, ctx->file_index, playback_offset);
          set_playback_deadlines(handle, ti, torrent_off, ctx->read_ahead_bytes.load(), ctx.get());
        }
      }

      // Determine chunk size (256KB to 1MB). httplib applies HTTP Range
      // requests to the content provider automatically, so provider offsets are
      // always file-relative offsets.
      const int64_t chunk_size = 256 * 1024;

      // Set up response headers.
      res.set_header("Accept-Ranges", "bytes");

      // Use ContentProvider to stream data in chunks.
      res.set_content_provider(
          static_cast<size_t>(file_size),
          "application/octet-stream",
          [s, ctx, chunk_size](size_t offset, size_t length, httplib::DataSink& sink) {
            if (!ctx->active.load()) {
              return false;
            }

            const int64_t file_offset = static_cast<int64_t>(offset);
            const int64_t remaining = ctx->file_size - file_offset;
            const int64_t to_read = std::min({static_cast<int64_t>(length), remaining, chunk_size});
            if (to_read <= 0) {
              return false;
            }

            // Get torrent handle and info for piece readiness check.
            lt::torrent_handle handle;
            std::shared_ptr<const lt::torrent_info> ti;
            {
              std::scoped_lock lock(s->mutex);
              handle = find_torrent_handle(s, ctx->torrent_id, nullptr, 0);
              if (handle.is_valid()) {
                ti = handle.torrent_file();
              }
            }

            if (!handle.is_valid() || !ti) {
              return false;
            }

            // Compute which pieces this chunk covers.
            const int64_t torrent_off = file_offset_in_torrent(ti, ctx->file_index, file_offset);
            int first_piece, last_piece;
            if (piece_range_for_offset(ti, torrent_off, to_read, first_piece, last_piece)) {
              set_playback_deadlines(
                  handle,
                  ti,
                  torrent_off,
                  ctx->read_ahead_bytes.load(),
                  ctx.get());
              // Wait for pieces to be ready (poll with timeout).
              const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(120);
              while (!are_pieces_ready(handle, first_piece, last_piece)) {
                if (!ctx->active.load()) {
                  return false;
                }
                if (std::chrono::steady_clock::now() > deadline) {
                  return false;
                }
                std::this_thread::sleep_for(std::chrono::milliseconds(50));
              }
            }

            // Read from disk.
            std::vector<char> buffer(static_cast<size_t>(to_read));
            const int bytes_read = read_file_chunk(ctx->file_path, file_offset, to_read, buffer.data());
            if (bytes_read <= 0) {
              return false;
            }

            return sink.write(buffer.data(), static_cast<size_t>(bytes_read));
          },
          [](bool /*success*/) {
            // Completion callback — nothing to do.
          });
    });

    // Build the stream URL.
    const std::string url = "http://127.0.0.1:" + std::to_string(s->http_port) + route;
    write_output(out_url, out_url_len, url);
    clear_error(error, error_len);
    return stream_id;
  } catch (const std::exception& e) {
    write_error(error, error_len, e.what());
  } catch (...) {
    write_error(error, error_len, "unknown error");
  }
  write_output(out_url, out_url_len, "");
  return -1;
}

int mikan_lt_stop_stream(
    mikan_lt_session_t session,
    int stream_id,
    char* error,
    int error_len) {
  try {
    auto* s = as_session(session, error, error_len);
    if (s == nullptr) {
      return 0;
    }

    std::shared_ptr<StreamContext> ctx;
    {
      std::scoped_lock lock(s->mutex);
      auto it = s->streams.find(stream_id);
      if (it == s->streams.end()) {
        write_error(error, error_len, "stream id not found");
        return 0;
      }
      ctx = it->second;
    }

    // Mark stream as inactive — in-flight HTTP responses will notice.
    ctx->active.store(false);

    // Clear piece deadlines, but do NOT pause or change the torrent.
    lt::torrent_handle handle;
    {
      std::scoped_lock lock(s->mutex);
      handle = find_torrent_handle(s, ctx->torrent_id, nullptr, 0);
    }
    if (handle.is_valid()) {
      clear_playback_deadlines(handle, ctx.get());
    }

    // Remove the stream context.
    {
      std::scoped_lock lock(s->mutex);
      s->streams.erase(stream_id);
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

int mikan_lt_set_stream_cache(
    mikan_lt_session_t session,
    int stream_id,
    int capacity,
    int read_ahead_pct,
    int connections_limit,
    char* error,
    int error_len) {
  try {
    auto* s = as_session(session, error, error_len);
    if (s == nullptr) {
      return 0;
    }

    std::shared_ptr<StreamContext> ctx;
    {
      std::scoped_lock lock(s->mutex);
      auto it = s->streams.find(stream_id);
      if (it == s->streams.end()) {
        write_error(error, error_len, "stream id not found");
        return 0;
      }
      ctx = it->second;
    }

    // Update read-ahead window.
    if (capacity > 0) {
      ctx->read_ahead_bytes.store(static_cast<int64_t>(capacity));
    } else if (read_ahead_pct > 0) {
      ctx->read_ahead_bytes.store(ctx->file_size * read_ahead_pct / 100);
    }

    // Optionally update connections limit on the session.
    if (connections_limit > 0) {
      lt::settings_pack settings;
      settings.set_int(lt::settings_pack::connections_limit, connections_limit);
      std::scoped_lock lock(s->mutex);
      s->session.apply_settings(settings);
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

int mikan_lt_preload_stream(
    mikan_lt_session_t session,
    int stream_id,
    long long preload_bytes,
    char* error,
    int error_len) {
  try {
    auto* s = as_session(session, error, error_len);
    if (s == nullptr) {
      return 0;
    }

    std::shared_ptr<StreamContext> ctx;
    {
      std::scoped_lock lock(s->mutex);
      auto it = s->streams.find(stream_id);
      if (it == s->streams.end()) {
        write_error(error, error_len, "stream id not found");
        return 0;
      }
      ctx = it->second;
    }

    if (!ctx->active.load()) {
      write_error(error, error_len, "stream is not active");
      return 0;
    }

    // Set deadlines for the first `preload_bytes` of the file.
    lt::torrent_handle handle;
    std::shared_ptr<const lt::torrent_info> ti;
    {
      std::scoped_lock lock(s->mutex);
      handle = find_torrent_handle(s, ctx->torrent_id, nullptr, 0);
      if (handle.is_valid()) {
        ti = handle.torrent_file();
      }
    }

    if (!handle.is_valid() || !ti) {
      write_error(error, error_len, "torrent not available");
      return 0;
    }

    const int64_t ahead = preload_bytes > 0
        ? static_cast<int64_t>(preload_bytes)
        : ctx->read_ahead_bytes.load();
    const int64_t torrent_off = file_offset_in_torrent(ti, ctx->file_index, 0);
    set_playback_deadlines(handle, ti, torrent_off, ahead, ctx.get());

    clear_error(error, error_len);
    return 1;
  } catch (const std::exception& e) {
    write_error(error, error_len, e.what());
  } catch (...) {
    write_error(error, error_len, "unknown error");
  }
  return 0;
}

}  // extern "C"
