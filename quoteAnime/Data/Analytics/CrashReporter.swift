import FirebaseCrashlytics

/// Non-fatals: failures the app recovers from silently but that we want to see in Crashlytics
/// (Android's `CrashReporter`). `source` groups them, like Android's `source` custom key.
enum CrashReporter {
    static func record(_ error: Error, source: String) {
        Crashlytics.crashlytics().record(error: error, userInfo: ["source": source])
    }
}
