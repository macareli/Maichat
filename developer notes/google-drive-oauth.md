# Google Drive backups — the OAuth client, and how to get one

`services/drive_client.dart` signs in with a **"Desktop app" OAuth client**,
PKCE, and a loopback listener (`http://127.0.0.1:<port>`). No custom URL scheme,
so no native plugin and no AGP-9 Kotlin hook. The only scopes asked for are
`https://www.googleapis.com/auth/drive.file` and `email`.

The flow is exercised against a loopback server in
`test/drive_client_test.dart`. A real OAuth client and account are needed to
verify the platform sign-in flow.

## Making the client (five console pages, once)

The console is redesigned constantly, so these deep links are the durable part —
they are the same five the app's Drive screen links to under
*Advanced ▸ Use my own Google client ▸ How to get them*.

1. **Project** — <https://console.cloud.google.com/projectcreate>
2. **Enable the Drive API** — <https://console.cloud.google.com/apis/library/drive.googleapis.com>
3. **Consent screen branding** (app name + a support email) —
   <https://console.cloud.google.com/auth/branding>
4. **Audience → External → Publish app** — <https://console.cloud.google.com/auth/audience>
5. **Credentials → OAuth client ID → Desktop app** —
   <https://console.cloud.google.com/apis/credentials>

Then either paste the two strings into the app (Settings ▸ Backups ▸ Export ▸
Google Drive ▸ Advanced) or build with them:

```
flutter build apk --release \
  --dart-define=MAICHAT_DRIVE_CLIENT_ID=…apps.googleusercontent.com \
  --dart-define=MAICHAT_DRIVE_CLIENT_SECRET=…
```

Build-time clients are supplied through the `DRIVE_CLIENT_ID` and
`DRIVE_CLIENT_SECRET` repository secrets; `.github/workflows/build-apk.yml`
passes them as Dart defines. Do not commit client configuration or account
credentials. With no defines, the app asks for a client entered in Settings.

`kBundledDriveClientId`/`kBundledDriveClientSecret` read those defines and are
empty otherwise. A build without defines has no bundled client. With a client
present, the Drive screen offers **Connect Google Drive**; otherwise it asks
for a client. `DriveClient.clientIdFor` prefers a client entered in Settings.
The stored grant does not identify the client that issued it; verify an existing
connection when changing client configuration and reconnect if required.

## OAuth and storage constraints

- **Testing status expires refresh tokens after 7 days**, and caps the app at 100
  allowlisted test users. A scheduled Drive backup therefore dies weekly until
  the consent screen is **Published**. Publishing is a button, not a review.
- **`drive.file` is non-sensitive** ([scope table](https://developers.google.com/workspace/drive/api/guides/api-specific-auth)),
  and `email` is a basic identity scope. So a *published but unverified* app has
  **no user cap and no "unverified app" danger screen** — verification is only
  about displaying your name and logo. Sensitive/restricted Drive scopes are the
  ones that can require review and a security assessment; this app requests
  neither sensitive nor restricted Drive scopes.
- **The support email on the consent screen is user-facing** — Google's words:
  "a support email address where users can contact you if they have questions
  about their consent". Whoever owns the client has that address shown to whoever
  signs in. The *developer contact* email is only Google → you.
- **Drive access is a checkbox** under granular permissions: a sign-in can
  succeed with it cleared. The token response's `scope` is checked for
  `drive.file` and the sign-in is rejected with a sentence that says so, rather
  than failing later with a bare 403.
- **An installed app's client secret is not confidential** (Google's own guidance
  for installed apps); PKCE protects the exchange. Holding both strings only lets
  someone ask a user to consent to an app that can see the files it creates.
- **Quotas apply to the OAuth project.** Check the current Google Drive quota
  and billing documentation when distributing a shared client or planning large
  backup and restore workloads.
- **Uploads are streamed** (`uploadFile` builds the `multipart/related` body from
  a file stream; `downloadToFile` streams the other way). A backup is far too
  large to hold in memory twice — see the note in `backup_codec.dart`.

## What only a real account can settle

Whether the browser on a phone follows the `http://127.0.0.1:<port>` redirect
back into the app, and whether the project's Drive API is enabled. Check both
with the configured client on a physical device.

If the browser lands on Google's `redirect_uri_mismatch` page instead of coming
back, compare the requested host with the client's allowed loopback redirect
configuration. `DriveClient.loopbackHost` controls whether the request uses
`127.0.0.1` or `localhost`; the request and configured client must agree.
