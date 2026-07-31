use std::{
    collections::VecDeque,
    sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    },
    time::Instant,
};

use axum::{
    Json, Router,
    extract::{
        Query, State, WebSocketUpgrade,
        ws::{Message, WebSocket},
    },
    http::StatusCode,
    response::{Html, IntoResponse, Response},
    routing::{get, post},
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use tokio::sync::{RwLock, broadcast};
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use uuid::Uuid;

pub mod system;
use system::{ActionExecutor, DaemonConfig, SystemActionExecutor};

#[derive(Clone)]
pub struct AppState {
    started_at: Instant,
    sequence: Arc<AtomicU64>,
    computer: Arc<RwLock<ComputerState>>,
    notifications: Arc<RwLock<VecDeque<DesktopNotification>>>,
    events: broadcast::Sender<EventEnvelope>,
    signals: broadcast::Sender<String>,
    executor: Arc<dyn ActionExecutor>,
}

impl Default for AppState {
    fn default() -> Self {
        let config = DaemonConfig::load().unwrap_or_default();
        Self::with_executor(Arc::new(SystemActionExecutor::new(config)))
    }
}

impl AppState {
    pub fn with_executor(executor: Arc<dyn ActionExecutor>) -> Self {
        let (events, _) = broadcast::channel(128);
        let (signals, _) = broadcast::channel(128);
        Self {
            started_at: Instant::now(),
            sequence: Arc::new(AtomicU64::new(0)),
            computer: Arc::new(RwLock::new(ComputerState::default())),
            notifications: Arc::new(RwLock::new(VecDeque::with_capacity(256))),
            events,
            signals,
            executor,
        }
    }

    fn next_sequence(&self) -> u64 {
        self.sequence.fetch_add(1, Ordering::Relaxed) + 1
    }

    fn publish(&self, event_type: &str, payload: Value) {
        let _ = self.events.send(EventEnvelope {
            sequence: self.next_sequence(),
            event_type: event_type.to_owned(),
            occurred_at: Utc::now(),
            payload,
        });
    }
}

#[derive(Debug, Serialize)]
pub struct HealthResponse {
    service: &'static str,
    version: &'static str,
    platform: &'static str,
    uptime_seconds: u64,
    capabilities: Vec<&'static str>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComputerState {
    pub online: bool,
    pub volume: u8,
    pub media_playing: bool,
    pub notification_access: NotificationAccess,
}

impl Default for ComputerState {
    fn default() -> Self {
        Self {
            online: true,
            volume: 50,
            media_playing: false,
            notification_access: if cfg!(target_os = "macos") {
                NotificationAccess::Unsupported
            } else {
                NotificationAccess::Denied
            },
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NotificationAccess {
    Available,
    Denied,
    Unsupported,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DesktopNotification {
    pub sequence: u64,
    pub id: Uuid,
    pub source: String,
    pub title: String,
    pub body: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct NotificationPage {
    cursor: u64,
    items: Vec<DesktopNotification>,
}

#[derive(Debug, Deserialize)]
pub struct NotificationQuery {
    #[serde(default)]
    after: u64,
}

#[derive(Debug, Deserialize)]
pub struct ActionRequest {
    pub request_id: Uuid,
    pub action: Action,
    #[serde(default)]
    pub arguments: Value,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Action {
    LaunchApp,
    SendShortcut,
    SetVolume,
    MediaPlayPause,
    LockComputer,
    OpenUrl,
}

#[derive(Debug, Serialize)]
pub struct ActionResult {
    request_id: Uuid,
    accepted: bool,
    message: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EventEnvelope {
    pub sequence: u64,
    #[serde(rename = "type")]
    pub event_type: String,
    pub occurred_at: DateTime<Utc>,
    pub payload: Value,
}

pub fn app(state: AppState) -> Router {
    Router::new()
        .route("/", get(|| async { Html(VIEWER_HTML) }))
        .route("/viewer", get(|| async { Html(VIEWER_HTML) }))
        .route("/v1/health", get(health))
        .route("/v1/state", get(computer_state))
        .route("/v1/notifications", get(notifications))
        .route("/v1/actions", post(perform_action))
        .route("/v1/events", get(events_socket))
        .route("/v1/webrtc", get(signaling_socket))
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}

async fn health(State(state): State<AppState>) -> Json<HealthResponse> {
    Json(HealthResponse {
        service: "vivy-daemon",
        version: env!("CARGO_PKG_VERSION"),
        platform: std::env::consts::OS,
        uptime_seconds: state.started_at.elapsed().as_secs(),
        capabilities: vec!["actions", "events", "webrtc"],
    })
}

async fn computer_state(State(state): State<AppState>) -> Json<ComputerState> {
    Json(state.computer.read().await.clone())
}

async fn notifications(
    State(state): State<AppState>,
    Query(query): Query<NotificationQuery>,
) -> Json<NotificationPage> {
    let store = state.notifications.read().await;
    let items = store
        .iter()
        .filter(|item| item.sequence > query.after)
        .cloned()
        .collect();
    Json(NotificationPage {
        cursor: state.sequence.load(Ordering::Relaxed),
        items,
    })
}

async fn perform_action(
    State(state): State<AppState>,
    Json(request): Json<ActionRequest>,
) -> Result<Json<ActionResult>, ApiError> {
    validate_action(&request.action, &request.arguments)?;
    let message = state
        .executor
        .execute(&request.action, &request.arguments)
        .await
        .map_err(|error| ApiError::execution_failed(error.to_string()))?;

    match request.action {
        Action::SetVolume => {
            state.computer.write().await.volume = request.arguments["value"]
                .as_u64()
                .expect("validated volume") as u8;
        }
        Action::MediaPlayPause => {
            let mut computer = state.computer.write().await;
            computer.media_playing = !computer.media_playing;
        }
        _ => {}
    }

    let result = ActionResult {
        request_id: request.request_id,
        accepted: true,
        message,
    };
    state.publish(
        "action_result",
        serde_json::to_value(&result).unwrap_or(Value::Null),
    );
    Ok(Json(result))
}

fn validate_action(action: &Action, arguments: &Value) -> Result<(), ApiError> {
    match action {
        Action::SetVolume => {
            arguments
                .get("value")
                .and_then(Value::as_u64)
                .filter(|value| *value <= 100)
                .ok_or_else(|| ApiError::bad_request("set_volume requires value from 0 to 100"))?;
        }
        Action::LaunchApp => require_string(arguments, "app")?,
        Action::SendShortcut => require_string(arguments, "shortcut")?,
        Action::OpenUrl => require_string(arguments, "url")?,
        Action::MediaPlayPause | Action::LockComputer => {}
    }
    Ok(())
}

fn require_string(arguments: &Value, key: &str) -> Result<(), ApiError> {
    arguments
        .get(key)
        .and_then(Value::as_str)
        .filter(|value| !value.trim().is_empty())
        .map(|_| ())
        .ok_or_else(|| ApiError::bad_request(format!("missing non-empty {key}")))
}

async fn events_socket(ws: WebSocketUpgrade, State(state): State<AppState>) -> Response {
    ws.on_upgrade(move |socket| event_session(socket, state.events.subscribe()))
}

async fn event_session(mut socket: WebSocket, mut receiver: broadcast::Receiver<EventEnvelope>) {
    while let Ok(event) = receiver.recv().await {
        let Ok(payload) = serde_json::to_string(&event) else {
            continue;
        };
        if socket.send(Message::Text(payload.into())).await.is_err() {
            break;
        }
    }
}

async fn signaling_socket(ws: WebSocketUpgrade, State(state): State<AppState>) -> Response {
    ws.on_upgrade(move |socket| signaling_session(socket, state))
}

async fn signaling_session(mut socket: WebSocket, state: AppState) {
    let mut receiver = state.signals.subscribe();
    loop {
        tokio::select! {
            incoming = socket.recv() => match incoming {
                Some(Ok(Message::Text(payload))) if serde_json::from_str::<Value>(&payload).is_ok() => {
                    let _ = state.signals.send(payload.to_string());
                }
                Some(Ok(Message::Close(_))) | None | Some(Err(_)) => break,
                _ => {}
            },
            outgoing = receiver.recv() => match outgoing {
                Ok(payload) => if socket.send(Message::Text(payload.into())).await.is_err() { break; },
                Err(broadcast::error::RecvError::Lagged(_)) => continue,
                Err(broadcast::error::RecvError::Closed) => break,
            }
        }
    }
}

#[derive(Debug)]
pub struct ApiError {
    status: StatusCode,
    message: String,
}

impl ApiError {
    fn bad_request(message: impl Into<String>) -> Self {
        Self {
            status: StatusCode::BAD_REQUEST,
            message: message.into(),
        }
    }

    fn execution_failed(message: impl Into<String>) -> Self {
        Self {
            status: StatusCode::SERVICE_UNAVAILABLE,
            message: message.into(),
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        (self.status, Json(json!({ "error": self.message }))).into_response()
    }
}

const VIEWER_HTML: &str = r#"<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Vivy Viewer</title><style>
html,body{margin:0;height:100%;background:#090a0a;color:#f3f4ef;font-family:system-ui,sans-serif}
main{height:100%;display:grid;place-items:center}video{width:100%;height:100%;object-fit:contain}.state{position:fixed;top:20px;left:20px;background:#151817;padding:10px 14px;border-radius:6px}
</style></head><body><main><video id="stream" autoplay playsinline></video><div class="state" id="state">Waiting for Vivy</div></main>
<script>
const state=document.querySelector('#state');
const scheme=location.protocol==='https:'?'wss':'ws';
const socket=new WebSocket(`${scheme}://${location.host}/v1/webrtc`);
const peer=new RTCPeerConnection();
peer.ontrack=e=>document.querySelector('#stream').srcObject=e.streams[0];
peer.onicecandidate=e=>e.candidate&&socket.send(JSON.stringify({peer_id:'viewer',type:'ice_candidate',payload:e.candidate}));
socket.onopen=()=>socket.send(JSON.stringify({peer_id:'viewer',type:'join',payload:{role:'viewer'}}));
socket.onmessage=async e=>{const m=JSON.parse(e.data);if(m.type==='offer'){await peer.setRemoteDescription(m.payload);const answer=await peer.createAnswer();await peer.setLocalDescription(answer);socket.send(JSON.stringify({peer_id:'viewer',target_peer_id:m.peer_id,type:'answer',payload:answer}));state.textContent='Connected'}else if(m.type==='ice_candidate'&&m.peer_id!=='viewer'){await peer.addIceCandidate(m.payload)}};
</script></body></html>"#;

#[cfg(test)]
mod tests {
    use super::*;
    use async_trait::async_trait;
    use axum::{
        body::{Body, to_bytes},
        http::{Request, header},
    };
    use tower::ServiceExt;

    struct TestExecutor;

    #[async_trait]
    impl ActionExecutor for TestExecutor {
        async fn execute(
            &self,
            _action: &Action,
            _arguments: &Value,
        ) -> Result<String, system::ExecutorError> {
            Ok("test action executed".into())
        }
    }

    fn test_app() -> Router {
        app(AppState::with_executor(Arc::new(TestExecutor)))
    }

    #[tokio::test]
    async fn health_contract_is_stable() {
        let response = test_app()
            .oneshot(
                Request::builder()
                    .uri("/v1/health")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body(), 4096).await.unwrap();
        let value: Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(value["service"], "vivy-daemon");
        assert!(
            value["capabilities"]
                .as_array()
                .unwrap()
                .contains(&json!("webrtc"))
        );
    }

    #[tokio::test]
    async fn rejects_volume_outside_range() {
        let payload = json!({"request_id": Uuid::new_v4(), "action": "set_volume", "arguments": {"value": 101}});
        let response = test_app()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/v1/actions")
                    .header(header::CONTENT_TYPE, "application/json")
                    .body(Body::from(payload.to_string()))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn set_volume_updates_state() {
        let app = test_app();
        let payload = json!({"request_id": Uuid::new_v4(), "action": "set_volume", "arguments": {"value": 35}});
        let response = app
            .clone()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/v1/actions")
                    .header(header::CONTENT_TYPE, "application/json")
                    .body(Body::from(payload.to_string()))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::OK);
        let response = app
            .oneshot(
                Request::builder()
                    .uri("/v1/state")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let body = to_bytes(response.into_body(), 4096).await.unwrap();
        let value: Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(value["volume"], 35);
    }
}
