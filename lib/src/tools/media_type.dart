/// Media category used to filter [MediaManagerPlatform.getMediaPage] queries.
///
/// Maps 1-to-1 with the `type` argument accepted by the Android
/// `MediaStoreScanner` and the equivalent iOS/macOS PHAsset filter.
///
/// [archive] covers zip / rar / 7z / tar / apk and other package formats.
/// On Android these are resolved with a file-system scan because MediaStore
/// does not index archives on most devices (especially Android 13+).
enum MediaType { image, video, audio, document, archive, any }
