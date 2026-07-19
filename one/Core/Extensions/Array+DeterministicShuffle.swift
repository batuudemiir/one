import Foundation

extension Array {
    /// Fisher-Yates shuffle with a deterministic LCG seed.
    /// Same seed → same order; different seed → different order.
    func deterministicShuffled(seed: UInt64) -> [Element] {
        var rng = seed
        var result = self
        for i in stride(from: result.count - 1, through: 1, by: -1) {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            let j = Int((rng >> 33) % UInt64(i + 1))
            result.swapAt(i, j)
        }
        return result
    }
}
