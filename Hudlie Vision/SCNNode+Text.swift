//
//  SCNNode+Text.swift
//  faceIT
//
//  Created by Michael Ruhl on 18.08.17.
//  Copyright © 2017 NovaTec GmbH. All rights reserved.
//

import Foundation
import ARKit

class FaceNode {
    
    let parent: SCNNode
    let name: SCNNode
    let title: SCNNode
    let location: SCNNode
    
    init(parent: SCNNode, name: SCNNode, title: SCNNode, location: SCNNode) {
        self.parent = parent
        self.name = name
        self.title = title
        self.location = location
    }
    
    func animateDataIn() {
        name.show()
        name.move(name.position + SCNVector3(0, -0.04, 0))
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + animationDuration - 0.05) {
            self.title.show()
            self.title.move(self.title.position + SCNVector3(0, -0.04, 0))
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + animationDuration - 0.05) {
                self.location.show()
                self.location.move(self.location.position + SCNVector3(0, -0.04, 0))
            }
        }
    }
}

class ScanningNode {
    
    let parent: SCNNode
    let plane: SCNNode
    let horizontalBar: SCNNode
    
    private var isScanning = false
    private static let scanningDuration = 0.6
    
    init(parent: SCNNode, plane: SCNNode, horizontalBar: SCNNode) {
        self.parent = parent
        self.plane = plane
        self.horizontalBar = horizontalBar
    }
    
    func startScanning() {
        isScanning = true
        keepScanning()
    }
    
    private func keepScanning() {
        guard isScanning else { return }
        horizontalBar.move(horizontalBar.position + SCNVector3(0, 0.3, 0), duration: ScanningNode.scanningDuration)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + ScanningNode.scanningDuration) {
            guard self.isScanning else { return }
            self.horizontalBar.move(self.horizontalBar.position + SCNVector3(0, -0.3, 0), duration: ScanningNode.scanningDuration)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + ScanningNode.scanningDuration) {
                self.keepScanning()
            }
        }
    }
    
    func stopScanning() {
        isScanning = false
    }
}

private let animationDuration = 0.3

extension SCNNode {
    
    static func faceNode(withPerson person: [String: Any]?, position: SCNVector3) -> FaceNode {
        // TEXT BILLBOARD CONSTRAINT
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        
        let nameNode = createTextNode(person?["name"] as? String ?? "Unknown")
        nameNode.simdPosition = simd_float3.init(x: 0, y: -0.21, z: 0.01)
        nameNode.opacity = 0
        let titleNode = createTextNode(person?["title"] as? String ?? "Unknown")
        titleNode.simdPosition = simd_float3.init(x: 0, y: -0.25, z: 0.01)
        titleNode.opacity = 0
        let locationNode = createTextNode(person?["location"] as? String ?? "Unknown")
        locationNode.simdPosition = simd_float3.init(x: 0, y: -0.29, z: 0.01)
        locationNode.opacity = 0
        
        // PLANE NODE
        let material = SCNMaterial()
        material.transparency = 0.0
        let plane = SCNPlane(width: 0.3, height: 0.3)
        let planeNode = SCNNode(geometry: plane)
        planeNode.simdPosition = simd_float3.init(x: 0, y: 0, z: 0)
        highlightNode(planeNode)
        plane.firstMaterial = material
        
        let parentNode = SCNNode()
        
        parentNode.addChildNode(planeNode)
        parentNode.addChildNode(nameNode)
        parentNode.addChildNode(titleNode)
        parentNode.addChildNode(locationNode)
        parentNode.constraints = [billboardConstraint]
        parentNode.position = position
        
        return FaceNode(parent: parentNode, name: nameNode, title: titleNode, location: locationNode)
    }
    
    static func scanningNode(position: SCNVector3) -> ScanningNode {
        // TEXT BILLBOARD CONSTRAINT
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        
        // PLANE NODE
        let planeMaterial = SCNMaterial()
        planeMaterial.diffuse.contents = UIColor.cyan
        planeMaterial.transparency = 0.2
        let plane = SCNPlane(width: 0.3, height: 0.3)
        let planeNode = SCNNode(geometry: plane)
        planeNode.simdPosition = simd_float3.init(x: 0, y: 0, z: 0)
        plane.firstMaterial = planeMaterial
        
        // HORIZONTAL BAR NODE
        let horizontalBarMaterial = SCNMaterial()
        horizontalBarMaterial.diffuse.contents = UIColor.green
        horizontalBarMaterial.transparency = 0.5
        let horizontalBar = SCNPlane(width: 0.3, height: 0.005)
        let horizontalBarNode = SCNNode(geometry: horizontalBar)
        horizontalBarNode.simdPosition = simd_float3.init(x: 0, y: -0.15, z: 0.001)
        horizontalBar.firstMaterial = horizontalBarMaterial
        
        let parentNode = SCNNode()
        
        parentNode.addChildNode(planeNode)
        parentNode.addChildNode(horizontalBarNode)
        
        parentNode.constraints = [billboardConstraint]
        parentNode.position = position
        
        return ScanningNode(parent: parentNode, plane: planeNode, horizontalBar: horizontalBarNode)
    }
    
    func move(_ position: SCNVector3, duration: CFTimeInterval = animationDuration)  {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction.init(name: .linear)
        self.position = position
        opacity = 1
        SCNTransaction.commit()
    }
    
    func hide(duration: CFTimeInterval = 2.0)  {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction.init(name: .linear)
        opacity = 0
        SCNTransaction.commit()
    }
    
    func show(duration: CFTimeInterval = animationDuration)  {
        opacity = 0
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction.init(name: .linear)
        opacity = 1
        SCNTransaction.commit()
    }
}

func createTextNode(_ text: String) -> SCNNode {
    let bubbleDepth : Float = 0.02 // the 'depth' of 3D text
    // BUBBLE-TEXT
    let bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))
    bubble.font = UIFont(name: "Futura", size: 0.18)?.withTraits(traits: .traitBold)
    bubble.alignmentMode = CATextLayerAlignmentMode.center.rawValue
    bubble.firstMaterial?.diffuse.contents = UIColor.orange
    bubble.firstMaterial?.specular.contents = UIColor.white
    bubble.firstMaterial?.isDoubleSided = true
    bubble.chamferRadius = CGFloat(bubbleDepth)
    
    // BUBBLE NODE
    let (minBound, maxBound) = bubble.boundingBox
    let bubbleNode = SCNNode(geometry: bubble)
    // Centre Node - to Centre-Bottom point
    bubbleNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2)
    // Reduce default text size
    bubbleNode.scale = SCNVector3(0.2, 0.2, 0.2)
    
    return bubbleNode
}

func createLineNode(fromPos origin: SCNVector3, toPos destination: SCNVector3, color: UIColor) -> SCNNode {
    let line = lineFrom(vector: origin, toVector: destination)
    let lineNode = SCNNode(geometry: line)
    let planeMaterial = SCNMaterial()
    planeMaterial.diffuse.contents = color
    line.materials = [planeMaterial]
    
    return lineNode
}

func lineFrom(vector vector1: SCNVector3, toVector vector2: SCNVector3) -> SCNGeometry {
    let indices: [Int32] = [0, 1]
    
    let source = SCNGeometrySource(vertices: [vector1, vector2])
    let element = SCNGeometryElement(indices: indices, primitiveType: .line)
    
    return SCNGeometry(sources: [source], elements: [element])
}


func highlightNode(_ node: SCNNode) {
    let (min, max) = node.boundingBox
    let zCoord = node.position.z
    let topLeft = SCNVector3Make(min.x, max.y, zCoord)
    let bottomLeft = SCNVector3Make(min.x, min.y, zCoord)
    let topRight = SCNVector3Make(max.x, max.y, zCoord)
    let bottomRight = SCNVector3Make(max.x, min.y, zCoord)
    
    
    let bottomSide = createLineNode(fromPos: bottomLeft, toPos: bottomRight, color: .yellow)
    let leftSide = createLineNode(fromPos: bottomLeft, toPos: topLeft, color: .yellow)
    let rightSide = createLineNode(fromPos: bottomRight, toPos: topRight, color: .yellow)
    let topSide = createLineNode(fromPos: topLeft, toPos: topRight, color: .yellow)
    
    [bottomSide, leftSide, rightSide, topSide].forEach {
        $0.name = "something" // Whatever name you want so you can unhighlight later if needed
        node.addChildNode($0)
    }
}

func unhighlightNode(_ node: SCNNode) {
    let highlightningNodes = node.childNodes { (child, stop) -> Bool in
        child.name == "something"
    }
    highlightningNodes.forEach {
        $0.removeFromParentNode()
    }
}

private extension UIFont {
    // Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
    func withTraits(traits:UIFontDescriptor.SymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptor.SymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
}

func +(left:SCNVector3, right:SCNVector3) -> SCNVector3 {
    return SCNVector3(left.x + right.x, left.y + right.y, left.z + right.z)
}
