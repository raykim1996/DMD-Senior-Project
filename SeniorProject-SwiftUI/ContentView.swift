//
//  ContentView.swift
//  SeniorProject-SwiftUI
//
//  Created by DongHo Kim on 2021/11/19.
//

import SwiftUI
import RealityKit
import ARKit

extension UIColor {
    static let normalColor = UIColor(named: "NormalColor")
    static let iceColor = UIColor(named: "IceColor")
    static let metalColor = UIColor(named: "MetalColor")
    static let doneColor = UIColor(named: "DoneColor")
}

var tileColor: UIColor? = nil
var characterWasOnTile = false
var moveCharacterMode = false
var prevStandingTile: AnchorEntity? = nil
var characterAnchorEntity: AnchorEntity? = nil
var selectedCharacterModel: ModelEntity? = nil
//var tileArray: Array<

struct ContentView : View {
    // Mode:
    // 0 = Character Selection Mode
    // 1 = Character Placement Mode
    // 2 = Goal Selection Mode
    // 3 = Goal Placement Mode
    // 4 = Tile Placement Mode
    // 5 = Game Mode
    @State var appMode = 0
    @State var currModel: String?
    @State var confirmedModel: String?
    @State var currTile: String?
    @State var currTileColor: UIColor?
    
    var modelList: [String] = ["toy_robot_vintage", "toy_drummer"]
//    var tileList: []
    
    var body: some View {
//        return ARViewContainer().edgesIgnoringSafeArea(.all)
        
        ZStack(alignment: .bottom) {
            ARViewContainer(confirmedModel: self.$confirmedModel, currTileColor: self.$currTileColor, appMode: self.$appMode)
            
            if (self.appMode == 0 || self.appMode == 2) {
                ModelPickerView(modelList: self.modelList, appMode: self.$appMode, currModel: self.$currModel)
//            } else if self.appMode == 2 {
//                ModelPickerView(modelList: self.modelList, appMode: self.$appMode)
            } else {
                if (self.appMode == 4 || self.appMode == 5) {
                    TilePickerView(appMode: self.$appMode, currTile: self.$currTile, currTileColor: self.$currTileColor)
                } else {
                    PlacementButtonView(appMode: self.$appMode, currModel: self.$currModel, confirmedModel: self.$confirmedModel)
                }
            }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var confirmedModel: String?
    @Binding var currTileColor: UIColor?
    @Binding var appMode: Int
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: true)
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        
//        arView.retrieveTileColor(self.currTileColor)
        arView.enableTapGesture()
        
        return arView
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        print("updateUIView")
        if let currModelName = self.confirmedModel {
            print("Adding model to the scene: \(currModelName)")
            
            let filename = currModelName + ".usdz"
            let modelEntity = try! ModelEntity.loadModel(named: filename)
            let anchorEntity = AnchorEntity(plane: .any)
            anchorEntity.addChild(modelEntity)
            uiView.scene.addAnchor(anchorEntity)
            if self.appMode == 2 {
                print("setting characterAnchorEntity")
                anchorEntity.name = "MainCharacter"
                selectedCharacterModel = modelEntity
                characterAnchorEntity = anchorEntity
            }
            if self.appMode == 4 {
                print("setting goalAnchorEntity")
                anchorEntity.name = "goalCharacter"
            }
            
            DispatchQueue.main.async {
                self.confirmedModel = nil
            }
        }
    }
}

extension ARView {
    func retrieveTileColor(currTileColor: UIColor) {
        tileColor = currTileColor
    }
    
    
    func enableTapGesture() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(recognizer:)))
        self.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func handleTapGesture(recognizer: UITapGestureRecognizer) {
        let tapCoord = recognizer.location(in: self)
        guard let currRay = self.ray(through: tapCoord) else {return}
        
        // raycast based on the tapped coordinate
        let hitResults = self.scene.raycast(origin: currRay.origin, direction: currRay.direction)
        
        // Tile Placing Stage
        if moveCharacterMode == false {
            if let firstHit = hitResults.first {
                // hit AR object (tile, character etc.), so no placing
    //            if let entity = recognizer.location(in: self)
    //                if let anchorEntity = entity.anchor, ancho
            } else {
                // didn't intersect with AR object, so place the new object
                let hitResults = self.raycast(from: tapCoord, allowing: .estimatedPlane, alignment: .any)
                
                if let firstHit = hitResults.first {
                    let pos = simd_make_float3(firstHit.worldTransform.columns.3)
                    placeTile(at: pos)
                }
            }
        } else { // After done placing tiles, Moving Character Stage
            if let firstHit = hitResults.first {
                let nextAnchorEntity = firstHit.entity
                print("curr name is: \(nextAnchorEntity.name)")
                if nextAnchorEntity.name == "goalCharacter" {
                    nextAnchorEntity.removeFromParent()
                }
                
                if characterWasOnTile == false {
                    characterWasOnTile = true
                    // move character
                    let currFilename = "toy_robot_vintage.usdz"
                    let currModelEntity = try! ModelEntity.loadModel(named: currFilename)
                    var position = firstHit.position
                    let currAnchorEntity = AnchorEntity(world: position)
                    currAnchorEntity.addChild(currModelEntity)
                    self.scene.addAnchor(currAnchorEntity)
                    characterAnchorEntity?.removeFromParent()
                    characterAnchorEntity = currAnchorEntity
                    
                    // assign currTile to prevTile
                    prevStandingTile = nextAnchorEntity.anchor as! AnchorEntity
                    
                } else {
                    // move character
                    let currFilename = "toy_robot_vintage.usdz"
                    let currModelEntity = try! ModelEntity.loadModel(named: currFilename)
                    var position = firstHit.position
                    let currAnchorEntity = AnchorEntity(world: position)
                    currAnchorEntity.addChild(currModelEntity)
                    self.scene.addAnchor(currAnchorEntity)
                    characterAnchorEntity?.removeFromParent()
                    characterAnchorEntity = currAnchorEntity

                    // delete prevTile
                    prevStandingTile?.removeFromParent()
                    
                    // assign currTile to prevTile
                    prevStandingTile = nextAnchorEntity.anchor as! AnchorEntity
                }
            }
        }
    }
    
    func placeTile(at pos: SIMD3<Float>) {
        let mesh = MeshResource.generateBox(width: 0.2, height: 0.05, depth: 0.2)
//        let mesh = MeshResource.generatePlane(width: 0.2, depth: 0.2, cornerRadius: 0.05)
        var material = SimpleMaterial(color: .white, roughness: 0.3, isMetallic: false)
        material.tintColor = tileColor!
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        modelEntity.generateCollisionShapes(recursive: true)
        
        let anchorEntity = AnchorEntity(world: pos)
        anchorEntity.addChild(modelEntity)
        
        self.scene.addAnchor(anchorEntity)
//        self.scene.anchors
    }
}

struct ModelPickerView: View {
    
    var modelList: [String] = ["toy_robot_vintage", "toy_drummer"]
    var goalList: [String] = ["toy_car"]
    
    @Binding var appMode: Int
    @Binding var currModel: String?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators:  false) {
            HStack(spacing: 30) {
                if self.appMode == 0 {
                    ForEach(0 ..< self.modelList.count) {
                        index in
                        Button(action: {
                            print("Selected model is: \(self.modelList[index])")
                            self.currModel = self.modelList[index]
                            self.appMode += 1
                            print("Mode Code: \(self.appMode)")
                        }) {
                            Image(uiImage: UIImage(named: self.modelList[index])!).resizable().frame(height: 100).aspectRatio(1/1, contentMode: .fit).background(Color.white)
                        }.buttonStyle(PlainButtonStyle())
                    }
                } else {
                    Button(action: {
                        print("Selected model is: \(self.goalList[0])")
                        self.currModel = self.goalList[0]
                        self.appMode += 1
                        print("Mode Code: \(self.appMode)")
                    }) {
                        Image(uiImage: UIImage(named: self.goalList[0])!).resizable().frame(height: 100).aspectRatio(1/1, contentMode: .fit).background(Color.white)
                    }.buttonStyle(PlainButtonStyle())
                }
            }
        }.padding(20).background(Color.black.opacity(0.5))
    }
}

struct TilePickerView: View {
    
    var tileOptionList: [String] = ["Normal", "Metal", "Ice", "Done"]
    var tileColorList: [UIColor?] = [UIColor.normalColor, UIColor.metalColor, UIColor.iceColor, UIColor.doneColor]
    
    @Binding var appMode: Int
    @Binding var currTile: String?
    @Binding var currTileColor: UIColor?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators:  false) {
            HStack(spacing: 30) {
                ForEach(0 ..< self.tileOptionList.count) {
                    index in
                    Button(action: {
                        print("Selected tile is: \(self.tileOptionList[index])")
                        if self.tileOptionList[index] == "Done" {
                            self.appMode = 5
                            moveCharacterMode = true
                        }
                        self.currTile = self.tileOptionList[index]
                        self.currTileColor = self.tileColorList[index]
                        tileColor = self.tileColorList[index]
                    }) {
                        Image(uiImage: UIImage(named: self.tileOptionList[index])!).resizable().frame(height: 100).aspectRatio(1/1, contentMode: .fit).background(Color.white)
                    }.buttonStyle(PlainButtonStyle())
                }
            }
        }.padding(20).background(Color.black.opacity(0.5))
    }
}

struct PlacementButtonView: View {
    @Binding var appMode: Int
    @Binding var currModel: String?
    @Binding var confirmedModel: String?
    
    var body: some View {
        HStack {
            // Place Button
            Button(action: {
                print("Placing model")
                self.confirmedModel = self.currModel
                self.appMode += 1
                print("Mode Code: \(self.appMode)")
            }) {
                Image(systemName: "checkmark").frame(width: 60, height: 60).font(.title).background(Color.white.opacity(0.75)).padding(20)
            }
            // X Button
            Button(action: {
                print("Canceling placing model")
                self.appMode -= 1
                print("Mode Code: \(self.appMode)")
            }) {
                Image(systemName: "xmark").frame(width: 60, height: 60).font(.title).background(Color.white.opacity(0.75)).padding(20)
            }
        }
    }
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
