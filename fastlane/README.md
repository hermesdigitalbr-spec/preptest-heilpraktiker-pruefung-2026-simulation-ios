fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios ensure_bundle_id

```sh
[bundle exec] fastlane ios ensure_bundle_id
```

Ensure Bundle ID exists with Sign in with Apple + IAP capabilities

### ios create_app

```sh
[bundle exec] fastlane ios create_app
```

Create the app listing on App Store Connect (first-time only)

### ios build

```sh
[bundle exec] fastlane ios build
```

Build and archive for App Store distribution

### ios setup_signing

```sh
[bundle exec] fastlane ios setup_signing
```

Create app group + widget bundle id and enable App Groups (portal, Apple ID session)

### ios upload_build

```sh
[bundle exec] fastlane ios upload_build
```

Upload the built IPA to ASC (no metadata, no submit)

### ios upload_binary

```sh
[bundle exec] fastlane ios upload_binary
```

Upload the built IPA binary only (TestFlight transporter, no metadata)

### ios submit_review

```sh
[bundle exec] fastlane ios submit_review
```

Submit version 1.0 / build 1 for App Store review

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight for internal testing

### ios set_metadata

```sh
[bundle exec] fastlane ios set_metadata
```

Push metadata and screenshots to ASC (no binary upload)

### ios push_metadata_text

```sh
[bundle exec] fastlane ios push_metadata_text
```

Push text metadata + categories + legal URLs (no screenshots, no binary)

### ios release

```sh
[bundle exec] fastlane ios release
```

Build, upload, and submit for App Store review

### ios asc_bundles

```sh
[bundle exec] fastlane ios asc_bundles
```

Inspect emt bundle ids and any app using them

### ios create_trials

```sh
[bundle exec] fastlane ios create_trials
```

Add free-trial introductory offers to the EMT subscriptions

### ios asc_find

```sh
[bundle exec] fastlane ios asc_find
```

List all apps and bundle ids

### ios asc_status

```sh
[bundle exec] fastlane ios asc_status
```

Print app version and build processing state

### ios relaunch_v1

```sh
[bundle exec] fastlane ios relaunch_v1
```

Attach build 3 + push purple screenshots/metadata to v1.0 (no submit)

### ios asc_set_build

```sh
[bundle exec] fastlane ios asc_set_build
```

Attach build 3 to v1.0

### ios asc_clear_shots

```sh
[bundle exec] fastlane ios asc_clear_shots
```

Delete all screenshot sets on v1.0

### ios asc_dedup

```sh
[bundle exec] fastlane ios asc_dedup
```

De-dup every screenshot set on v1.0 and print final fileName lists

### ios asc_shots

```sh
[bundle exec] fastlane ios asc_shots
```

Print screenshot counts per display type for v1.0

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
