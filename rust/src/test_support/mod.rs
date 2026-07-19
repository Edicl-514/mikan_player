//! Shared, offline-only helpers for Rust unit tests.
//!
//! Production modules keep their focused unit tests next to the implementation,
//! while stable response bodies live under `tests/fixtures`.

pub(crate) mod fixture;
pub(crate) mod http_server;
pub(crate) mod state;
