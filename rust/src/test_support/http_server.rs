use axum::Router;
use axum::body::{Body, Bytes, to_bytes};
use axum::extract::State;
use axum::http::{HeaderMap, HeaderName, HeaderValue, Method, Request, Response, StatusCode, Uri};
use futures::stream;
use std::collections::VecDeque;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tokio::net::TcpListener;
use tokio::sync::oneshot;
use tokio::task::JoinHandle;

use super::fixture::fixture_bytes;

const MAX_RECORDED_REQUEST_BODY: usize = 1024 * 1024;

#[derive(Clone, Debug)]
pub(crate) struct TestResponse {
    status: StatusCode,
    headers: HeaderMap,
    chunks: Vec<Bytes>,
    response_delay: Duration,
    chunk_delay: Duration,
    body_error: Option<String>,
    body_error_delay: Duration,
}

impl TestResponse {
    pub(crate) fn new(status: StatusCode, body: impl Into<Bytes>) -> Self {
        Self {
            status,
            headers: HeaderMap::new(),
            chunks: vec![body.into()],
            response_delay: Duration::ZERO,
            chunk_delay: Duration::ZERO,
            body_error: None,
            body_error_delay: Duration::ZERO,
        }
    }

    pub(crate) fn ok(body: impl Into<Bytes>) -> Self {
        Self::new(StatusCode::OK, body)
    }

    pub(crate) fn fixture(relative_path: impl AsRef<std::path::Path>) -> Self {
        Self::ok(fixture_bytes(relative_path))
    }

    pub(crate) fn redirect(status: StatusCode, location: &str) -> Self {
        assert!(status.is_redirection(), "redirect status must be 3xx");
        Self::new(status, Bytes::new()).with_header("location", location)
    }

    pub(crate) fn with_header(mut self, name: &str, value: &str) -> Self {
        let name = HeaderName::from_bytes(name.as_bytes())
            .unwrap_or_else(|error| panic!("invalid test header name {name:?}: {error}"));
        let value = HeaderValue::from_str(value)
            .unwrap_or_else(|error| panic!("invalid test header value {value:?}: {error}"));
        self.headers.insert(name, value);
        self
    }

    pub(crate) fn with_delay(mut self, delay: Duration) -> Self {
        self.response_delay = delay;
        self
    }

    pub(crate) fn with_chunks<I, B>(mut self, chunks: I, inter_chunk_delay: Duration) -> Self
    where
        I: IntoIterator<Item = B>,
        B: Into<Bytes>,
    {
        self.chunks = chunks.into_iter().map(Into::into).collect();
        self.chunk_delay = inter_chunk_delay;
        self
    }

    pub(crate) fn with_body_error_after_chunks(mut self, message: &str, delay: Duration) -> Self {
        self.body_error = Some(message.to_string());
        self.body_error_delay = delay;
        self
    }

    async fn into_response(self) -> Response<Body> {
        if !self.response_delay.is_zero() {
            tokio::time::sleep(self.response_delay).await;
        }

        let body = if self.body_error.is_none() && self.chunks.len() <= 1 {
            Body::from(self.chunks.into_iter().next().unwrap_or_default())
        } else {
            let body_stream = stream::unfold(
                (
                    self.chunks.into_iter(),
                    true,
                    self.chunk_delay,
                    self.body_error,
                    self.body_error_delay,
                ),
                |(mut chunks, first, delay, mut body_error, body_error_delay)| async move {
                    if let Some(chunk) = chunks.next() {
                        if !first && !delay.is_zero() {
                            tokio::time::sleep(delay).await;
                        }
                        return Some((
                            Ok::<Bytes, std::io::Error>(chunk),
                            (chunks, false, delay, body_error, body_error_delay),
                        ));
                    }

                    if let Some(message) = body_error.take() {
                        if !body_error_delay.is_zero() {
                            tokio::time::sleep(body_error_delay).await;
                        }
                        return Some((
                            Err(std::io::Error::new(
                                std::io::ErrorKind::ConnectionReset,
                                message,
                            )),
                            (chunks, false, delay, body_error, body_error_delay),
                        ));
                    }

                    None
                },
            );
            Body::from_stream(body_stream)
        };

        let mut response = Response::new(body);
        *response.status_mut() = self.status;
        *response.headers_mut() = self.headers;
        response
    }
}

#[derive(Debug)]
pub(crate) struct TestRoute {
    method: Method,
    path: String,
    responses: VecDeque<TestResponse>,
}

impl TestRoute {
    pub(crate) fn new(method: Method, path: &str, response: TestResponse) -> Self {
        Self::sequence(method, path, [response])
    }

    pub(crate) fn get(path: &str, response: TestResponse) -> Self {
        Self::new(Method::GET, path, response)
    }

    pub(crate) fn post(path: &str, response: TestResponse) -> Self {
        Self::new(Method::POST, path, response)
    }

    pub(crate) fn sequence<I>(method: Method, path: &str, responses: I) -> Self
    where
        I: IntoIterator<Item = TestResponse>,
    {
        assert!(path.starts_with('/'), "test route paths must start with /");
        let responses = responses.into_iter().collect::<VecDeque<_>>();
        assert!(
            !responses.is_empty(),
            "test routes require at least one response"
        );
        Self {
            method,
            path: path.to_string(),
            responses,
        }
    }
}

#[derive(Clone, Debug)]
pub(crate) struct RecordedRequest {
    pub(crate) method: Method,
    pub(crate) uri: Uri,
    pub(crate) headers: HeaderMap,
    pub(crate) body: Bytes,
}

#[derive(Debug)]
struct RouteState {
    method: Method,
    path: String,
    responses: Mutex<VecDeque<TestResponse>>,
}

#[derive(Debug)]
struct ServerState {
    routes: Vec<RouteState>,
    requests: Mutex<Vec<RecordedRequest>>,
}

pub(crate) struct TestServer {
    address: SocketAddr,
    state: Arc<ServerState>,
    shutdown_tx: Option<oneshot::Sender<()>>,
    task: Option<JoinHandle<()>>,
}

impl TestServer {
    pub(crate) async fn spawn(routes: impl IntoIterator<Item = TestRoute>) -> Self {
        let listener = TcpListener::bind(SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0))
            .await
            .expect("failed to bind loopback test server");
        let address = listener
            .local_addr()
            .expect("failed to read loopback test server address");
        let state = Arc::new(ServerState {
            routes: routes
                .into_iter()
                .map(|route| RouteState {
                    method: route.method,
                    path: route.path,
                    responses: Mutex::new(route.responses),
                })
                .collect(),
            requests: Mutex::new(Vec::new()),
        });
        let app = Router::new()
            .fallback(handle_request)
            .with_state(Arc::clone(&state));
        let (shutdown_tx, shutdown_rx) = oneshot::channel();
        let task = tokio::spawn(async move {
            axum::serve(listener, app)
                .with_graceful_shutdown(async {
                    let _ = shutdown_rx.await;
                })
                .await
                .expect("loopback test server failed");
        });

        Self {
            address,
            state,
            shutdown_tx: Some(shutdown_tx),
            task: Some(task),
        }
    }

    pub(crate) fn base_url(&self) -> String {
        format!("http://{}", self.address)
    }

    pub(crate) fn url(&self, path: &str) -> String {
        assert!(path.starts_with('/'), "test URL paths must start with /");
        format!("{}{}", self.base_url(), path)
    }

    pub(crate) fn requests(&self) -> Vec<RecordedRequest> {
        self.state.requests.lock().unwrap().clone()
    }

    pub(crate) fn request_count(&self, method: Method, path: &str) -> usize {
        self.state
            .requests
            .lock()
            .unwrap()
            .iter()
            .filter(|request| request.method == method && request.uri.path() == path)
            .count()
    }

    pub(crate) async fn shutdown(mut self) {
        if let Some(shutdown_tx) = self.shutdown_tx.take() {
            let _ = shutdown_tx.send(());
        }
        if let Some(task) = self.task.take() {
            task.await.expect("loopback test server task panicked");
        }
    }
}

impl Drop for TestServer {
    fn drop(&mut self) {
        if let Some(shutdown_tx) = self.shutdown_tx.take() {
            let _ = shutdown_tx.send(());
        }
        if let Some(task) = self.task.take() {
            task.abort();
        }
    }
}

async fn handle_request(
    State(state): State<Arc<ServerState>>,
    request: Request<Body>,
) -> Response<Body> {
    let (parts, body) = request.into_parts();
    let body = to_bytes(body, MAX_RECORDED_REQUEST_BODY)
        .await
        .unwrap_or_default();
    state.requests.lock().unwrap().push(RecordedRequest {
        method: parts.method.clone(),
        uri: parts.uri.clone(),
        headers: parts.headers,
        body,
    });

    let response = state
        .routes
        .iter()
        .find(|route| route.method == parts.method && route.path == parts.uri.path())
        .map(|route| {
            let mut responses = route.responses.lock().unwrap();
            if responses.len() > 1 {
                responses.pop_front().unwrap()
            } else {
                responses.front().unwrap().clone()
            }
        });

    match response {
        Some(response) => response.into_response().await,
        None => {
            TestResponse::new(StatusCode::NOT_FOUND, "no matching test route")
                .into_response()
                .await
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use reqwest::redirect::Policy;
    use tokio::time::Instant;

    #[tokio::test]
    async fn supports_status_headers_redirects_delays_and_response_sequences() {
        let server = TestServer::spawn([
            TestRoute::get(
                "/status",
                TestResponse::new(StatusCode::IM_A_TEAPOT, "short body")
                    .with_header("x-test-id", "status-1"),
            ),
            TestRoute::get(
                "/delayed",
                TestResponse::ok("later").with_delay(Duration::from_millis(20)),
            ),
            TestRoute::get(
                "/redirect",
                TestResponse::redirect(StatusCode::TEMPORARY_REDIRECT, "/status"),
            ),
            TestRoute::sequence(
                Method::GET,
                "/sequence",
                [
                    TestResponse::new(StatusCode::SERVICE_UNAVAILABLE, "retry"),
                    TestResponse::ok("ready"),
                ],
            ),
        ])
        .await;
        let no_redirect = reqwest::Client::builder()
            .redirect(Policy::none())
            .build()
            .unwrap();

        let status = no_redirect.get(server.url("/status")).send().await.unwrap();
        assert_eq!(status.status(), StatusCode::IM_A_TEAPOT);
        assert_eq!(status.headers()["x-test-id"], "status-1");
        assert_eq!(status.text().await.unwrap(), "short body");

        let started = Instant::now();
        let delayed = no_redirect
            .get(server.url("/delayed"))
            .send()
            .await
            .unwrap();
        assert!(started.elapsed() >= Duration::from_millis(15));
        assert_eq!(delayed.text().await.unwrap(), "later");

        let redirect = no_redirect
            .get(server.url("/redirect"))
            .send()
            .await
            .unwrap();
        assert_eq!(redirect.status(), StatusCode::TEMPORARY_REDIRECT);
        assert_eq!(redirect.headers()["location"], "/status");

        let first = no_redirect
            .get(server.url("/sequence"))
            .send()
            .await
            .unwrap();
        let second = no_redirect
            .get(server.url("/sequence"))
            .send()
            .await
            .unwrap();
        let third = no_redirect
            .get(server.url("/sequence"))
            .send()
            .await
            .unwrap();
        assert_eq!(first.status(), StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(second.status(), StatusCode::OK);
        assert_eq!(third.status(), StatusCode::OK);

        server.shutdown().await;
    }

    #[tokio::test]
    async fn serves_chunked_fixtures_and_records_request_details() {
        let server = TestServer::spawn([
            TestRoute::get(
                "/fixture",
                TestResponse::fixture("danmaku/search_anime.json")
                    .with_header("content-type", "application/json"),
            ),
            TestRoute::post(
                "/chunks",
                TestResponse::ok("")
                    .with_chunks(["first-", "second-", "third"], Duration::from_millis(2)),
            ),
        ])
        .await;
        let client = reqwest::Client::new();

        let fixture = client
            .get(server.url("/fixture?keyword=%E8%91%AC%E9%80%81"))
            .send()
            .await
            .unwrap();
        assert_eq!(fixture.headers()["content-type"], "application/json");
        assert!(fixture.text().await.unwrap().contains("Fixture Anime"));

        let chunks = client
            .post(server.url("/chunks"))
            .header("x-request-id", "request-7")
            .body("request body")
            .send()
            .await
            .unwrap();
        assert_eq!(chunks.text().await.unwrap(), "first-second-third");

        let requests = server.requests();
        assert_eq!(requests.len(), 2);
        assert_eq!(requests[0].uri.query(), Some("keyword=%E8%91%AC%E9%80%81"));
        assert_eq!(requests[1].headers["x-request-id"], "request-7");
        assert_eq!(requests[1].body, "request body");
        assert_eq!(server.request_count(Method::POST, "/chunks"), 1);

        server.shutdown().await;
    }
}
