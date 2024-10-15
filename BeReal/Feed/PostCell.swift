//
//  PostCell.swift
//  BeReal
//
//  Created by Tony Vazquez on 09/25/24.
//

import UIKit
import Alamofire
import AlamofireImage

class PostCell: UITableViewCell {

    @IBOutlet private weak var usernameLabel: UILabel!
    @IBOutlet private weak var postImageView: UIImageView!
    @IBOutlet private weak var captionLabel: UILabel!
    @IBOutlet private weak var dateLabel: UILabel!
    @IBOutlet weak var blurView: UIVisualEffectView!
    @IBOutlet weak var locationLabel: UILabel! // Added for displaying location

    private var imageDataRequest: DataRequest?

    func configure(with post: Post) {
        // Username
        if let user = post.user {
            usernameLabel.text = user.username
        }

        // Image
        if let imageFile = post.imageFile,
           let imageUrl = imageFile.url {
            
            // Use AlamofireImage helper to fetch remote image from URL
            imageDataRequest = AF.request(imageUrl).responseImage { [weak self] response in
                switch response.result {
                case .success(let image):
                    // Set image view image with fetched image
                    self?.postImageView.image = image
                case .failure(let error):
                    print("❌ Error fetching image: \(error.localizedDescription)")
                    break
                }
            }
        }

        // Show/hide the blur view based on post dates
        if let currentUser = User.current,
           let lastPostedDate = currentUser.lastPostedDate,
           let postCreatedDate = post.createdAt,
           let diffHours = Calendar.current.dateComponents([.hour], from: postCreatedDate, to: lastPostedDate).hour {

            // Hide the blur view if the post was created within 24 hours of the current user's last post
            blurView.isHidden = abs(diffHours) < 24
        } else {
            // Default to blur view if dates can't be computed
            blurView.isHidden = false
        }

        // Show location if available
        if let location = post.location {
            locationLabel.text = "Location: Lat \(location.latitude), Lon \(location.longitude)"
        } else {
            locationLabel.text = "Location not available"
        }

        // Show post creation date and time
        if let createdAt = post.createdAt {
            dateLabel.text = DateFormatter.localizedString(from: createdAt, dateStyle: .short, timeStyle: .short)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // Reset image view image.
        postImageView.image = nil

        // Cancel image request.
        imageDataRequest?.cancel()
    }
}
