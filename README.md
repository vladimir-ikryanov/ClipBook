# ClipBook

ClipBook is a clipboard manager for macOS.

## Requirements

- macOS 13.0 or later
- Xcode with the macOS SDK

## Development

To build ClipBook and launch it, run the following command in the root directory of the project:

```bash
./run.sh
```

The app is built into `DerivedData/Debug` and relaunched, replacing the instance
the script started previously. A copy installed in `/Applications` is left
running, so a rebuild never quits the ClipBook you use day to day.

Useful options:

| Option | Description |
| --- | --- |
| `--configuration NAME` | Build configuration. Default: `Debug`. |
| `--clean` | Clean the build before rebuilding. |
| `--build-only` | Build without launching the app. |
| `--foreground` | Run the app in the terminal, streaming its output. `Ctrl+C` quits. |
| `-h`, `--help` | Show all options. |

Build output is piped through [xcbeautify](https://github.com/cpisciotta/xcbeautify)
or [xcpretty](https://github.com/xcpretty/xcpretty) when either is installed, and
falls back to the raw `xcodebuild` log otherwise.

## Release

To build a signed and notarized release, run the following command in the root
directory of the project:

```bash
./release.sh --version 2.0.0
```

This archives a universal binary, packages it as a DMG, notarizes it, and updates
the Sparkle appcast under `Releases`. Notarization needs a `notarytool` keychain
profile; pass `--skip-notarization` to produce local artifacts without one. Run
`./release.sh --help` for the full list of options.
