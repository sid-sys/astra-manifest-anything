# Building for iOS

Private. How the free iOS build works, and how to run it.

## Why it is set up this way

iOS only builds on macOS. On a private GitHub repo a macOS minute costs ten
times a normal one, so the build runs from a **public** repo, where runners are
free and unlimited. That public repo, `sid-sys/maya-ios-build`, holds **one
workflow and nothing else**. The app is fetched from this private repo for the
length of one build and is gone when it ends.

The source in `tool/public-repo/` is the master copy of what is in that repo.
Change it here, then copy the files across.

## Run a build

Actions → *iOS build* → *Run workflow* on `maya-ios-build`. Pick a branch, tag or
commit of this repo (default `master`). It must be **pushed** first — the build
reads GitHub, not your disk.

Or from a terminal: `gh workflow run ios.yml -R sid-sys/maya-ios-build -f ref=master`

## When a build fails

The public repo's logs are public, and a compile error prints the line of code
that caused it. So build output goes to files, and on failure it is uploaded as
an **encrypted** artifact. To read it:

```bash
gh run download <run-id> -R sid-sys/maya-ios-build -n build-logs-encrypted
openssl enc -d -aes-256-cbc -md sha256 -pass env:IOS_LOG_PASSPHRASE \
  -in build-logs.enc | tar -xzf -
```

`IOS_LOG_PASSPHRASE` is in `.env.local`. The same value is the `LOG_PASSPHRASE`
secret on the public repo.

## Secrets on the public repo

| Secret | What it is |
| --- | --- |
| `SOURCE_DEPLOY_KEY` | Private half of a **read-only** deploy key on this repo. Revoke it in this repo's Settings → Deploy keys. |
| `LOG_PASSPHRASE` | Encrypts the logs of a failed build. |

## What this build does not do yet

It compiles with `--no-codesign`. That proves the app builds for iOS. It does not
produce something Apple will accept. Signing and TestFlight upload need an Apple
Developer account, a distribution certificate, a provisioning profile and an App
Store Connect API key — all stored as secrets, never in a file.
