# Research: Gemini CLI quota channel (Task 12 gate)

## Verdict: FAIL

On this machine, Gemini CLI (`gemini --version` → `0.50.0`) is configured for
**`gemini-api-key`** auth (`~/.gemini/settings.json` → `security.auth.selectedType`), not
OAuth "Login with Google". There is **no OAuth credential file** at all under `~/.gemini`
(no `oauth_creds.json`), and `~/.gemini/google_accounts.json` has `"active": null` — no
Google account is currently signed in. The one real, wired-up usage/quota RPC that exists
in gemini-cli's own source — `CodeAssistServer.retrieveUserQuota` — lives entirely on the
OAuth/Code-Assist path and requires exactly that missing credential plus a
server-assigned `cloudaicompanionProject`. The auth mode that **is** active here
(`gemini-api-key`, i.e. the raw Gemini Developer API / AI Studio key) has **no** proactive
usage/percent/reset endpoint anywhere in the CLI source — quota awareness for that path is
purely reactive, parsed out of 429/499/503 error bodies returned by real generation calls,
never queried ahead of time. Per the task's stated reality check, this is a legitimate FAIL,
not a forced one: criterion 1 fails (no credential file backs the currently active auth
mode), which makes criteria 2–3 unreachable without fabricating a credential or a fixture.
**Task 13 (live GeminiProvider adapter) should be skipped**, or re-scoped to require the
user to first complete `gemini` OAuth login (`Login with Google`), at which point this
doc's §2 reference notes describe the endpoint that would then apply.

---

## 1. Local credential state under `~/.gemini/`

Directory listing (`ls -la ~/.gemini/`):

```
google_accounts.json
installation_id
projects.json
settings.json
state.json
trustedFolders.json
history/
skills/
tmp/
```

No `oauth_creds.json` (the file gemini-cli's own source uses for OAuth token storage —
see §2) is present anywhere under `~/.gemini`. No `GEMINI_API_KEY` / `GOOGLE_API_KEY` env
var is set in the shell (checked both the tool's default shell and a fresh `zsh -lc` login
shell), no `.env` in `$HOME` or the repo root, no `~/.config/gcloud/application_default_credentials.json`,
and no matching entry in the macOS login keychain (`security dump-keychain` filtered for
`gemini`/`google` service or account names — no hits).

Type-only probe of the two files that do carry auth-relevant state (values never printed —
only key names, JSON types, and, where explicitly non-secret, a labeled enum-like value):

`~/.gemini/settings.json` (relevant subtree only):

```json
{
  "security": {
    "auth": {
      "selectedType": "string(len 14)"   // observed value: "gemini-api-key"
    }
  }
}
```

`~/.gemini/google_accounts.json`:

```json
{
  "active": "NoneType",       // no account currently signed in
  "old": ["string(len 21)"]   // one previously-used account, no longer active
}
```

**Interpretation:** `selectedType: "gemini-api-key"` means this installation authenticates
generation calls to the plain Gemini Developer API (`generativelanguage.googleapis.com`)
using an API key, not the OAuth "Login with Google" flow that backs Gemini Code Assist
(`cloudcode-pa.googleapis.com`). Confirming this, `google_accounts.active` is `null` (no
signed-in Google account) and no `oauth_creds.json` exists. Wherever the actual API key
value lives (not found in env, `.env`, or keychain during this probe), it is immaterial to
this gate: the `gemini-api-key` auth path has no usage/quota RPC in the CLI source at all
(see §3), so no credential of any kind would unlock a quota endpoint for it.

## 2. The one real usage/quota RPC in gemini-cli's source (OAuth/Code-Assist path only)

Source: `packages/core/src/code_assist/server.ts` (`google-gemini/gemini-cli@main`,
found via `gh api search/code` for `retrieveUserQuota`, `RetrieveUserQuota`, `quota`,
`rate_limit`, `UserTierId`, `loadCodeAssist`):

```ts
export const CODE_ASSIST_ENDPOINT = 'https://cloudcode-pa.googleapis.com';
export const CODE_ASSIST_API_VERSION = 'v1internal';
...
async retrieveUserQuota(
  req: RetrieveUserQuotaRequest,
): Promise<RetrieveUserQuotaResponse> {
  return this.requestPost<RetrieveUserQuotaResponse>('retrieveUserQuota', req);
}
```

`requestPost` issues a **POST** to
`https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota` with an
`AuthClient`-signed `Authorization: Bearer <access_token>` header (from `google-auth-library`,
populated by the OAuth token cache — see below) and a JSON body `{ project: <projectId> }`.
This is called from `packages/core/src/config/config.ts`:

```ts
async refreshUserQuota(): Promise<RetrieveUserQuotaResponse | undefined> {
  const codeAssistServer = getCodeAssistServer(this);
  if (!codeAssistServer || !codeAssistServer.projectId) {
    return undefined;
  }
  const quota = await codeAssistServer.retrieveUserQuota({ project: codeAssistServer.projectId });
  ...
}
```

Response shape (`packages/core/src/code_assist/types.ts`):

```ts
export interface BucketInfo {
  remainingAmount?: string;
  remainingFraction?: number;   // 0.0–1.0, directly gives percent-remaining
  resetTime?: string;
  tokenType?: string;
  modelId?: string;
}
export interface RetrieveUserQuotaResponse {
  buckets?: BucketInfo[];
}
```

This RPC is real and used in production (not dead code) — `config.ts` parses
`remainingFraction`/`remainingAmount` into a `{ remaining, limit, resetTime }` map per
`modelId`, which feeds the CLI's own `QuotaDisplay.tsx` footer ("`NN% used (resets in ...)`").
Structurally, `BucketInfo` is a clean analogue to `QuotaLimit` (percent + reset time,
per-model instead of per-window), and **would** support a `GeminiProvider` if it were
reachable.

**Why it is not reachable from this machine, and why "reachable in general" still doesn't
flip the verdict:**

- `codeAssistServer.projectId` gates the call entirely (`if (!codeAssistServer.projectId) return undefined`).
  `projectId` only gets populated via the OAuth "Login with Google" onboarding flow
  (`packages/core/src/code_assist/setup.ts`, `doSetupUser`/`onboardUser`), which assigns
  even FREE-tier accounts a Google-managed `cloudaicompanionProject`. **This machine has
  never completed that OAuth flow** (§1), so no `projectId` — and thus no path to this
  RPC — exists locally regardless of the API key.
- The OAuth token itself would live at `Storage.getOAuthCredsPath()` →
  `~/.gemini/oauth_creds.json` (`packages/core/src/config/storage.ts`:
  `export const OAUTH_FILE = 'oauth_creds.json';`), written by
  `cacheCredentials()` in `packages/core/src/code_assist/oauth2.ts` as a standard
  `google-auth-library` `Credentials` object (`access_token`, `refresh_token`,
  `expiry_date`, `scope`, `token_type`, `id_token`). This file does not exist here, so
  there is no credential to probe or to sign a request with (criterion 1 is unmet for
  this endpoint specifically, on top of being unmet for the active auth mode overall).
- The call is a **POST**, not a GET — an RPC-over-HTTP convention Google uses broadly, and
  functionally read-only (no observed side effect beyond returning current quota state).
  The task's security mandate restricts reproduction to a single read-only **GET**, so even
  if a valid `oauth_creds.json` existed, reproducing this specific call would fall outside
  what this gate permits to attempt live. This is a secondary blocker, moot here since §1
  already rules out having a credential to call it with.

## 3. The active auth mode (`gemini-api-key`) has no usage/quota endpoint

Searching the same repo for `generativelanguage.googleapis.com` (the endpoint actually used
by `gemini-api-key` auth) turns up only the content-generation client, a live-transcription
provider, and error-classification code — no quota/usage RPC. The only "quota" handling for
this auth path is `packages/core/src/utils/googleQuotaErrors.ts`, which **classifies errors
after a real `generateContent` call fails**:

```ts
// 429/499/503 responses are parsed for Google RPC error details (QuotaFailure, ErrorInfo,
// RetryInfo) and turned into TerminalQuotaError / RetryableQuotaError.
// There is no endpoint queried in advance — this only fires reactively, mid-request.
```

`packages/cli/src/ui/hooks/useQuotaAndFallback.ts` confirms this is purely reactive: on a
`TerminalQuotaError` it shows a dialog ("`Usage limit reached for <model>`" / "`/stats model
for usage details`") and offers to switch models — it never calls a quota-query endpoint to
show a percentage ahead of time. `/stats` is local session-call counting, not a server quota
figure. This matches the task's stated reality check precisely: the free/API-key tier is
request-count/model-quota based with no percent-of-limit query endpoint.

**No fixture was captured.** There is no read-only GET (or any) endpoint reachable with the
credential actually present on this machine (`gemini-api-key`, no OAuth session), and the
one endpoint that would exist under OAuth (§2) is a POST gated behind a credential file that
does not exist here. Fabricating either would violate the task's explicit instruction not to
force a PASS.

## 4. Mapping table

Not produced — blocked upstream by §1–§3. No live response exists to map from. If a future
task re-attempts this gate against a machine that has completed `gemini` OAuth login
("Login with Google"), `BucketInfo.remainingFraction` (× 100 → percent used, i.e.
`(1 - remainingFraction) * 100`), `BucketInfo.resetTime`, and `BucketInfo.modelId` are the
fields to map to `QuotaLimit.percentUsed` / `QuotaLimit.resetsAt` / a per-model `LimitKind`
respectively — but that mapping is unverified against a real body and is not a substitute
for the required fixture.

## Credential/endpoint parity summary vs. Claude/Codex adapters

| | Claude (`ClaudeProvider`) | Codex (`CodexProvider`) | Gemini (this gate) |
|---|---|---|---|
| Credential file | `~/.claude/.credentials.json` (+ Keychain) | `~/.codex/auth.json` | `~/.gemini/oauth_creds.json` — **required for the only quota RPC found, but does not exist on this machine** |
| Active local auth mode | OAuth (Claude Max/Pro) | ChatGPT OAuth | `gemini-api-key` (no OAuth session; `google_accounts.active: null`) |
| Usage/quota endpoint | `GET https://api.anthropic.com/api/oauth/usage` | `GET https://chatgpt.com/backend-api/wham/usage` | `POST https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota` — OAuth/Code-Assist only, gated on a server-assigned `projectId`; **no equivalent exists for `gemini-api-key` auth** |
| Reproducible here | yes (PASS, Task 10/11) | yes (PASS, Task 10/11) | **no** — missing credential (this gate), plus method is POST and active auth mode has no endpoint at all |

**Result: FAIL. Task 13 is skipped** per the task brief's instruction, unless the user first
completes `gemini` OAuth login on this machine, in which case this gate should be re-run —
§2 documents exactly what the endpoint and response shape would then be.
