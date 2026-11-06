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

### Tests

To run the test suite:

```bash
./test.sh
```

Options:

| Option | Description |
| --- | --- |
| `--filter IDENTIFIER` | Run only the given test suite or test, for example `DomainAndSensitiveContentTests`. Repeat to run several. A suite inside another type is named by its path, as in `DomainAndSensitiveContentTests/SensitiveContentTests`, and a single test needs its parentheses, as in `Suite/test()`. The run fails when an identifier matches no test. |
| `--no-parallel` | Run tests serially. |
| `--clean` | Clean the build before running. |
| `--record-snapshots` | Re-record the reference images in `ClipBookTests/Snapshots`. |
| `-h`, `--help` | Show all options. |

Set `RESULT_BUNDLE_PATH=PATH` to write the `.xcresult` bundle, including test
attachments such as view snapshots, to `PATH`. The path must not exist yet.

The view snapshot tests compare rendered views with the reference images in
`ClipBookTests/Snapshots`. After an intentional UI change, run
`./test.sh --record-snapshots` (it re-records every image and reports each one
as a failure), review the image diff, and commit the new images. A snapshot that fails
attaches the rendered image, and a diff when the sizes match, to the test result. The images were recorded
on macOS 27.2; another macOS release can render text and controls slightly
differently, which the attached diff shows.

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
