//
//  Destype.swift
//  Harbeth
//
//  Created by Condy on 2022/10/22.
//

import Foundation

public protocol Destype {
    
    associatedtype Element
    
    var element: Element { get }
    var filters: [C7FilterProtocol] { get }
    
    init(element: Element, filters: [C7FilterProtocol])
    
    func output() throws -> Element
}
