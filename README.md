# ClipBook

ClipBook is a macOS clipboard history app that stores everything you copy and lets you quickly access your clipboard history.

## Why open source?

ClipBook is open source to provide transparency and trust for the users. I want you to be confident that there's no hidden logic, tracking, or behavior in the app. Privacy is important, and I want you to know that ClipBook respects your privacy.

You can analyze the source code and even build your own copy of the app using the instructions below.

**Note**: ClipBook remains a paid application. I rely on your support to continue development and maintenance. Purchasing a license helps me improve the app and offer ongoing support.

## Building ClipBook

You can build your own copy of ClipBook from the source code by following these steps:

### Prerequisites

- macOS Sonoma 14 or later.
- Install [Node.js](https://nodejs.org/en/download) version 20.11.0 or higher.
- Install [Command Line Tools](http://osxdaily.com/2014/02/12/install-command-line-tools-mac-os-x/).

**Note**: ClipBook is built using [MōBrowser](https://teamdev.com/mobrowser/docs/quick-start/), a commercial SDK for building cross-platform desktop applications using C++ and web technologies. You can use a [free 3-week trial](https://teamdev.com/mobrowser/#pricing) to build ClipBook.

### Getting the source code

```sh
git clone git@github.com:vladimir-ikryanov/ClipBook.git
cd ClipBook
```

### Installing dependencies

```sh
npm install
```

### Building ClipBook

```sh
npm run mobrowser build
```

This command will build and pack ClipBook into a native executable and place it in the project's `build-dist/bin` directory. It will also create a DMG installer in `build-dist/pack`.

**Note**: The application will not be signed and notarized. You can sign and notarize it using your own Apple developer certificate by following the instructions in the [MōBrowser SDK documentation](https://teamdev.com/mobrowser/docs/distribution/signing.html#macos). 

## License

ClipBook’s source code is provided for transparency and personal use. However, its use in commercial or redistributed products is restricted without a license. Please refer to the [LICENSE](LICENSE.md) file for details.

## Terms of Use

By using ClipBook, you agree to the [Terms of Use](https://clipbook.app/terms/) and [Privacy Policy](https://clipbook.app/privacy/).

## Support

For questions or support, please [contact me](mailto:vladimir.ikryanov@clipbook.app).
