import Photos
import PhotosUI
import SwiftUI
import UIKit

/// Wraps `PHPickerViewController` for images, Live Photos, and videos (reference import only).
struct PhotoPickerRepresentable: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onComplete: ([PHPickerResult]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .any(of: [.images, .livePhotos, .videos])
        configuration.selectionLimit = 0
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: PhotoPickerRepresentable

        init(_ parent: PhotoPickerRepresentable) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Dismiss the picker first, then deliver results on the next runloop.
            // This avoids sheet-presentation races when the caller immediately opens another sheet.
            parent.isPresented = false
            DispatchQueue.main.async {
                self.parent.onComplete(results)
            }
        }
    }
}
