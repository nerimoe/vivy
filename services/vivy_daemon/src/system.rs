use std::{collections::HashMap, path::PathBuf, process::Stdio};

use async_trait::async_trait;
use serde::Deserialize;
use serde_json::Value;
use tokio::process::Command;
use url::Url;

use crate::Action;

#[derive(Debug, Default, Deserialize)]
pub struct DaemonConfig {
    #[serde(default)]
    pub applications: HashMap<String, ConfiguredCommand>,
    #[serde(default)]
    pub shortcuts: HashMap<String, ConfiguredCommand>,
    #[serde(default)]
    pub allowed_url_hosts: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct ConfiguredCommand {
    pub program: String,
    #[serde(default)]
    pub args: Vec<String>,
}

impl DaemonConfig {
    pub fn load() -> Result<Self, ExecutorError> {
        let path = std::env::var_os("VIVY_CONFIG")
            .map(PathBuf::from)
            .or_else(|| {
                std::env::var_os("HOME")
                    .map(PathBuf::from)
                    .map(|home| home.join(".config/vivy/daemon.json"))
            });
        let Some(path) = path else {
            return Ok(Self::default());
        };
        if !path.exists() {
            return Ok(Self::default());
        }
        let bytes = std::fs::read(&path)
            .map_err(|error| ExecutorError(format!("cannot read {}: {error}", path.display())))?;
        serde_json::from_slice(&bytes)
            .map_err(|error| ExecutorError(format!("invalid {}: {error}", path.display())))
    }
}

#[derive(Debug)]
pub struct ExecutorError(pub String);

impl std::fmt::Display for ExecutorError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter.write_str(&self.0)
    }
}

#[async_trait]
pub trait ActionExecutor: Send + Sync {
    async fn execute(&self, action: &Action, arguments: &Value) -> Result<String, ExecutorError>;
}

pub struct SystemActionExecutor {
    config: DaemonConfig,
}

impl SystemActionExecutor {
    pub fn new(config: DaemonConfig) -> Self {
        Self { config }
    }

    async fn configured(
        &self,
        commands: &HashMap<String, ConfiguredCommand>,
        name: &str,
    ) -> Result<(), ExecutorError> {
        let command = commands
            .get(name)
            .ok_or_else(|| ExecutorError(format!("{name} is not configured")))?;
        run(&command.program, &command.args).await
    }

    async fn open_url(&self, value: &str) -> Result<(), ExecutorError> {
        let url =
            Url::parse(value).map_err(|error| ExecutorError(format!("invalid URL: {error}")))?;
        if !matches!(url.scheme(), "http" | "https") {
            return Err(ExecutorError("only HTTP and HTTPS URLs are allowed".into()));
        }
        let host = url
            .host_str()
            .ok_or_else(|| ExecutorError("URL has no host".into()))?;
        if !self
            .config
            .allowed_url_hosts
            .iter()
            .any(|allowed| allowed == host)
        {
            return Err(ExecutorError(format!("URL host {host} is not configured")));
        }
        #[cfg(target_os = "macos")]
        return run("/usr/bin/open", &[value.to_owned()]).await;
        #[cfg(target_os = "linux")]
        return run("xdg-open", &[value.to_owned()]).await;
        #[cfg(target_os = "windows")]
        return run(
            "rundll32",
            &["url.dll,FileProtocolHandler".into(), value.into()],
        )
        .await;
        #[allow(unreachable_code)]
        Err(ExecutorError(
            "open_url is unsupported on this platform".into(),
        ))
    }
}

#[async_trait]
impl ActionExecutor for SystemActionExecutor {
    async fn execute(&self, action: &Action, arguments: &Value) -> Result<String, ExecutorError> {
        match action {
            Action::LaunchApp => {
                let name = required_string(arguments, "app")?;
                self.configured(&self.config.applications, name).await?;
                Ok(format!("launched configured app {name}"))
            }
            Action::SendShortcut => {
                let name = required_string(arguments, "shortcut")?;
                self.configured(&self.config.shortcuts, name).await?;
                Ok(format!("sent configured shortcut {name}"))
            }
            Action::SetVolume => {
                let volume = arguments
                    .get("value")
                    .and_then(Value::as_u64)
                    .filter(|value| *value <= 100)
                    .ok_or_else(|| {
                        ExecutorError("set_volume requires value from 0 to 100".into())
                    })?;
                set_volume(volume as u8).await?;
                Ok(format!("volume set to {volume}"))
            }
            Action::MediaPlayPause => {
                media_play_pause().await?;
                Ok("media play/pause sent".into())
            }
            Action::LockComputer => {
                lock_computer().await?;
                Ok("computer locked".into())
            }
            Action::OpenUrl => {
                let url = required_string(arguments, "url")?;
                self.open_url(url).await?;
                Ok(format!("opened configured URL {url}"))
            }
        }
    }
}

fn required_string<'a>(arguments: &'a Value, name: &str) -> Result<&'a str, ExecutorError> {
    arguments
        .get(name)
        .and_then(Value::as_str)
        .filter(|value| !value.trim().is_empty())
        .ok_or_else(|| ExecutorError(format!("missing non-empty {name}")))
}

async fn run(program: &str, args: &[String]) -> Result<(), ExecutorError> {
    let status = Command::new(program)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .await
        .map_err(|error| ExecutorError(format!("failed to start {program}: {error}")))?;
    if status.success() {
        Ok(())
    } else {
        Err(ExecutorError(format!("{program} exited with {status}")))
    }
}

#[cfg(target_os = "macos")]
async fn set_volume(volume: u8) -> Result<(), ExecutorError> {
    run(
        "/usr/bin/osascript",
        &["-e".into(), format!("set volume output volume {volume}")],
    )
    .await
}

#[cfg(target_os = "linux")]
async fn set_volume(volume: u8) -> Result<(), ExecutorError> {
    run(
        "wpctl",
        &[
            "set-volume".into(),
            "@DEFAULT_AUDIO_SINK@".into(),
            format!("{volume}%"),
        ],
    )
    .await
}

#[cfg(target_os = "windows")]
async fn set_volume(_volume: u8) -> Result<(), ExecutorError> {
    Err(ExecutorError(
        "set_volume requires a Windows adapter".into(),
    ))
}

#[cfg(target_os = "macos")]
async fn media_play_pause() -> Result<(), ExecutorError> {
    run(
        "/usr/bin/osascript",
        &[
            "-e".into(),
            "tell application \"Music\" to playpause".into(),
        ],
    )
    .await
}

#[cfg(target_os = "linux")]
async fn media_play_pause() -> Result<(), ExecutorError> {
    run("playerctl", &["play-pause".into()]).await
}

#[cfg(target_os = "windows")]
async fn media_play_pause() -> Result<(), ExecutorError> {
    Err(ExecutorError(
        "media_play_pause requires a Windows adapter".into(),
    ))
}

#[cfg(target_os = "macos")]
async fn lock_computer() -> Result<(), ExecutorError> {
    run(
        "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession",
        &["-suspend".into()],
    )
    .await
}

#[cfg(target_os = "linux")]
async fn lock_computer() -> Result<(), ExecutorError> {
    run("loginctl", &["lock-session".into()]).await
}

#[cfg(target_os = "windows")]
async fn lock_computer() -> Result<(), ExecutorError> {
    run("rundll32", &["user32.dll,LockWorkStation".into()]).await
}
