# Security and AI keys

Mahzaidex Tech / Hasnain Zaidi.

## Credentials

AI keys are personal to the signed-in account. OpenAI and Google Gemini are supported. Server-side AES-256-GCM encryption uses a random nonce and binds ciphertext to the account/provider record. The client can save, replace or remove a key, but cannot retrieve its plaintext; the UI shows a fixed mask. Keys are excluded from general settings/sync responses and Excel reference exports. Provider requests execute on the server with keys in headers, never URL query strings. Provider error bodies and request payloads are not logged or returned.

The first saved key creates a private 32-byte `.assetflow-ai.key` beside the active database. `AI_KEY_FILE` can select another persistent path, or `AI_KEY_ENCRYPTION_KEY` can supply a 32-byte base64 secret through the process environment. Never commit these secrets or expose the server without HTTPS. Do not change/delete the encryption key while encrypted credentials exist.

Full-state backups contain encrypted credentials, not the master encryption key. Back up that key separately and securely. Restoring a snapshot containing AI credentials verifies decryption before changing any data and rejects the restore when the correct key is unavailable.

The old Android plaintext Gemini key is removed from local settings on upgrade; enter it again under AI API Keys. Provider requests require the user's consent. Inventory analysis sends aggregate counts by status/category, not names, account data or credentials. Image analysis sends the chosen photo. AI suggestions never execute database changes automatically. Costs, model access and retention are governed by the user's provider account.

Implementation references: [OpenAI Responses API](https://developers.openai.com/api/reference/resources/responses/methods/create) and [Gemini generateContent](https://ai.google.dev/api/generate-content).

## Authorization and deployment

Every authenticated request checks the account's current active status and role. Administrator tools also check the database directly. Reports, scrap operations, backups, restore and permanent deletion are administrator-only. Importing Excel is administrator-only because it can change accounts. Keep a strong, persistent `JWT_SECRET` outside source control and preserve it across redeployments. The application has no built-in production JWT signing secret.

Protect backup directories and HTTPS configuration as described in [INSTALLATION.md](INSTALLATION.md). The current Android project retains its existing debug signing configuration for compatibility with already installed copies. A public-store distribution should use a protected release signing key, with an explicit migration plan for installations signed by a different key.
