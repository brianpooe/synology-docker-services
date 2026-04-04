module.exports = {
    // Substituted from .env by setup-node-red.sh — do not edit the appdata copy directly.
    // If this changes, all saved credentials (HA token, etc.) become unreadable.
    credentialSecret: '{{NODE_RED_CREDENTIAL_SECRET}}',

    editorTheme: {
        projects: {
            enabled: false
        }
    }
};
