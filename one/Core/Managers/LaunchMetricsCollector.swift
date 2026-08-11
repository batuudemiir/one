//
//  LaunchMetricsCollector.swift
//  one
//
//  MetricKit ile prod cold/warm launch histogram özetlerini toplar ve
//  `AppAnalytics`'e `launch_metric_report` event'i olarak yollar.
//
//  Register: `oneApp.body .onAppear` Tier 3 içinden
//  `MXMetricManager.shared.add(LaunchMetricsCollector.shared)`.
//
//  iOS bu payload'ları günde ~1 kez, uygulama background'daysa teslim eder.
//  TestFlight/App Store build'de ~24h sonra ilk raporlar gelmeye başlar.
//

import Foundation
import MetricKit

final class LaunchMetricsCollector: NSObject, MXMetricManagerSubscriber {
    static let shared = LaunchMetricsCollector()

    private override init() { super.init() }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            guard let launch = payload.applicationLaunchMetrics else { continue }
            report(histogram: launch.histogrammedTimeToFirstDraw, isResume: false)
            report(histogram: launch.histogrammedApplicationResumeTime, isResume: true)
        }
    }

    // MetricKit diagnostics ile karıştırılmasın — sadece metric payload dinliyoruz.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {}

    /// Histogram bucket'larından p50/p95 hesap ve event yolla. MetricKit
    /// bucket sınırlarını `.bucketStart / .bucketEnd` ile veriyor; her bucket
    /// için orta noktayı `.bucketCount` kez tekrarlayarak yaklaşık dağılım
    /// kuruyoruz — sample count küçük olduğu için exact matematik gerekmiyor.
    private func report<UnitType: Unit>(
        histogram: MXHistogram<UnitType>,
        isResume: Bool
    ) {
        let buckets = histogram.bucketEnumerator
        var samplesMs: [Int] = []
        while let bucket = buckets.nextObject() as? MXHistogramBucket<UnitType> {
            let midpoint = (bucket.bucketStart.value + bucket.bucketEnd.value) / 2.0
            // MetricKit launch histogram unit'i saniye; ms'ye çevir.
            let midMs = Int((midpoint * 1000).rounded())
            for _ in 0..<bucket.bucketCount { samplesMs.append(midMs) }
        }

        guard !samplesMs.isEmpty else { return }
        samplesMs.sort()
        let p50 = percentile(samplesMs, p: 0.50)
        let p95 = percentile(samplesMs, p: 0.95)

        AppAnalytics.shared.track(.launchMetricReport(
            p50Ms: p50,
            p95Ms: p95,
            sampleCount: samplesMs.count,
            isResume: isResume
        ))
    }

    private func percentile(_ sorted: [Int], p: Double) -> Int {
        guard !sorted.isEmpty else { return 0 }
        let idx = min(sorted.count - 1, Int((Double(sorted.count) * p).rounded()))
        return sorted[idx]
    }
}
