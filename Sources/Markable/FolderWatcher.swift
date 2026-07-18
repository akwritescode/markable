import Foundation
import CoreServices

/// Recursive file-system watcher over a folder, built on FSEvents.
/// Events are coalesced (~0.3s latency) and delivered on the main actor.
final class FolderWatcher {
    private var streamRef: FSEventStreamRef?
    private let onChange: @MainActor @Sendable ([String]) -> Void

    init?(url: URL, onChange: @escaping @MainActor @Sendable ([String]) -> Void) {
        self.onChange = onChange

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, count, eventPaths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            let paths = (Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String]) ?? []
            let handler = watcher.onChange
            Task { @MainActor in handler(paths) }
        }

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            [url.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagUseCFTypes
                    | kFSEventStreamCreateFlagFileEvents
                    | kFSEventStreamCreateFlagNoDefer
            )
        ) else { return nil }

        streamRef = stream
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
    }

    deinit {
        if let streamRef {
            FSEventStreamStop(streamRef)
            FSEventStreamInvalidate(streamRef)
            FSEventStreamRelease(streamRef)
        }
    }
}
