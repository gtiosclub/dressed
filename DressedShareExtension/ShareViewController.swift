import ImageIO
import UIKit
import UniformTypeIdentifiers

private struct SharedImageEnvelope: Encodable {
    let id: String
    let ownerId: String
    let createdAt: Date
}

private struct SharedLinkEnvelope: Encodable {
    let id: String
    let ownerId: String
    let createdAt: Date
    let productURL: URL
}

final class ShareViewController: UIViewController {
    private let groupId = "group.gtiosclub.dressed"
    private let maxInputBytes = 40 * 1024 * 1024
    private let maxImageDimension: CGFloat = 2560
    private let status = UILabel()
    private let doneButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        status.text = "Preparing image…"
        status.numberOfLines = 0
        status.textAlignment = .center
        status.font = .preferredFont(forTextStyle: .headline)
        doneButton.setTitle("Done", for: .normal)
        doneButton.addTarget(self, action: #selector(finish), for: .touchUpInside)
        doneButton.isHidden = true

        let stack = UIStackView(arrangedSubviews: [status, doneButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 360)
        ])

        receiveShare()
    }

    private func receiveShare() {
        guard let ownerId = activeOwnerId else {
            show("Open Dressed and sign in, then share the image again.")
            return
        }
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        if let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }) {
            let imageTypes = provider.registeredTypeIdentifiers.filter {
                UTType($0)?.conforms(to: .image) == true
            }
            loadImage(from: provider, types: imageTypes, index: 0, ownerId: ownerId)
            return
        }
        if let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        }) {
            loadProductURL(from: provider, ownerId: ownerId)
            return
        }
        show("Share an image or a public HTTPS product link to Dressed.")
    }

    private func loadProductURL(from provider: NSItemProvider, ownerId: String) {
        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                let url = (item as? URL) ?? (item as? String).flatMap(URL.init(string:))
                guard let url, self.activeOwnerId == ownerId,
                      url.scheme?.lowercased() == "https", let host = url.host,
                      !host.isEmpty, url.user == nil, url.password == nil,
                      url.port == nil || url.port == 443 else {
                    self.show("Could not read a public HTTPS product link. Paste it in Dressed instead.")
                    return
                }
                do {
                    try self.queue(url, ownerId: ownerId)
                    self.show("Product link ready. Open Dressed to review it.")
                } catch {
                    self.show("Could not prepare this link. Paste it in Dressed instead.")
                }
            }
        }
    }

    private func queue(_ url: URL, ownerId: String) throws {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let links = root.appendingPathComponent("Links", isDirectory: true)
        try FileManager.default.createDirectory(at: links, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let record = SharedLinkEnvelope(id: id, ownerId: ownerId, createdAt: Date(), productURL: url)
        try JSONEncoder().encode(record).write(to: links.appendingPathComponent("\(id).json"), options: .atomic)
    }

    private func loadImage(from provider: NSItemProvider, types: [String], index: Int, ownerId: String) {
        guard index < types.count else {
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                showUnreadableImage()
                return
            }
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard let image = object as? UIImage, let jpeg = self.jpeg(from: image) else {
                        self.showUnreadableImage()
                        return
                    }
                    self.finishLoading(jpeg, ownerId: ownerId)
                }
            }
            return
        }

        let type = types[index]
        provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] fileURL, _ in
            // The provider owns this temporary file; read it before this callback returns.
            let data = fileURL.flatMap { self?.readImageFile(at: $0) }
            DispatchQueue.main.async {
                guard let self else { return }
                if let data, let jpeg = self.jpeg(from: data) {
                    self.finishLoading(jpeg, ownerId: ownerId)
                } else {
                    self.loadImageData(from: provider, types: types, index: index, ownerId: ownerId)
                }
            }
        }
    }

    private func loadImageData(from provider: NSItemProvider, types: [String], index: Int, ownerId: String) {
        provider.loadDataRepresentation(forTypeIdentifier: types[index]) { [weak self] data, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if let data, let jpeg = self.jpeg(from: data) {
                    self.finishLoading(jpeg, ownerId: ownerId)
                } else {
                    self.loadImage(from: provider, types: types, index: index + 1, ownerId: ownerId)
                }
            }
        }
    }

    private func readImageFile(at url: URL) -> Data? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= maxInputBytes else { return nil }
        return try? Data(contentsOf: url)
    }

    private func jpeg(from data: Data) -> Data? {
        guard !data.isEmpty, data.count <= maxInputBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxImageDimension)
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.85)
    }

    private func jpeg(from image: UIImage) -> Data? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = min(1, maxImageDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.jpegData(withCompressionQuality: 0.85) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private var activeOwnerId: String? {
        guard let id = UserDefaults(suiteName: groupId)?.string(forKey: "activeOwnerId"),
              !id.isEmpty else { return nil }
        return id
    }

    private func finishLoading(_ jpeg: Data, ownerId: String) {
        // Sign-out or an account switch while the provider is loading invalidates the share.
        guard activeOwnerId == ownerId else {
            show("Your Dressed account changed. Open Dressed and share the image again.")
            return
        }
        do {
            try queue(jpeg, ownerId: ownerId)
            show("Ready to review. Open Dressed to finish importing.")
        } catch {
            show("Could not prepare the image. Please try sharing it again.")
        }
    }

    private func queue(_ jpeg: Data, ownerId: String) throws {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let inbox = root.appendingPathComponent("Inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let imageURL = inbox.appendingPathComponent("\(id).jpg")
        let recordURL = inbox.appendingPathComponent("\(id).json")
        try jpeg.write(to: imageURL, options: .atomic)
        do {
            let envelope = SharedImageEnvelope(id: id, ownerId: ownerId, createdAt: Date())
            try JSONEncoder().encode(envelope).write(to: recordURL, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: imageURL)
            throw error
        }
    }

    private func showUnreadableImage() {
        show("Could not read this image. Try sharing a saved photo.")
    }

    private func show(_ message: String) {
        status.text = message
        doneButton.isHidden = false
    }

    @objc private func finish() {
        extensionContext?.completeRequest(returningItems: [])
    }
}
