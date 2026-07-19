use serde::de::DeserializeOwned;
use std::path::{Component, Path, PathBuf};

/// Returns a validated path below `rust/tests/fixtures`.
pub(crate) fn fixture_path(relative_path: impl AsRef<Path>) -> PathBuf {
    let relative_path = relative_path.as_ref();
    assert!(
        !relative_path.is_absolute()
            && relative_path
                .components()
                .all(|component| matches!(component, Component::Normal(_))),
        "fixture paths must be relative and cannot contain traversal: {}",
        relative_path.display()
    );

    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("tests")
        .join("fixtures")
        .join(relative_path)
}

pub(crate) fn fixture_bytes(relative_path: impl AsRef<Path>) -> Vec<u8> {
    let path = fixture_path(relative_path);
    std::fs::read(&path)
        .unwrap_or_else(|error| panic!("failed to read fixture {}: {error}", path.display()))
}

pub(crate) fn fixture_text(relative_path: impl AsRef<Path>) -> String {
    let path = fixture_path(relative_path);
    std::fs::read_to_string(&path)
        .unwrap_or_else(|error| panic!("failed to read fixture {}: {error}", path.display()))
}

pub(crate) fn fixture_json<T: DeserializeOwned>(relative_path: impl AsRef<Path>) -> T {
    let path = fixture_path(relative_path);
    let bytes = std::fs::read(&path)
        .unwrap_or_else(|error| panic!("failed to read fixture {}: {error}", path.display()));
    serde_json::from_slice(&bytes)
        .unwrap_or_else(|error| panic!("failed to parse JSON fixture {}: {error}", path.display()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Value;

    #[test]
    fn loads_text_bytes_and_json_from_the_fixture_root() {
        let html = fixture_text("mikan/search_minimal.html");
        assert!(html.contains("/Home/Bangumi/123"));

        let xml = fixture_bytes("dmhy/feed_minimal.xml");
        assert!(xml.windows(4).any(|window| window == b"<rss"));

        let json: Value = fixture_json("danmaku/search_anime.json");
        assert_eq!(json["animes"][0]["animeId"], 42);
    }

    #[test]
    #[should_panic(expected = "fixture paths must be relative")]
    fn rejects_fixture_path_traversal() {
        let _ = fixture_path("../Cargo.toml");
    }
}
