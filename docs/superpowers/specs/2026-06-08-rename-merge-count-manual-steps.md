# Manual steps — "Merge Count" rebrand (out-of-scope of the code change)

These steps cannot be done by editing the repo alone — they involve secrets,
domain hosting, and external dashboards. Do them **after** the code rename lands.
Companion to `2026-06-08-rename-merge-count-design.md`.

Order: do **1 (keystore) first** — its SHA-256 fingerprint is required by
**2 (App Links)**.

---

## 1. Generate the new Android release keystore

The signing wiring already exists in `android/app/build.gradle.kts`: it loads
`android/key.properties` (gitignored) and signs release builds with it; if that
file is absent the release build falls back to debug signing. So you only need to
(a) create the keystore and (b) write `key.properties`.

### 1a. Create the keystore

Run from the repo root (Windows PowerShell). `keytool` ships with the JDK that
Android Studio/Flutter use; if `keytool` isn't on PATH, use the full path under
`...\Android\Android Studio\jbr\bin\keytool.exe`.

```powershell
keytool -genkey -v `
  -keystore android/merge_count-upload.jks `
  -storetype JKS `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias merge_count
```

It will prompt for a store password, a key password (press Enter to reuse the
store password), and a name/org. **Record both passwords in your password
manager** — losing them means you can never ship an update to this app once it's
on the Play Store.

> Keep `android/merge_count-upload.jks` OUT of git. Verify `*.jks` (or this path)
> is covered by `android/.gitignore`; add it if not.

### 1b. Write `android/key.properties`

Create `android/key.properties` (do **not** commit it) with the values you just
chose:

```properties
storePassword=<store password from 1a>
keyPassword=<key password from 1a>
keyAlias=merge_count
storeFile=merge_count-upload.jks
```

`storeFile` is resolved relative to the `android/` directory (the Gradle root
project), so the bare filename is correct.

### 1c. Verify signing works

```powershell
flutter build appbundle --release
```

A successful `.aab` under `build/app/outputs/bundle/release/` confirms the
keystore is wired.

### 1d. Capture the SHA-256 fingerprint (needed for step 2)

```powershell
keytool -list -v -keystore android/merge_count-upload.jks -alias merge_count
```

Copy the **SHA-256** line from the output — you'll paste it into
`assetlinks.json` below.

> If you plan to use **Google Play App Signing** (recommended), Google re-signs
> your app with a *different* key. After your first upload, take the SHA-256 that
> Play shows under **Setup → App signing**, and use *that* fingerprint in
> `assetlinks.json` instead of (or in addition to) your upload key's.

---

## 2. Host the domain association files for `mergecount.app`

The `mergecount://` custom scheme works with no domain. The **`https://`
invite-link fallback** (Android App Links + iOS Universal Links) only verifies
once `mergecount.app` serves two well-known files over HTTPS. Until then, https
invite links open in the browser instead of the app — not broken, just not deep
linked.

Prerequisite: you own `mergecount.app` and can serve static files at its root
over HTTPS (valid TLS cert, no redirects on the `.well-known` paths).

### 2a. Android — `assetlinks.json`

Serve at exactly:
`https://mergecount.app/.well-known/assetlinks.json`

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.kiddulu.merge_count",
      "sha256_cert_fingerprints": [
        "<SHA-256 from step 1d, colon-separated hex>"
      ]
    }
  }
]
```

Must be served as `Content-Type: application/json`, HTTP 200, no redirect.
Verify with Google's tester:
`https://developers.google.com/digital-asset-links/tools/generator`

### 2b. iOS — `apple-app-site-association`

Serve at exactly (note: **no** `.json` extension):
`https://mergecount.app/.well-known/apple-app-site-association`

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "<TEAMID>.com.kiddulu.mergeCount",
        "paths": ["/invite/*"]
      }
    ]
  }
}
```

`<TEAMID>` is your Apple Developer Team ID (Apple Developer portal →
Membership). Served as `application/json`, HTTP 200, no redirect.

### 2c. iOS — add the Associated Domains entitlement

In Xcode: **Runner target → Signing & Capabilities → + Capability → Associated
Domains**, then add:

```
applinks:mergecount.app
```

This writes an entitlement / `Runner.entitlements`. Commit that file. (Android's
side is already declared by the `https`/`mergecount.app` intent filter in
`AndroidManifest.xml` from the code change.)

---

## 3. Rename the Supabase project

The repo's `supabase/config.toml` `project_id` is only the **local linked-project
label** — changing it (done in the code step) does not rename anything in the
cloud.

To rename the actual project (cosmetic; the project **ref** / API URL does not
change):
1. Supabase Dashboard → your project → **Settings → General → Project name** →
   set to `merge_count` (or `Merge Count`) → Save.
2. The project ref, database, and `SUPABASE_URL` stay the same, so **no `.env`
   change is required**.

If you ever re-link the CLI: `supabase link --project-ref <unchanged-ref>`.

---

## 4. (Optional) Rename the repo folder

Purely cosmetic — nothing in the build depends on the folder name.
1. Close any editor/terminal holding the directory open.
2. Rename `C:\Users\dat1k\Projects\merge_loop` →
   `C:\Users\dat1k\Projects\merge_count` in Explorer (or
   `Rename-Item merge_loop merge_count`).
3. Reopen the project from the new path. Git history and the remote are
   unaffected.

---

## Checklist

- [ ] 1. Keystore generated, passwords saved, `key.properties` written, `.jks`
      gitignored, release `.aab` builds.
- [ ] 1d. SHA-256 fingerprint captured.
- [ ] 2a. `assetlinks.json` live and passing Google's tester.
- [ ] 2b. `apple-app-site-association` live with correct Team ID.
- [ ] 2c. Associated Domains entitlement added in Xcode and committed.
- [ ] 3. Supabase project renamed in dashboard.
- [ ] 4. (Optional) Repo folder renamed.
