//
//  PostViewController.swift
//  BeReal
//
//  Created by Tony Vazquez on 09/25/24.
//
import UIKit
import PhotosUI
import ParseSwift
import CoreLocation
import ImageIO

class PostViewController: UIViewController {

    // MARK: Outlets
    @IBOutlet weak var shareButton: UIBarButtonItem!
    @IBOutlet weak var captionTextField: UITextField!
    @IBOutlet weak var previewImageView: UIImageView!

    private var pickedImage: UIImage?
    private var currentLocation: CLLocationCoordinate2D?
    private var currentCityState: String?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func onPickedImageTapped(_ sender: UIBarButtonItem) {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.preferredAssetRepresentationMode = .current
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @IBAction func onShareTapped(_ sender: Any) {
        view.endEditing(true)

        guard let image = pickedImage,
              let imageData = image.jpegData(compressionQuality: 0.1) else {
            return
        }

        let imageFile = ParseFile(name: "image.jpg", data: imageData)
        var post = Post()
        post.imageFile = imageFile
        post.caption = captionTextField.text

        // Set location if available
        if let currentLocation = currentLocation {
            post.location = try? ParseGeoPoint(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        } else {
            print("Location not found")
        }

        post.user = User.current

        post.save { [weak self] result in
            switch result {
            case .success(let post):
                print("✅ Post Saved! \(post)")

                if var currentUser = User.current {
                    currentUser.lastPostedDate = Date()
                    currentUser.save { result in
                        switch result {
                        case .success(let user):
                            print("✅ User Saved! \(user)")
                            DispatchQueue.main.async {
                                self?.navigationController?.popViewController(animated: true)
                            }
                        case .failure(let error):
                            self?.showAlert(description: error.localizedDescription)
                        }
                    }
                }
            case .failure(let error):
                self?.showAlert(description: error.localizedDescription)
            }
        }
    }

    private func showAlert(description: String? = nil) {
        let alertController = UIAlertController(title: "Oops...", message: "\(description ?? "Please try again...")", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        present(alertController, animated: true)
    }

    // Helper method to extract GPS metadata
    private func extractMetadata(from asset: NSItemProvider) {
        asset.loadDataRepresentation(forTypeIdentifier: "public.jpeg") { [weak self] data, error in
            guard let imageData = data, error == nil else {
                print("Failed to load image data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            // Use ImageIO to extract metadata
            if let source = CGImageSourceCreateWithData(imageData as CFData, nil),
               let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
               let gpsData = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any] {

                if let latitude = gpsData[kCGImagePropertyGPSLatitude as String] as? Double,
                   let longitude = gpsData[kCGImagePropertyGPSLongitude as String] as? Double {
                    DispatchQueue.main.async {
                        self?.currentLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                        print("Location extracted from photo: \(latitude), \(longitude)")

                        // Perform reverse geocoding to get the address (city/state)
                        let location = CLLocation(latitude: latitude, longitude: longitude)
                        let geocoder = CLGeocoder()
                        geocoder.reverseGeocodeLocation(location) { placemarks, error in
                            if let error = error {
                                print("Reverse geocoding failed: \(error.localizedDescription)")
                            } else if let placemark = placemarks?.first {
                                let city = placemark.locality ?? "Unknown City"
                                let state = placemark.administrativeArea ?? "Unknown State"
                                self?.currentCityState = "\(city), \(state)"
                                print("Location: \(city), \(state)")
                            }
                        }
                    }
                }
            }
        }
    }
}

extension PostViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }
        
        // Load the selected image
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard let image = object as? UIImage else {
                self?.showAlert(description: error?.localizedDescription ?? "Error loading image")
                return
            }
            
            DispatchQueue.main.async {
                self?.previewImageView.image = image
                self?.pickedImage = image
            }
        }
        
        // Extract metadata including location data (if available)
        if provider.hasItemConformingToTypeIdentifier("public.jpeg") {
            extractMetadata(from: provider)
        }
    }
}
