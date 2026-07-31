use std::net::SocketAddr;

use tokio::net::TcpListener;
use tracing::info;
use tracing_subscriber::EnvFilter;
use vivy_daemon::{AppState, app};

#[tokio::main]
async fn main() -> std::io::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "vivy_daemon=info,tower_http=info".into()),
        )
        .init();

    let address: SocketAddr = std::env::var("VIVY_BIND")
        .unwrap_or_else(|_| "0.0.0.0:43821".to_owned())
        .parse()
        .expect("VIVY_BIND must be a valid socket address");
    let listener = TcpListener::bind(address).await?;
    info!(%address, "Vivy daemon listening");
    axum::serve(listener, app(AppState::default())).await
}
