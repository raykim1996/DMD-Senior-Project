//
//  Model.swift
//  SeniorProject-SwiftUI
//
//  Created by DongHo Kim on 2021/12/04.
//

import UIKit
import RealityKit
import Combine

class Model {
    var modelName: String
    var image: UIImage
    var modelEntity: ModelEntity?
    
    var cancellable: AnyCancellable? = nil
    
    init(modelName: String) {
        self.modelName = modelName
        
        self.image = UIImage(named: modelName)!
        
        let filenmae = modelName + ".usdz"
        self.cancellable = ModelEntity.loadModelAsync(named: filenmae).sink(receiveCompletion: {loadCompletion in
            print("Unable to load modelEntity for modelName: \(self.modelName)")
        }, receiveValue: { modelEntity in
            self.modelEntity = modelEntity
            print("Successfullly loaded modelEntity for modelName: \(self.modelName)")
        })
        
    }
}
