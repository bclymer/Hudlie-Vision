//
//  ViewController.swift
//  Hudlie Vision
//
//  Created by Brian Clymer on 10/15/18.
//  Copyright © 2018 Brian Clymer. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet private var sceneView: ARSCNView!
    
    private let faceDetectionQueue = DispatchQueue(label: "Face-Detection", qos: .userInteractive)
    private let model: VNCoreMLModel = try! VNCoreMLModel(for: faces_model().model)
    private let faceView = UIView()
    
    private var faceDetectionTimer: Timer?
    private var currentFaceNode: (FaceNode, String)?
    private var currentScanningNode: ScanningNode?
    private var isReady = false
    private var bounds: CGRect = CGRect(x: 0, y: 0, width: 0, height: 0)
    
    private var recentSamples = [VNClassificationObservation]()
    
    private var hudlieData = [String: [String: Any]]()
    
    private var tapCount = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let hudliesJsonUrl = Bundle.main.url(forResource: "hudlies", withExtension: "json") {
            if let data = try? Data(contentsOf: hudliesJsonUrl) {
                if let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) {
                    let arrayData = json as? [[String: Any]]
                    arrayData?.forEach {
                        hudlieData[($0["email"] as! String).lowercased()] = $0
                    }
                }
            }
        }
        
        faceView.layer.borderWidth = 2
        faceView.layer.borderColor = UIColor.yellow.cgColor
        faceView.isHidden = true
        self.sceneView.addSubview(faceView)
        
        // Set the view's delegate
        sceneView.delegate = self
        
        faceDetectionTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(detectFace), userInfo: nil, repeats: true)
        
        //self.sceneView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapToCreateFakeFace)))
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bounds = sceneView.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    @objc
    private func tapToCreateFakeFace() {
        faceDetectionQueue.async {
            let (direction, _) = self.getUserVector()
            if self.tapCount % 2 == 0 {
                NSLog("Adding fake scanner")
                self.addScanningOverlay(vector: direction)
            } else {
                NSLog("Adding fake data")
                self.addText(vector: direction, personId: "brian.clymer")
            }
            self.tapCount += 1
        }
    }
    
    @objc
    private func detectFace() {
        faceDetectionQueue.async {
            guard let frame = self.sceneView.session.currentFrame else {
                return
            }

            let image = CIImage(cvPixelBuffer: frame.capturedImage).rotate
            
            let faceRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
                guard let faces = request.results as? [VNFaceObservation], !faces.isEmpty else {
                    self.recentSamples.removeAll()
                    DispatchQueue.main.async {
                        self.faceView.isHidden = true
                        self.currentFaceNode?.0.parent.removeFromParentNode()
                        self.currentFaceNode = nil
                        self.currentScanningNode?.parent.removeFromParentNode()
                        self.currentScanningNode = nil
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.faceView.isHidden = false
                }
                guard let face = faces.first else {
                    return
                }
                
                let boundingBox = self.transformBoundingBox(face.boundingBox)
                
                DispatchQueue.main.async {
                    self.faceView.frame = boundingBox
                }
                
                let distance = (70 / Float(boundingBox.size.width))
                
                guard let worldCoord = self.normalizeWorldCoord(boundingBox, estimatedDistance: distance) else {
                    return
                }
                
                // If there isn't a current face node, add the scanning overlay.
                if self.currentFaceNode == nil {
                    self.addScanningOverlay(vector: worldCoord)
                }
                
                self.identifyFace(face: face, image: image, frame: frame, completion: { (classification) in
                    guard let classification = classification else { return }
                    self.addText(vector: worldCoord, personId: classification.identifier)
                })
            })
            let requestHandler = VNImageRequestHandler(ciImage: image, options: [:])
            do {
                try requestHandler.perform([faceRequest])
            } catch {
                print(error)
            }
        }
    }
    
    private func identifyFace(face: VNFaceObservation, image: CIImage, frame: ARFrame, completion: @escaping (VNClassificationObservation?) -> Void) {
        let request = VNCoreMLRequest(model: self.model, completionHandler: { request, error in
            guard error == nil else {
                print("ML request error: \(error!.localizedDescription)")
                return
            }

            guard let classifications = request.results as? [VNClassificationObservation] else {
                completion(nil)
                return
            }
            
            NSLog("Classifications \(classifications)")
            
            guard let classification = classifications.first else {
                completion(nil)
                return
            }
            
            self.recentSamples.append(classification)
            if self.recentSamples.count > 5 {
                self.recentSamples = Array(self.recentSamples.dropFirst())
            }
            
            var sampleRate = [String: Int]()
            self.recentSamples.forEach {
                if sampleRate[$0.identifier] == nil {
                    sampleRate[$0.identifier] = 1
                } else {
                    sampleRate[$0.identifier] = sampleRate[$0.identifier]! + 1
                }
            }
            
            let max = sampleRate.max(by: { (lhs, rhs) -> Bool in
                return lhs.value < rhs.value
            })!
            
            if max.value < 3 {
                completion(nil)
                return
            }
            
            let classificationMatch = self.recentSamples.first(where: { $0.identifier == max.key })
            
            completion(classificationMatch)
        })
        request.imageCropAndScaleOption = .scaleFit

        do {
            let pixel = image.cropImage(toFace: face)
            let uiImage = UIImage(ciImage: pixel)
            let resizedImage = uiImage.resizeToBoundingSquare(227)
            let finalImage = CIImage(cgImage: resizedImage.cgImage!)
            try VNImageRequestHandler(ciImage: finalImage, options: [:]).perform([request])
        } catch {
            print("ML request handler error: \(error.localizedDescription)")
        }
    }
    
    /// In order to get stable vectors, we determine multiple coordinates within an interval.
    ///
    /// - Parameters:
    ///   - boundingBox: Rect of the face on the screen
    /// - Returns: the normalized vector
    private func normalizeWorldCoord(_ boundingBox: CGRect, estimatedDistance: Float) -> SCNVector3? {
        
        var array: [SCNVector3] = []
        Array(0...5).forEach{_ in
            if let position = determineWorldCoord(boundingBox, estimatedDistance: estimatedDistance) {
                array.append(position)
            }
            usleep(17000) // .017 seconds, slightly longer than 1 frame.
        }
        
        if array.isEmpty {
            return nil
        }
        
        let estimatedPoint = SCNVector3.center(array)
        
        // Take estimated distance, take worldTransform of best estimate,
        // find direction of camera -> worldTransform, calculate that distance,
        // then create a point that uses our distance.
        
        let (_, position) = self.getUserVector()
        let directionFromCamera = estimatedPoint - position
        let distanceFromEstimatedPoint = position.distance(toVector: estimatedPoint)
        let distanceRatio = estimatedDistance / distanceFromEstimatedPoint
        let fixedDistanceEstimation = position + SCNVector3(
            directionFromCamera.x * distanceRatio,
            directionFromCamera.y * distanceRatio,
            directionFromCamera.z * distanceRatio
        )
        
        return fixedDistanceEstimation
    }
    
    
    /// Determine the vector from the position on the screen.
    ///
    /// - Parameter boundingBox: Rect of the face on the screen
    /// - Returns: the vector in the sceneView
    private func determineWorldCoord(_ boundingBox: CGRect, estimatedDistance: Float) -> SCNVector3? {
        let arHitTestResults = sceneView.hitTest(CGPoint(x: boundingBox.midX, y: boundingBox.midY), types: [.featurePoint])
        
        if let closestResult = arHitTestResults.first {
            return SCNVector3.positionFromTransform(closestResult.worldTransform)
        }
        return nil
    }
    
    private func addText(vector: SCNVector3, personId: String) {
        DispatchQueue.main.async {
            NSLog(personId)
            self.currentScanningNode?.parent.removeFromParentNode()
            self.currentScanningNode = nil
            if let currentFaceNode = self.currentFaceNode, currentFaceNode.1 == personId {
                currentFaceNode.0.parent.move(vector)
            } else {
                self.currentFaceNode?.0.parent.removeFromParentNode()
                let faceNode = SCNNode.faceNode(withPerson: self.hudlieData["\(personId)@hudl.com".lowercased()], position: vector)
                self.currentFaceNode = (faceNode, personId)
                self.sceneView.scene.rootNode.addChildNode(faceNode.parent)
                faceNode.animateDataIn()
            }
        }
    }
    
    private func addScanningOverlay(vector: SCNVector3) {
        DispatchQueue.main.async {
            self.currentFaceNode?.0.parent.removeFromParentNode()
            self.currentFaceNode = nil
            if let currentScanningNode = self.currentScanningNode {
                currentScanningNode.parent.move(vector)
            } else {
                let scanningNode = SCNNode.scanningNode(position: vector)
                self.currentScanningNode = scanningNode
                self.sceneView.scene.rootNode.addChildNode(scanningNode.parent)
                scanningNode.startScanning()
            }
        }
    }
    
    func getUserVector() -> (SCNVector3, SCNVector3) { // (direction, position)
        if let frame = self.sceneView.session.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform) // 4x4 transform matrix describing camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33) // orientation of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43) // location of camera in world space
            
            return (dir, pos)
        }
        return (SCNVector3(0, 0, -1), SCNVector3(0, 0, -0.2))
    }
    
    /// Transform bounding box according to device orientation
    ///
    /// - Parameter boundingBox: of the face
    /// - Returns: transformed bounding box
    private func transformBoundingBox(_ boundingBox: CGRect) -> CGRect {
        // the camera is doing 4:3 resolution, and our screen is not. Figure out how much is cut off the sides.
        let trueWidth = bounds.height / 4.0 * 3.0
        let offset = (trueWidth - bounds.width) / 2.0
        
        let size = CGSize(
            width: boundingBox.width * trueWidth,
            height: boundingBox.height * bounds.height
        )
        
        let origin = CGPoint(
            x: (boundingBox.minX * trueWidth) - offset,
            y: (1 - boundingBox.maxY) * bounds.height
        )
        
        return CGRect(origin: origin, size: size)
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            isReady = true
            NSLog("Is ready")
        case .notAvailable:
            NSLog("Not available")
        case .limited(let reason):
            NSLog("Limited \(reason)")
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}


// Matrix multiplication stuff.
func * (left: SCNMatrix4, right: SCNVector3) -> SCNVector3 {
    let matrix = float4x4(left)
    let vector = float4(right)
    let result = matrix * vector
    
    return SCNVector3(result)
}

extension float4 {
    init(_ vector: SCNVector4) {
        self.init(vector.x, vector.y, vector.z, vector.w)
    }
    
    init(_ vector: SCNVector3) {
        self.init(vector.x, vector.y, vector.z, 1)
    }
}

extension SCNVector4 {
    init(_ vector: float4) {
        self.init(x: vector.x, y: vector.y, z: vector.z, w: vector.w)
    }
    
    init(_ vector: SCNVector3) {
        self.init(x: vector.x, y: vector.y, z: vector.z, w: 1)
    }
}

extension SCNVector3 {
    init(_ vector: float4) {
        self.init(x: vector.x / vector.w, y: vector.y / vector.w, z: vector.z / vector.w)
    }
}

extension float4x4 {
    init(_ matrix: SCNMatrix4) {
        self.init([
            float4(matrix.m11, matrix.m12, matrix.m13, matrix.m14),
            float4(matrix.m21, matrix.m22, matrix.m23, matrix.m24),
            float4(matrix.m31, matrix.m32, matrix.m33, matrix.m34),
            float4(matrix.m41, matrix.m42, matrix.m43, matrix.m44)
        ])
    }
}
