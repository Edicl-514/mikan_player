# Rust test fixtures

- Keep fixtures minimal, deterministic, UTF-8, and free of credentials or user data.
- Prefer one behavior per file; name malformed/edge-case variants explicitly.
- Load files through `crate::test_support::fixture` so tests never depend on the process working directory.
- Default tests must serve network fixtures through the loopback Axum helper. Live-network smoke tests must be `#[ignore]`.
- Use `tempfile` for writable files/directories. Tests that mutate `api::config::CONFIG` must hold `isolate_runtime_config()` so they serialize and restore the full snapshot.
