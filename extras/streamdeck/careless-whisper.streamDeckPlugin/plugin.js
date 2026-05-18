/// <reference path="libs/streamdeck.d.ts" />

/**
 * Careless Whisper — Stream Deck plugin runtime.
 *
 * Each action posts a JSON payload to the Careless Whisper HTTP server
 * (default: http://127.0.0.1:12138/) and reports success or failure via
 * the Stream Deck SDK's showOk / showAlert feedback.
 *
 * Transport: HTTP POST, Content-Type: application/json
 * Optional auth: set X-StreamDeck-Secret header when a shared secret is
 * configured in the Godot app (ProjectSettings → streamdeck/secret).
 */

const DEFAULT_PORT = 12138;
const DEFAULT_HOST = "127.0.0.1";

/** Action UUID constants — must match manifest.json. */
const ACTION = {
  START_RECORDING: "com.clawffice.carelesswhisper.startrecording",
  STOP_RECORDING:  "com.clawffice.carelesswhisper.stoprecording",
  TOGGLE_MUTE:     "com.clawffice.carelesswhisper.togglemute",
  LOAD_MODEL:      "com.clawffice.carelesswhisper.loadmodel",
  NOTIFY:          "com.clawffice.carelesswhisper.notify",
};

/**
 * Build the server URL from settings stored on the action instance.
 * Falls back to localhost:12138 when settings are absent or empty.
 *
 * @param {object} settings - Per-action settings from Stream Deck.
 * @returns {string} Full URL including trailing slash.
 */
function serverUrl(settings) {
  const port   = (settings && settings.port)   || DEFAULT_PORT;
  const host   = (settings && settings.host)   || DEFAULT_HOST;
  return `http://${host}:${port}/`;
}

/**
 * Send a JSON payload to the Careless Whisper HTTP server.
 *
 * @param {object} settings  - Per-action settings (port, host, secret).
 * @param {object} payload   - Request body; must include an "action" key.
 * @returns {Promise<object>} Parsed JSON response body.
 */
async function postAction(settings, payload) {
  const headers = { "Content-Type": "application/json" };
  if (settings && settings.secret) {
    headers["X-StreamDeck-Secret"] = settings.secret;
  }

  const response = await fetch(serverUrl(settings), {
    method:  "POST",
    headers: headers,
    body:    JSON.stringify(payload),
  });

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }

  return response.json();
}

// ---------------------------------------------------------------------------
// Stream Deck SDK entry point
// ---------------------------------------------------------------------------

$SD.onConnected(({ actionInfo, appInfo, connection, messageType, port, uuid }) => {
  console.log("[careless-whisper] plugin connected", uuid);
});

// ---------------------------------------------------------------------------
// keyDown handlers — one per action UUID
// ---------------------------------------------------------------------------

$SD.onKeyDown(ACTION.START_RECORDING, async ({ action, context, device, event, payload }) => {
  try {
    await postAction(payload.settings, { action: "start_recording" });
    $SD.showOk(context);
  } catch (err) {
    console.error("[careless-whisper] start_recording error:", err.message);
    $SD.showAlert(context);
  }
});

$SD.onKeyDown(ACTION.STOP_RECORDING, async ({ action, context, device, event, payload }) => {
  try {
    await postAction(payload.settings, { action: "stop_recording" });
    $SD.showOk(context);
  } catch (err) {
    console.error("[careless-whisper] stop_recording error:", err.message);
    $SD.showAlert(context);
  }
});

$SD.onKeyDown(ACTION.TOGGLE_MUTE, async ({ action, context, device, event, payload }) => {
  try {
    await postAction(payload.settings, { action: "toggle_mute" });
    $SD.showOk(context);
  } catch (err) {
    console.error("[careless-whisper] toggle_mute error:", err.message);
    $SD.showAlert(context);
  }
});

$SD.onKeyDown(ACTION.LOAD_MODEL, async ({ action, context, device, event, payload }) => {
  const model = (payload.settings && payload.settings.model) || "tiny.en";
  try {
    await postAction(payload.settings, { action: "load_model", model });
    $SD.showOk(context);
  } catch (err) {
    console.error("[careless-whisper] load_model error:", err.message);
    $SD.showAlert(context);
  }
});

$SD.onKeyDown(ACTION.NOTIFY, async ({ action, context, device, event, payload }) => {
  const message = (payload.settings && payload.settings.message) || "";
  try {
    await postAction(payload.settings, { action: "notify", message });
    $SD.showOk(context);
  } catch (err) {
    console.error("[careless-whisper] notify error:", err.message);
    $SD.showAlert(context);
  }
});

// ---------------------------------------------------------------------------
// Settings change — update action title to reflect current config
// ---------------------------------------------------------------------------

$SD.onDidReceiveSettings(ACTION.LOAD_MODEL, ({ context, payload }) => {
  const model = (payload.settings && payload.settings.model) || "tiny.en";
  $SD.setTitle(context, model);
});

$SD.onDidReceiveSettings(ACTION.NOTIFY, ({ context, payload }) => {
  const msg = (payload.settings && payload.settings.message) || "";
  const label = msg.length > 12 ? msg.slice(0, 12) + "…" : msg;
  $SD.setTitle(context, label || "Notify");
});
