//
//  Zodifier.swift
//  Zodifier
//
//  Created by lzackx on 2022/5/7.
//

import UIKit
import ObjectiveC

extension Notification.Name {
    static let ZodifierDidChange = Notification.Name("ZodifierDidChangeNotification")
}

public protocol ZodifierProtocol {}

open class ZodifierManager<T: ZodifierProtocol> {

    open private(set) var zodifierObject: T {
        didSet {
            NotificationCenter.default.post(name: .ZodifierDidChange, object: self.zodifierObject)
        }
    }

    public init(_ zodifierObject: T) {
        self.zodifierObject = zodifierObject
    }

    private var internalAnimationBlock: ((@escaping () -> Void) -> Void)?
    public var animationDuration: TimeInterval = 0.3
    open var animationBlock: (@escaping () -> Void) -> Void {
        set {
            internalAnimationBlock = newValue
        }
        get {
            if internalAnimationBlock == nil {
                internalAnimationBlock = {
                    UIView.animate(withDuration: self.animationDuration, animations: $0)
                }
            }
            return internalAnimationBlock!
        }
    }

    public struct ZodifierConfiguration {
        public typealias ApplyBlockType = (AnyObject, T) -> Void

        public private(set) weak var object: AnyObject?
        public private(set) var applyBlock: ApplyBlockType

        public init(object: AnyObject, applyBlock: @escaping ApplyBlockType) {
            self.object = object
            self.applyBlock = applyBlock
        }
    }

    private class ZodifierCleaner {
        
        var objectAddress: Int

        var objectCleanBlock: ((Int) -> Void)?

        deinit {
            objectCleanBlock?(objectAddress)
        }

        init(_ objectAddress: Int) {
            self.objectAddress = objectAddress
        }
    }

    private var modifiedObjects = [Int: [ZodifierConfiguration]]()
    
    lazy var ZodifierCleanerKey: String = {
       return "\(object_getClassName(self))ZodifierCleanerKey"
    }()

    open func setup<O: AnyObject>(_ object: O?, applyBlock: @escaping (O, T) -> Void) {
        guard let object = object else {
            return
        }

        let objectAddress = unsafeBitCast(object, to: Int.self)

        let cleaner: ZodifierCleaner = ZodifierCleaner(objectAddress)
        cleaner.objectCleanBlock = {
            self.modifiedObjects.removeValue(forKey: $0)
        }
        objc_setAssociatedObject(object, self.ZodifierCleanerKey, cleaner, .OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        let configuration: ZodifierConfiguration = ZodifierConfiguration(object: object) {
            (object, zodifierObject) in
            applyBlock(object as! O, zodifierObject)
        }
        modifiedObjects[objectAddress, default: []].append(configuration)

        applyBlock(object, self.zodifierObject)
    }

    open func apply(_ zodifierObject: T, animated: Bool = true) {
        self.zodifierObject = zodifierObject
        modifiedObjects.forEach { (_, configurations) in
            configurations.forEach { (configuration) in
                guard let object = configuration.object else {
                    return
                }

                if animated, let view = object as? UIView, view.window != nil {
                    self.animationBlock {
                        configuration.applyBlock(object, zodifierObject)
                    }
                } else {
                    configuration.applyBlock(object, zodifierObject)
                }
            }
        }
    }
}

