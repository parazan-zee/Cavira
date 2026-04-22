import Photos
import SwiftUI
import UIKit

enum CameraCaptureResult {
    case cancelled
    case savedAsset(localIdentifier: String)
}

/// Uses `UIImagePickerController` camera to capture photo/video, then explicitly saves into Photos
/// and returns the new asset's `localIdentifier`.
struct CameraCaptureView: UIViewControllerRepresentable {
    var onComplete: (CameraCaptureResult) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image", "public.movie"]
        picker.videoQuality = .typeHigh
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onComplete: (CameraCaptureResult) -> Void

        init(onComplete: @escaping (CameraCaptureResult) -> Void) {
            self.onComplete = onComplete
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onComplete(.cancelled)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                saveImageToPhotos(image)
                return
            }
            if let url = info[.mediaURL] as? URL {
                saveVideoToPhotos(url)
                return
            }
            onComplete(.cancelled)
        }

        private func saveImageToPhotos(_ image: UIImage) {
            var placeholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetCreationRequest.forAsset()
                req.addResource(with: .photo, data: image.jpegData(compressionQuality: 0.95) ?? Data(), options: nil)
                placeholder = req.placeholderForCreatedAsset
            }, completionHandler: { [onComplete] success, _ in
                DispatchQueue.main.async {
                    guard success, let id = placeholder?.localIdentifier else {
                        onComplete(.cancelled)
                        return
                    }
                    onComplete(.savedAsset(localIdentifier: id))
                }
            })
        }

        private func saveVideoToPhotos(_ url: URL) {
            var placeholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetCreationRequest.forAsset()
                req.addResource(with: .video, fileURL: url, options: nil)
                placeholder = req.placeholderForCreatedAsset
            }, completionHandler: { [onComplete] success, _ in
                DispatchQueue.main.async {
                    guard success, let id = placeholder?.localIdentifier else {
                        onComplete(.cancelled)
                        return
                    }
                    onComplete(.savedAsset(localIdentifier: id))
                }
            })
        }
    }
}

