import Foundation

/// A spot on the target as angles from its centre, in true MOA. Positive is right and high.
struct AngularPoint: Equatable {
    var rightMOA = 0.0
    var highMOA = 0.0
}
