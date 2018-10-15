//
//  SCNNode+Text.swift
//  faceIT
//
//  Created by Michael Ruhl on 18.08.17.
//  Copyright © 2017 NovaTec GmbH. All rights reserved.
//

import Foundation
import ARKit

public extension SCNNode {
    convenience init(withPerson person: [String: Any]?, position: SCNVector3) {
        // TEXT BILLBOARD CONSTRAINT
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        
        let nameNode = createTextNode(person?["name"] as? String ?? "Unknown")
        nameNode.simdPosition = simd_float3.init(x: 0, y: -0.12, z: 0.1)
        let titleNode = createTextNode(person?["title"] as? String ?? "Unknown")
        titleNode.simdPosition = simd_float3.init(x: 0, y: -0.16, z: 0.1)
        let locationNode = createTextNode(person?["Location"] as? String ?? "Unknown")
        locationNode.simdPosition = simd_float3.init(x: 0, y: -0.20, z: 0.1)
        
        // PLANE NODE
        let material = SCNMaterial()
        material.transparency = 0.0
        let plane = SCNPlane(width: 0.2, height: 0.2)
        let planeNode = SCNNode(geometry: plane)
        planeNode.simdPosition = simd_float3.init(x: 0, y: 0, z: 0)
        highlightNode(planeNode)
        plane.firstMaterial = material
        
        self.init()
        addChildNode(planeNode)
        addChildNode(nameNode)
        addChildNode(titleNode)
        addChildNode(locationNode)
        constraints = [billboardConstraint]
        self.position = position
    }
    
    func move(_ position: SCNVector3)  {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.4
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction.init(name: .linear)
        self.position = position
        opacity = 1
        SCNTransaction.commit()
    }
    
    func hide()  {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 2.0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction.init(name: .linear)
        opacity = 0
        SCNTransaction.commit()
    }
    
    func show()  {
        opacity = 0
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.4
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
    element.pointSize = 5
    
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
