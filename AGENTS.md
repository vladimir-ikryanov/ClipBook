---
description: 
alwaysApply: true
---

Here's a list of rules you should follow when writing code:

- When you write a feature or fix a bug, you should always build the code to make sure there's no compilation and build errors.
- When running `xcodebuild`, request unsandboxed execution up front because Xcode and SwiftPM may need to read or write caches, logs, and package diagnostics under `~/Library` outside the workspace. If a sandboxed build fails with `Operation not permitted` in SwiftPM or Xcode cache/log paths, rerun the same build command without the sandbox.
- When you fix some bug or apply some changes, you should build and run the app when you finish. Developer should be able to test the app with the applied changes manually without the need to build and run the app manually.