//
//  CIImage+FaceDetection.swift
//  faceIT
//
//  Created by Michael Ruhl on 31.07.17.
//  Copyright © 2017 NovaTec GmbH. All rights reserved.
//

import Foundation
import Vision
import ARKit

public extension CIImage {
    
    var rotate: CIImage {
        get {
            return self.oriented(UIDevice.current.orientation.cameraOrientation())
        }
    }

    /// Cropping the image containing the face.
    ///
    /// - Parameter toFace: the face to extract
    /// - Returns: the cropped image
    func cropImage(toFace face: VNFaceObservation) -> CIImage {
        let width = face.boundingBox.width * CGFloat(extent.size.width)
        let height = face.boundingBox.height * CGFloat(extent.size.height)
        let x = face.boundingBox.origin.x * CGFloat(extent.size.width)
        let y = face.boundingBox.origin.y * CGFloat(extent.size.height)
        
        let rect: CGRect
        let difference = abs(width - height)
        if width > height {
            rect = CGRect(x: x, y: y - (difference / 2), width: width, height: width)
        } else {
            rect = CGRect(x: x - (difference / 2), y: y, width: height, height: height)
        }
        
        //let increasedRect = rect.insetBy(dx: width * -percentage, dy: height * -percentage)
        return self.cropped(to: rect)
    }
}

extension UIImage {
    public func resizeToBoundingSquare(_ boundingSquareSideLength : CGFloat) -> UIImage {
        let imgScale = self.size.width > self.size.height ? boundingSquareSideLength / self.size.width : boundingSquareSideLength / self.size.height
        let newWidth = self.size.width * imgScale
        let newHeight = self.size.height * imgScale
        let newSize = CGSize(width: newWidth, height: newHeight)
        UIGraphicsBeginImageContext(newSize)
        self.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage!
    }
}

private extension UIDeviceOrientation {
    func cameraOrientation() -> CGImagePropertyOrientation {
        switch self {
        case .landscapeLeft: return .up
        case .landscapeRight: return .down
        case .portraitUpsideDown: return .left
        default: return .right
        }
    }
}
