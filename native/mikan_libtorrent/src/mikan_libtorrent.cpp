#include "mikan_libtorrent.h"

#include <algorithm>
#include <cstring>
#include <memory>
#include <string>
#include <utility>

#include <libtorrent/session.hpp>
#include <libtorrent/settings_pack.hpp>
#include <libtorrent/version.hpp>

namespace {

namespace lt = libtorrent;

struct MikanSession {
  explicit MikanSession(lt::settings_pack settings) : session(std::move(settings)) {}

  lt::session session;
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

}  // extern "C"
