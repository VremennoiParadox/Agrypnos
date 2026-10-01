import Foundation
import Darwin

enum OpenCodePluginSetupError: Error {
    case unsafePath, foreignFile, writeFailed, unsupportedConfiguration
}

// Descriptor-relative operations refuse symlinks, including each parent component.
enum OpenCodePrivateFiles {
    static func directory(_ url: URL, create: Bool = true, privateOnly: Bool = false) throws -> Int32 {
        guard url.isFileURL, url.path.hasPrefix("/"), !url.path.contains("\0") else {
            throw OpenCodePluginSetupError.unsafePath
        }
        var descriptor = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard descriptor >= 0 else { throw OpenCodePluginSetupError.unsafePath }
        do {
            for part in url.path.split(separator: "/") {
                let name = String(part)
                guard name != "..", name != "." else { throw OpenCodePluginSetupError.unsafePath }
                var next = openat(descriptor, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                if next < 0, errno == ENOENT, create {
                    guard mkdirat(descriptor, name, 0o700) == 0 else { throw OpenCodePluginSetupError.writeFailed }
                    next = openat(descriptor, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                }
                guard next >= 0 else { throw OpenCodePluginSetupError.unsafePath }
                close(descriptor)
                descriptor = next
            }
            var info = stat()
            guard fstat(descriptor, &info) == 0, info.st_uid == getuid(),
                  !privateOnly || info.st_mode & 0o077 == 0 else {
                throw OpenCodePluginSetupError.unsafePath
            }
            return descriptor
        } catch { close(descriptor); throw error }
    }

    static func read(_ url: URL) throws -> Data? {
        let parent = try directory(url.deletingLastPathComponent(), create: false)
        defer { close(parent) }
        let fd = openat(parent, url.lastPathComponent, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        if fd < 0, errno == ENOENT { return nil }
        guard fd >= 0 else { throw OpenCodePluginSetupError.unsafePath }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == getuid(),
              info.st_mode & S_IFMT == S_IFREG, info.st_size <= 262144 else {
            throw OpenCodePluginSetupError.unsafePath
        }
        let bytes = try handle.read(upToCount: 262145) ?? Data()
        guard bytes.count <= 262144 else { throw OpenCodePluginSetupError.unsafePath }
        return bytes
    }

    static func write(_ data: Data, to url: URL) throws {
        let parent = try directory(url.deletingLastPathComponent())
        defer { close(parent) }
        _ = try read(url)
        let temporary = ".agrypnos-" + UUID().uuidString
        let fd = openat(parent, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw OpenCodePluginSetupError.writeFailed }
        defer { close(fd); unlinkat(parent, temporary, 0) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        try handle.write(contentsOf: data)
        guard fsync(fd) == 0, renameat(parent, temporary, parent, url.lastPathComponent) == 0 else {
            throw OpenCodePluginSetupError.writeFailed
        }
    }

    static func remove(_ url: URL) throws {
        guard try read(url) != nil else { return }
        let parent = try directory(url.deletingLastPathComponent(), create: false)
        defer { close(parent) }
        guard unlinkat(parent, url.lastPathComponent, 0) == 0 else { throw OpenCodePluginSetupError.writeFailed }
    }
}
