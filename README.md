# Adium Chat Transcript Viewer

A read-only, native macOS viewer for Adium's chat transcript logs — for browsing old conversations without Adium installed.

## Download

Grab `AdiumLogViewer-<version>-macOS.zip` from the [Releases](https://github.com/kkirby/adium-log-viewer/releases) page (universal: Apple Silicon + Intel, macOS 15+). The app is ad-hoc signed but not notarized, so on first launch right-click it and choose **Open**, or run `xattr -dr com.apple.quarantine AdiumLogViewer.app`.

## Running from source

Open `Package.swift` in Xcode (or run from the terminal):

```
swift run
```

Or build and run the debug binary directly:

```
swift build
.build/debug/AdiumLogViewer
```

On first launch it looks for `~/Library/Application Support/Adium 2.0/Users/*/Logs`; if not found, use **Choose Logs Folder…** (Cmd-O) to point it at wherever your Adium logs live.

## Packaging & releases

```
scripts/package-app.sh 1.2.3   # -> dist/AdiumLogViewer.app + dist/AdiumLogViewer-1.2.3-macOS.zip
```

CI builds and tests every push and PR. Pushing a `v*` tag (e.g. `git tag v1.2.3 && git push origin v1.2.3`) runs the release workflow, which packages the app and publishes a GitHub release with the zip attached.

## Testing

```
swift test
```

## Notes / known limitations

- Both the modern XML `.chatlog` format (bundle directory or flat file) and legacy `.html`/`.html.bak`/`.AdiumHTMLLog` transcripts are supported. Legacy HTML logs predate Adium's structured log format and have no reliable per-message markup to parse (confirmed against Adium's own log viewer and Spotlight importer, which treat them the same way) — each is rendered as a single captured HTML document rather than a list of individually-parsed messages, so it looks like whatever message style was active when it was written rather than matching the styling of newer transcripts.
- Contact/account folder names are shown as-is from disk; Adium's filename sanitization is not reversed, so names containing characters like `/` will appear sanitized.
- Search does a raw substring scan of each log's XML text, so a query that happens to span an HTML tag boundary can miss a match.
- No app icon yet. `scripts/package-app.sh` wraps the release binary in a minimal `.app` bundle (Info.plist only), so it has no custom Dock icon.
