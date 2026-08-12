/// Media category used to filter [MediaManagerPlatform.getMediaPage] queries.
///
/// Maps 1-to-1 with the `type` argument accepted by the Android
/// `MediaStoreScanner` and the equivalent iOS/macOS PHAsset filter.
enum MediaType { image, video, audio, document, any }
