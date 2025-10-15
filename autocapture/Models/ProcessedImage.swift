//
//  ProcessedImage.swift
//  autocapture
//
//  Created by Justin Collins on 10/14/25.
//

import Foundation
import SwiftData
import UIKit

@Model
final class ProcessedImage {
    var id: UUID
    var captureDate: Date
    @Attribute(.externalStorage) var imageData: Data
    
    init(image: UIImage, captureDate: Date = Date()) {
        self.id = UUID()
        self.captureDate = captureDate
        self.imageData = image.pngData() ?? Data()
    }
    
    var image: UIImage? {
        return UIImage(data: imageData)
    }
}


