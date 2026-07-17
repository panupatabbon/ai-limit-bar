# Research: Codex CLI quota channel (Task 10 gate)

## Verdict: PASS

A read-only GET to `https://chatgpt.com/backend-api/wham/usage`, authenticated with the
`access_token` from `~/.codex/auth.json`, returns HTTP 200 with a JSON body containing
plan type and rate-limit window percentages/reset timestamps. This is structurally
equivalent to the existing `ClaudeUsageClient` → `UsageResponse` → `QuotaSnapshot` pipeline,
so a `CodexProvider` mirroring `Sources/AILimitBarKit/Providers/Claude/` is feasible.
Task 11 may proceed.

---

## 1. Credential file: `~/.codex/auth.json`

Read-only type probe (values never printed except two non-secret fields called out below):

```
python3 -c "import json; d=json.load(open(...)); print({k: type(v).__name__ for k,v in d.items()})"
```

```json
{
  "auth_mode": "string(len 7)",
  "OPENAI_API_KEY": "NoneType",
  "tokens": {
    "id_token": "string(len 2121)",
    "access_token": "string(len 1781)",
    "refresh_token": "string(len 196)",
    "account_id": "string(len 36)"
  },
  "last_refresh": "string(len 27)"
}
```

Non-secret values (safe to record — a mode label and an ISO timestamp, not credentials):
- `auth_mode`: `"chatgpt"`
- `last_refresh`: `"2026-07-16T02:19:33.175544Z"`

This matches `AuthDotJson` in the Codex CLI source verbatim
(`codex-rs/login/src/auth/storage.rs`, openai/codex@main):

```rust
pub struct AuthDotJson {
    pub auth_mode: Option<AuthMode>,
    #[serde(rename = "OPENAI_API_KEY")]
    pub openai_api_key: Option<String>,
    pub tokens: Option<TokenData>,
    pub last_refresh: Option<DateTime<Utc>>,
    pub agent_identity: Option<AgentIdentityStorage>,
    pub personal_access_token: Option<String>,
    pub bedrock_api_key: Option<BedrockApiKeyAuth>,
}
```

and `TokenData` (`codex-rs/login/src/token_data.rs`):

```rust
pub struct TokenData {
    pub id_token: IdTokenInfo,   // parsed from the id_token JWT
    pub access_token: String,   // JWT — this is the bearer token for API calls
    pub refresh_token: String,
    pub account_id: Option<String>,
}
```

**Key names + types only, for a future `CodexCredentials.parse`:**

| JSON path | type | needed for adapter |
|---|---|---|
| `auth_mode` | string (`"chatgpt"` observed) | sanity-check auth mode is ChatGPT-based, not API-key/bedrock |
| `tokens.access_token` | string (JWT) | `Authorization: Bearer <access_token>` |
| `tokens.account_id` | string (uuid-like) | optional `ChatGPT-Account-Id` header (see §2) |
| `tokens.id_token`, `tokens.refresh_token` | string (JWT / opaque) | **never read/used** — mirrors Claude adapter never touching `refreshToken` |
| `last_refresh` | string (ISO8601) | not needed by the adapter |

No expiry timestamp is stored in `auth.json` in the same explicit way Claude's
`expiresAt` is (the JWT's own `exp` claim carries it, but the adapter does not need to
decode it — a 401 from the endpoint is sufficient signal, same pattern as
`ClaudeUsageClient` mapping 401/403 → `QuotaError.tokenExpired`).

## 2. Endpoint (from Codex CLI's own open-source client)

Source: `codex-rs/backend-client/src/client/rate_limit_resets.rs` (openai/codex@main,
repo actively pushed as of 2026-07-16):

```rust
pub(super) async fn get_rate_limit_status(&self) -> Result<RateLimitStatusWithResetCredits> {
    let url = self.rate_limit_status_url();
    let req = self.http.get(&url).headers(self.headers());
    ...
}

fn rate_limit_status_url(&self) -> String {
    match self.path_style {
        PathStyle::CodexApi => format!("{}/api/codex/usage", self.base_url),
        PathStyle::ChatGptApi => format!("{}/wham/usage", self.base_url),
    }
}
```

`base_url` default (`codex-rs/core/src/config/mod.rs`):
```rust
chatgpt_base_url: cfg.chatgpt_base_url
    .unwrap_or("https://chatgpt.com/backend-api/".to_string()),
```

`PathStyle::from_base_url` selects `ChatGptApi` whenever the base URL contains
`/backend-api` — true for the default. So the **effective endpoint is**:

```
GET https://chatgpt.com/backend-api/wham/usage
```

Headers (`codex-rs/backend-client/src/client.rs`, `fn headers`):
```rust
h.insert(USER_AGENT, "codex-cli");
self.auth_provider.add_auth_headers(&mut h);   // Authorization: Bearer <access_token>
if let Some(acc) = &self.chatgpt_account_id {
    h.insert("ChatGPT-Account-Id", acc);        // optional
}
```
`Authorization: Bearer <access_token>` format confirmed against
`codex-rs/core/tests/suite/client.rs` assertions (e.g. `"Bearer Access Token"`,
`request_chatgpt_account_id`).

This is a single, plain GET — no body, no side effects — matching the Claude adapter's
`GET https://api.anthropic.com/api/oauth/usage` shape exactly.

## 3. Captured response (redacted fixture)

One read-only request was made:
```
curl -s "https://chatgpt.com/backend-api/wham/usage" \
  -H "Authorization: Bearer <access_token from auth.json>" \
  -H "ChatGPT-Account-Id: <account_id from auth.json>" \
  -H "User-Agent: codex-cli"
```
Result: `HTTP 200`. Body (secrets/PII redacted; numbers and structure are real):

```json
{
  "user_id": "REDACTED",
  "account_id": "REDACTED",
  "email": "REDACTED",
  "plan_type": "plus",
  "rate_limit": {
    "allowed": true,
    "limit_reached": false,
    "primary_window": {
      "used_percent": 0,
      "limit_window_seconds": 604800,
      "reset_after_seconds": 547005,
      "reset_at": 1784800646
    },
    "secondary_window": null
  },
  "code_review_rate_limit": null,
  "additional_rate_limits": null,
  "credits": {
    "has_credits": false,
    "unlimited": false,
    "overage_limit_reached": false,
    "balance": "0",
    "approx_local_messages": [0, 0],
    "approx_cloud_messages": [0, 0]
  },
  "spend_control": {
    "reached": false,
    "individual_limit": null
  },
  "rate_limit_reached_type": null,
  "promo": null,
  "rate_limit_reset_credits": {
    "available_count": 0,
    "applicable_available_count": 0
  }
}
```

**Note for Task 11:** the response includes `user_id`, `account_id`, `email` (PII) at the
top level. The real `CodexUsageClient`/`UsageResponse` decode step must only extract
`plan_type` and `rate_limit.*` — never log, store, or surface the identity fields, same
posture as `ClaudeCredentials.parse` deliberately never touching `refreshToken`.

This response schema matches the CLI's own generated OpenAPI models
(`codex-rs/codex-backend-openapi-models/src/models/rate_limit_status_payload.rs`,
`rate_limit_status_details.rs`, `rate_limit_window_snapshot.rs`):

```rust
pub struct RateLimitStatusPayload {
    pub plan_type: PlanType,                 // enum: guest/free/go/plus/pro/business/... 
    pub rate_limit: Option<Option<Box<RateLimitStatusDetails>>>,
    ...
}
pub struct RateLimitStatusDetails {
    pub allowed: bool,
    pub limit_reached: bool,
    pub primary_window: Option<Option<Box<RateLimitWindowSnapshot>>>,
    pub secondary_window: Option<Option<Box<RateLimitWindowSnapshot>>>,
}
pub struct RateLimitWindowSnapshot {
    pub used_percent: i32,          // 0-100
    pub limit_window_seconds: i32,  // window length, e.g. 18000 (5h) or 604800 (7d)
    pub reset_after_seconds: i32,
    pub reset_at: i32,              // unix epoch seconds
}
```

**Important quirk observed live:** unlike Claude's response (which tags each limit entry
with an explicit `kind: "session" | "weekly_all" | "weekly_scoped"`), Codex's
`primary_window`/`secondary_window` carry **no kind label** — only `limit_window_seconds`.
In the captured fixture, `primary_window.limit_window_seconds` is `604800` (7 days,
i.e. a **weekly** window) and `secondary_window` is `null` — this ChatGPT Plus account has
no distinct 5-hour session cap, only a rolling weekly one. A future `CodexProvider` must
classify session-vs-weekly by inspecting `limit_window_seconds` (e.g. `< 86400` →
session-like, `>= 86400` → weekly), not by trusting `primary`/`secondary` position.

## 4. Mapping table: response → `QuotaSnapshot`

(`Sources/AILimitBarKit/Core/Models.swift`: `QuotaSnapshot { planName, limits: [QuotaLimit], fetchedAt }`,
 `QuotaLimit { kind: LimitKind, percentUsed: Double, resetsAt: Date, isActive: Bool }`)

| Codex response field | Type | → AILimitBar field | Notes |
|---|---|---|---|
| `plan_type` | string enum (`plus`, `pro`, `business`, `enterprise`, ...) | `QuotaSnapshot.planName` | Mirror `ClaudeProvider.planName(for:)`: map to `"CODEX <PLAN>"` display string |
| `rate_limit.primary_window.limit_window_seconds` | int (seconds) | discriminator for `LimitKind` | `< 86400` → `.session`; `>= 86400` → `.weeklyAll` (no per-model `weeklyModel` analogue observed) |
| `rate_limit.primary_window.used_percent` | int 0-100 | `QuotaLimit.percentUsed` | cast to `Double`; already 0-100 like Claude's `percent` |
| `rate_limit.primary_window.reset_at` | int (unix epoch **seconds**) | `QuotaLimit.resetsAt` | `Date(timeIntervalSince1970: Double(reset_at))` — **not** milliseconds, and **not** an ISO8601 string like Claude's `resets_at`; a new `CodexDate`/direct epoch parse is needed (no `AnthropicDate.parse` reuse) |
| `rate_limit.secondary_window.*` | same shape as primary, nullable | second `QuotaLimit`, same discriminator | was `null` in this account's fixture (Plus plan, single weekly window); a Pro/Business account may populate both |
| `rate_limit.allowed` / `rate_limit.limit_reached` | bool | optional input to `QuotaLimit.isActive` | Claude's `isActive` marks which limit is currently binding; Codex's closest analogue is `limit_reached` (true once a window is fully consumed) — needs a design decision in Task 11, not blocking |
| `user_id`, `account_id`, `email` | string (PII) | **discard, never decode into any stored model** | present in the live response; must not be logged or surfaced, same posture as Claude adapter never touching `refreshToken` |
| `credits`, `spend_control`, `additional_rate_limits`, `code_review_rate_limit`, `promo`, `rate_limit_reset_credits` | various, mostly null for this plan | out of scope | not part of the session/weekly quota bar; ignore for `.toQuotaLimits()`-equivalent parsing |

## Credential/endpoint parity summary vs. Claude adapter

| | Claude (`ClaudeProvider`) | Codex (proposed `CodexProvider`) |
|---|---|---|
| Credential file | `~/.claude/.credentials.json` (+ Keychain) | `~/.codex/auth.json` |
| Token field | `claudeAiOauth.accessToken` | `tokens.access_token` |
| Endpoint | `GET https://api.anthropic.com/api/oauth/usage` | `GET https://chatgpt.com/backend-api/wham/usage` |
| Auth header | `Authorization: Bearer <token>` + `anthropic-beta` | `Authorization: Bearer <token>` (+ optional `ChatGPT-Account-Id`) |
| Expiry signal | `expiresAt` in credentials file (ms epoch) | none in file; rely on 401 from endpoint, same as Claude's 401/403 → `tokenExpired` fallback |
| Window kind signal | explicit `kind` string per entry | inferred from `limit_window_seconds` (no explicit label) |
| Reset time format | ISO8601 string | unix epoch integer (seconds) |

All four PASS criteria are met: (1) credential schema documented above, (2) a single
read-only GET endpoint identified and confirmed from CLI source, (3) a real captured
response with all PII/secrets redacted is included above, (4) the mapping table above
gives Task 11 everything needed to write `CodexCredentials`, `CodexUsageClient`,
`CodexUsageResponse`, and `CodexProvider`.
