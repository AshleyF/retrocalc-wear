import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "display0" asset catalog image resource.
    static let display0 = DeveloperToolsSupport.ImageResource(name: "display0", bundle: resourceBundle)

    /// The "display1" asset catalog image resource.
    static let display1 = DeveloperToolsSupport.ImageResource(name: "display1", bundle: resourceBundle)

    /// The "display2" asset catalog image resource.
    static let display2 = DeveloperToolsSupport.ImageResource(name: "display2", bundle: resourceBundle)

    /// The "display3" asset catalog image resource.
    static let display3 = DeveloperToolsSupport.ImageResource(name: "display3", bundle: resourceBundle)

    /// The "display4" asset catalog image resource.
    static let display4 = DeveloperToolsSupport.ImageResource(name: "display4", bundle: resourceBundle)

    /// The "display5" asset catalog image resource.
    static let display5 = DeveloperToolsSupport.ImageResource(name: "display5", bundle: resourceBundle)

    /// The "display6" asset catalog image resource.
    static let display6 = DeveloperToolsSupport.ImageResource(name: "display6", bundle: resourceBundle)

    /// The "display7" asset catalog image resource.
    static let display7 = DeveloperToolsSupport.ImageResource(name: "display7", bundle: resourceBundle)

    /// The "display8" asset catalog image resource.
    static let display8 = DeveloperToolsSupport.ImageResource(name: "display8", bundle: resourceBundle)

    /// The "display9" asset catalog image resource.
    static let display9 = DeveloperToolsSupport.ImageResource(name: "display9", bundle: resourceBundle)

    /// The "display_e" asset catalog image resource.
    static let displayE = DeveloperToolsSupport.ImageResource(name: "display_e", bundle: resourceBundle)

    /// The "display_f" asset catalog image resource.
    static let displayF = DeveloperToolsSupport.ImageResource(name: "display_f", bundle: resourceBundle)

    /// The "display_i" asset catalog image resource.
    static let displayI = DeveloperToolsSupport.ImageResource(name: "display_i", bundle: resourceBundle)

    /// The "display_n" asset catalog image resource.
    static let displayN = DeveloperToolsSupport.ImageResource(name: "display_n", bundle: resourceBundle)

    /// The "display_neg" asset catalog image resource.
    static let displayNeg = DeveloperToolsSupport.ImageResource(name: "display_neg", bundle: resourceBundle)

    /// The "display_none" asset catalog image resource.
    static let displayNone = DeveloperToolsSupport.ImageResource(name: "display_none", bundle: resourceBundle)

    /// The "display_o" asset catalog image resource.
    static let displayO = DeveloperToolsSupport.ImageResource(name: "display_o", bundle: resourceBundle)

    /// The "display_r" asset catalog image resource.
    static let displayR = DeveloperToolsSupport.ImageResource(name: "display_r", bundle: resourceBundle)

    /// The "dot" asset catalog image resource.
    static let dot = DeveloperToolsSupport.ImageResource(name: "dot", bundle: resourceBundle)

    /// The "sym_editing" asset catalog image resource.
    static let symEditing = DeveloperToolsSupport.ImageResource(name: "sym_editing", bundle: resourceBundle)

    /// The "sym_editing_none" asset catalog image resource.
    static let symEditingNone = DeveloperToolsSupport.ImageResource(name: "sym_editing_none", bundle: resourceBundle)

    /// The "sym_f" asset catalog image resource.
    static let symF = DeveloperToolsSupport.ImageResource(name: "sym_f", bundle: resourceBundle)

    /// The "sym_f_none" asset catalog image resource.
    static let symFNone = DeveloperToolsSupport.ImageResource(name: "sym_f_none", bundle: resourceBundle)

    /// The "sym_g" asset catalog image resource.
    static let symG = DeveloperToolsSupport.ImageResource(name: "sym_g", bundle: resourceBundle)

    /// The "sym_g_none" asset catalog image resource.
    static let symGNone = DeveloperToolsSupport.ImageResource(name: "sym_g_none", bundle: resourceBundle)

    /// The "sym_rec" asset catalog image resource.
    static let symRec = DeveloperToolsSupport.ImageResource(name: "sym_rec", bundle: resourceBundle)

    /// The "sym_rec_none" asset catalog image resource.
    static let symRecNone = DeveloperToolsSupport.ImageResource(name: "sym_rec_none", bundle: resourceBundle)

}

