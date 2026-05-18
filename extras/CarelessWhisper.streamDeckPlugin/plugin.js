/* Careless Whisper StreamDeck plugin (minimal scaffold)
   This file is intentionally minimal: it registers the plugin socket handler
   required by the Stream Deck runtime. Actual action logic should send HTTP
   requests to the running Careless Whisper HTTP integration.
*/

function connectSocket(inPort, inUUID, inRegisterEvent, inInfo) {
    // No-op placeholder: the Stream Deck app will call this when loading the
    // plugin. Implementation can open websockets or forward events locally.
}

function disconnectSocket() {
    // Cleanup placeholder
}

// Exports are handled by the Stream Deck runtime when bundling the plugin.
