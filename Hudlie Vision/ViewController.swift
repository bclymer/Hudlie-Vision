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

    @IBOutlet var sceneView: ARSCNView!
    private var faceDetectionTimer: Timer?
    
    private let faceDetectionQueue = DispatchQueue(label: "Face-Detection", qos: .userInteractive)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        //let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        //sceneView.scene = scene
        
        print("Kicking off timer")
        faceDetectionTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(detectFace), userInfo: nil, repeats: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    @objc
    private func detectFace() {
        print("Queueing face detection")
        faceDetectionQueue.async {
            print("Running face detection")
            guard let frame = self.sceneView.session.currentFrame else {
                print("Leaving because no current frame")
                return
            }
            
            let image = CIImage(cvPixelBuffer: frame.capturedImage).rotate
            
            let faceRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request, error) in
                print("Results back")
                guard let faces = request.results as? [VNFaceObservation] else {
                    print("Leaving because wrong format")
                    return
                }
                faces.forEach { face in
                    guard let worldCoord = self.normalizeWorldCoord(face.boundingBox) else {
                        return
                    }
                    self.addText(vector: worldCoord)
                    print("Found face as \(face.boundingBox)")
                }
            })
            let requestHandler = VNImageRequestHandler(ciImage: image, options: [:])
            do {
                print("Processing request")
                try requestHandler.perform([faceRequest])
            } catch {
                print(error)
            }
        }
    }
    
    private func addText(vector: SCNVector3) {
        DispatchQueue.main.async {
            print("Adding face thing")
            self.sceneView.scene.rootNode.childNodes.forEach { node in
                node.removeFromParentNode()
            }
            let node = SCNNode(withText: "Face!", position: vector)
            self.sceneView.scene.rootNode.addChildNode(node)
        }
    }
    
    /// In order to get stable vectors, we determine multiple coordinates within an interval.
    ///
    /// - Parameters:
    ///   - boundingBox: Rect of the face on the screen
    /// - Returns: the normalized vector
    private func normalizeWorldCoord(_ boundingBox: CGRect) -> SCNVector3? {
        
        var array: [SCNVector3] = []
        Array(0...2).forEach{_ in
            if let position = determineWorldCoord(boundingBox) {
                array.append(position)
            }
            usleep(12000) // .012 seconds
        }
        
        if array.isEmpty {
            return nil
        }
        
        return SCNVector3.center(array)
    }
    
    
    /// Determine the vector from the position on the screen.
    ///
    /// - Parameter boundingBox: Rect of the face on the screen
    /// - Returns: the vector in the sceneView
    private func determineWorldCoord(_ boundingBox: CGRect) -> SCNVector3? {
        let arHitTestResults = sceneView.hitTest(CGPoint(x: boundingBox.midX, y: boundingBox.midY), types: [.featurePoint])
        
        // Filter results that are to close
        if let closestResult = arHitTestResults.filter({ $0.distance > 0.10 }).first {
            //            print("vector distance: \(closestResult.distance)")
            return SCNVector3.positionFromTransform(closestResult.worldTransform)
        }
        return nil
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
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
