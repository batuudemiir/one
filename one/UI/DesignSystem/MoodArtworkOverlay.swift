import SwiftUI

// MARK: - Mood Artwork Overlay

/// Fotoğraf zeminli story kartına Matisse-tarzı soyut illüstrasyon bindiren katman.
///
/// Referans: Organik, kağıt-kesilmiş (cut-out) formlar — kenarları hafif düzensiz,
/// içi dolu şekiller. Her mood kendi sembolik formunu taşır. Blend mode ile
/// fotoğrafla bütünleşir, ``drawingGroup()`` ile Metal'de tek bitmap'e düşer.
///
/// Bu katman yalnız `V3StoryBackground.photo` seçiliyken `V3StoryComposer`
/// tarafından ekleniyor; renk/kağıt zeminde gizli.
struct MoodArtworkOverlay: View {
    let mood: V3Mood

    /// Şeklin hangi blend mode ile fotoğrafa karışacağını mood'a göre belirler.
    /// Açık renkli mood'lar (mutlu, enerjik) → softLight daha zarif durur.
    /// Koyu mood'lar (hüzünlü, yorgun) → screen ile parlar.
    private var blendMode: BlendMode {
        switch mood {
        case .mutlu, .enerjik, .coskulu, .atesli: return .softLight
        case .huzurlu, .odakli: return .screen
        default: return .softLight
        }
    }

    var body: some View {
        Canvas { context, size in
            let artworkColor = mood.color.opacity(0.55)
            
            switch mood {
            case .huzurlu:
                drawOrganicSpiral(in: context, size: size, color: artworkColor)
            case .mutlu:
                drawSunburst(in: context, size: size, color: artworkColor)
            case .enerjik:
                drawStarburst(in: context, size: size, color: artworkColor)
            case .atesli:
                drawFlame(in: context, size: size, color: artworkColor)
            case .coskulu:
                drawWaveSwirl(in: context, size: size, color: artworkColor)
            case .odakli:
                drawConcentricRings(in: context, size: size, color: artworkColor)
            case .huzunlu:
                drawRainDrops(in: context, size: size, color: artworkColor)
            case .yorgun:
                drawCloudForm(in: context, size: size, color: artworkColor)
            case .gergin:
                drawLightningZag(in: context, size: size, color: artworkColor)
            }
        }
        .blendMode(blendMode)
        .drawingGroup()
        .allowsHitTesting(false)
    }
    
    // MARK: - Huzurlu — Organik Spiral (Matisse cut-out tarzı, içi dolu)
    
    private func drawOrganicSpiral(in context: GraphicsContext, size: CGSize, color: Color) {
        let cx = size.width * 0.5
        let cy = size.height * 0.38
        let maxR = min(size.width, size.height) * 0.32
        
        // Dış spiralden içe doğru katmanlar — her biri ayrı dolgu blob
        for ring in 0..<4 {
            let radius = maxR * (1.0 - CGFloat(ring) * 0.22)
            let points = 32
            var path = Path()
            
            for i in 0...points {
                let t = CGFloat(i) / CGFloat(points)
                let angle = t * .pi * 2
                // Organik düzensizlik: her noktada biraz farklı yarıçap
                let wobble = sin(angle * 3 + CGFloat(ring) * 1.7) * radius * 0.12
                    + cos(angle * 5 - CGFloat(ring) * 0.9) * radius * 0.08
                let r = radius + wobble
                let x = cx + cos(angle) * r
                let y = cy + sin(angle) * r
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
            
            // Her katman biraz daha açık/koyu
            let layerOpacity = 0.35 - Double(ring) * 0.06
            context.fill(path, with: .color(color.opacity(layerOpacity)))
        }
        
        // Merkeze küçük bir nokta
        let dotR: CGFloat = maxR * 0.08
        let dotPath = Path(ellipseIn: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2))
        context.fill(dotPath, with: .color(color.opacity(0.5)))
    }
    
    // MARK: - Mutlu — Güneş / Sunburst (kalın ışınlar, organik)
    
    private func drawSunburst(in context: GraphicsContext, size: CGSize, color: Color) {
        let cx = size.width * 0.5
        let cy = size.height * 0.35
        let baseR = min(size.width, size.height) * 0.12
        let rayLen = min(size.width, size.height) * 0.25
        let rayCount = 12
        
        // Merkez daire (güneş gövdesi)
        let sunPath = organicCirclePath(cx: cx, cy: cy, radius: baseR, wobbleAmt: 0.1)
        context.fill(sunPath, with: .color(color.opacity(0.45)))
        
        // Işınlar — her biri kalın, hafif eğri bir "yaprak" formu
        for i in 0..<rayCount {
            let angle = (CGFloat(i) / CGFloat(rayCount)) * .pi * 2 - .pi / 2
            let lenJitter = sin(CGFloat(i) * 2.3) * rayLen * 0.2
            let len = rayLen + lenJitter
            let halfWidth: CGFloat = baseR * 0.35 + sin(CGFloat(i) * 1.7) * 3
            
            var ray = Path()
            let tipX = cx + cos(angle) * (baseR + len)
            let tipY = cy + sin(angle) * (baseR + len)
            let leftAngle = angle - .pi / 2
            let rightAngle = angle + .pi / 2
            
            let baseLeftX = cx + cos(angle) * baseR + cos(leftAngle) * halfWidth
            let baseLeftY = cy + sin(angle) * baseR + sin(leftAngle) * halfWidth
            let baseRightX = cx + cos(angle) * baseR + cos(rightAngle) * halfWidth
            let baseRightY = cy + sin(angle) * baseR + sin(rightAngle) * halfWidth
            
            ray.move(to: CGPoint(x: baseLeftX, y: baseLeftY))
            // Hafif kavisli uç — yaprak formu
            let ctrlOff = len * 0.5
            let ctrlX = cx + cos(angle) * (baseR + ctrlOff) + cos(leftAngle) * halfWidth * 0.3
            let ctrlY = cy + sin(angle) * (baseR + ctrlOff) + sin(leftAngle) * halfWidth * 0.3
            ray.addQuadCurve(to: CGPoint(x: tipX, y: tipY), control: CGPoint(x: ctrlX, y: ctrlY))
            
            let ctrlX2 = cx + cos(angle) * (baseR + ctrlOff) + cos(rightAngle) * halfWidth * 0.3
            let ctrlY2 = cy + sin(angle) * (baseR + ctrlOff) + sin(rightAngle) * halfWidth * 0.3
            ray.addQuadCurve(to: CGPoint(x: baseRightX, y: baseRightY), control: CGPoint(x: ctrlX2, y: ctrlY2))
            ray.closeSubpath()
            
            context.fill(ray, with: .color(color.opacity(0.35)))
        }
    }
    
    // MARK: - Enerjik — Starburst / Yıldız patlaması
    
    private func drawStarburst(in context: GraphicsContext, size: CGSize, color: Color) {
        let cx = size.width * 0.5
        let cy = size.height * 0.38
        let outerR = min(size.width, size.height) * 0.34
        let innerR = outerR * 0.35
        let points = 8
        
        var star = Path()
        for i in 0..<(points * 2) {
            let angle = (CGFloat(i) / CGFloat(points * 2)) * .pi * 2 - .pi / 2
            let r = (i % 2 == 0) ? outerR : innerR
            // Organik düzensizlik
            let wobble = sin(CGFloat(i) * 3.1) * r * 0.08
            let actualR = r + wobble
            let x = cx + cos(angle) * actualR
            let y = cy + sin(angle) * actualR
            
            if i == 0 {
                star.move(to: CGPoint(x: x, y: y))
            } else {
                star.addLine(to: CGPoint(x: x, y: y))
            }
        }
        star.closeSubpath()
        context.fill(star, with: .color(color.opacity(0.4)))
        
        // İç daire
        let innerCircle = organicCirclePath(cx: cx, cy: cy, radius: innerR * 0.7, wobbleAmt: 0.15)
        context.fill(innerCircle, with: .color(color.opacity(0.25)))
    }
    
    // MARK: - Ateşli — Alev formu (organik, yukarı uzanan yapraklar)
    
    private func drawFlame(in context: GraphicsContext, size: CGSize, color: Color) {
        let cx = size.width * 0.5
        let baseY = size.height * 0.55
        let flameH = min(size.width, size.height) * 0.4
        let flameW = flameH * 0.45
        
        // 3 katmanlı alev (büyükten küçüğe)
        for layer in 0..<3 {
            let scale = 1.0 - CGFloat(layer) * 0.28
            let w = flameW * scale
            let h = flameH * scale
            let offsetX = CGFloat(layer) * 3
            
            var flame = Path()
            flame.move(to: CGPoint(x: cx + offsetX, y: baseY))
            
            // Sol kavis
            flame.addCurve(
                to: CGPoint(x: cx + offsetX, y: baseY - h),
                control1: CGPoint(x: cx - w * 1.2 + offsetX, y: baseY - h * 0.3),
                control2: CGPoint(x: cx - w * 0.3 + offsetX, y: baseY - h * 0.85)
            )
            // Sağ kavis
            flame.addCurve(
                to: CGPoint(x: cx + offsetX, y: baseY),
                control1: CGPoint(x: cx + w * 0.3 + offsetX, y: baseY - h * 0.85),
                control2: CGPoint(x: cx + w * 1.2 + offsetX, y: baseY - h * 0.3)
            )
            flame.closeSubpath()
            
            let layerOpacity = 0.4 - Double(layer) * 0.1
            context.fill(flame, with: .color(color.opacity(layerOpacity)))
        }
    }
    
    // MARK: - Coşkulu — Dalga Spiral / Wave Swirl
    
    private func drawWaveSwirl(in context: GraphicsContext, size: CGSize, color: Color) {
        let cx = size.width * 0.5
        let cy = size.height * 0.38
        let maxR = min(size.width, size.height) * 0.3
        
        // C-şekilli büyük dalga
        var wave = Path()
        let startAngle: CGFloat = -.pi * 0.3
        let endAngle: CGFloat = .pi * 1.4
        let thickness: CGFloat = maxR * 0.3
        
        // Dış kenar
        let outerPoints = 40
        for i in 0...outerPoints {
            let t = CGFloat(i) / CGFloat(outerPoints)
            let angle = startAngle + t * (endAngle - startAngle)
            let r = maxR + sin(t * .pi * 3) * 8
            let x = cx + cos(angle) * r
            let y = cy + sin(angle) * r
            if i == 0 { wave.move(to: CGPoint(x: x, y: y)) }
            else { wave.addLine(to: CGPoint(x: x, y: y)) }
        }
        // İç kenar (ters yön)
        for i in stride(from: outerPoints, through: 0, by: -1) {
            let t = CGFloat(i) / CGFloat(outerPoints)
            let angle = startAngle + t * (endAngle - startAngle)
            // İç taraf giderek incelsin (kıvrım ucu)
            let taperedThickness = thickness * (0.3 + t * 0.7)
            let r = maxR - taperedThickness + cos(t * .pi * 4) * 5
            let x = cx + cos(angle) * r
            let y = cy + sin(angle) * r
            wave.addLine(to: CGPoint(x: x, y: y))
        }
        wave.closeSubpath()
        context.fill(wave, with: .color(color.opacity(0.4)))
        
        // İç küçük spiral
        let smallR = maxR * 0.25
        let smallCircle = organicCirclePath(cx: cx + maxR * 0.15, cy: cy + maxR * 0.1, radius: smallR, wobbleAmt: 0.12)
        context.fill(smallCircle, with: .color(color.opacity(0.3)))
    }
    
    // MARK: - Odaklı — Konsantrik halkalar (hedef / bullseye)
    
    private func drawConcentricRings(in context: GraphicsContext, size: CGSize, color: Color) {
        let cx = size.width * 0.5
        let cy = size.height * 0.38
        let maxR = min(size.width, size.height) * 0.32
        
        for ring in 0..<4 {
            let outerR = maxR * (1.0 - CGFloat(ring) * 0.22)
            let innerR = outerR * 0.72
            let thickness = outerR - innerR
            
            // Dış organik daire
            var annulus = Path()
            let pts = 36
            for i in 0...pts {
                let t = CGFloat(i) / CGFloat(pts)
                let angle = t * .pi * 2
                let wobble = sin(angle * 4 + CGFloat(ring) * 2.0) * thickness * 0.15
                let r = outerR + wobble
                let x = cx + cos(angle) * r
                let y = cy + sin(angle) * r
                if i == 0 { annulus.move(to: CGPoint(x: x, y: y)) }
                else { annulus.addLine(to: CGPoint(x: x, y: y)) }
            }
            annulus.closeSubpath()
            
            // İç delik
            for i in stride(from: pts, through: 0, by: -1) {
                let t = CGFloat(i) / CGFloat(pts)
                let angle = t * .pi * 2
                let wobble = sin(angle * 3 + CGFloat(ring) * 1.5) * thickness * 0.1
                let r = innerR + wobble
                let x = cx + cos(angle) * r
                let y = cy + sin(angle) * r
                if i == pts { annulus.move(to: CGPoint(x: x, y: y)) }
                else { annulus.addLine(to: CGPoint(x: x, y: y)) }
            }
            annulus.closeSubpath()
            
            let layerOpacity = 0.35 - Double(ring) * 0.06
            // Even-odd fill ile iç delik şeffaf kalır
            context.fill(annulus, with: .color(color.opacity(layerOpacity)), style: FillStyle(eoFill: true))
        }
    }
    
    // MARK: - Hüzünlü — Yağmur damlaları (organik, farklı boyutlarda)
    
    private func drawRainDrops(in context: GraphicsContext, size: CGSize, color: Color) {
        let drops: [(CGFloat, CGFloat, CGFloat)] = [
            (0.25, 0.20, 0.08),
            (0.55, 0.15, 0.06),
            (0.75, 0.28, 0.07),
            (0.40, 0.35, 0.10),
            (0.15, 0.48, 0.05),
            (0.65, 0.45, 0.09),
            (0.85, 0.52, 0.06),
            (0.30, 0.58, 0.07),
            (0.50, 0.55, 0.05),
        ]
        
        for (rx, ry, rScale) in drops {
            let cx = size.width * rx
            let cy = size.height * ry
            let r = min(size.width, size.height) * rScale
            
            // Damla formu: üstten sivri, alttan yuvarlak
            var drop = Path()
            drop.move(to: CGPoint(x: cx, y: cy - r * 1.5))
            drop.addCurve(
                to: CGPoint(x: cx, y: cy + r),
                control1: CGPoint(x: cx + r * 1.1, y: cy - r * 0.2),
                control2: CGPoint(x: cx + r * 0.8, y: cy + r * 0.9)
            )
            drop.addCurve(
                to: CGPoint(x: cx, y: cy - r * 1.5),
                control1: CGPoint(x: cx - r * 0.8, y: cy + r * 0.9),
                control2: CGPoint(x: cx - r * 1.1, y: cy - r * 0.2)
            )
            drop.closeSubpath()
            
            let opacity = 0.25 + rScale * 2
            context.fill(drop, with: .color(color.opacity(opacity)))
        }
    }
    
    // MARK: - Yorgun — Bulut formu (yumuşak, ağır)
    
    private func drawCloudForm(in context: GraphicsContext, size: CGSize, color: Color) {
        let cx = size.width * 0.5
        let cy = size.height * 0.38
        let unit = min(size.width, size.height) * 0.14
        
        // Birleşen organik dairelerden bulut
        let blobs: [(CGFloat, CGFloat, CGFloat)] = [
            (cx - unit * 1.2, cy, unit * 0.9),
            (cx - unit * 0.3, cy - unit * 0.5, unit * 1.1),
            (cx + unit * 0.7, cy - unit * 0.3, unit * 0.95),
            (cx + unit * 1.4, cy + unit * 0.1, unit * 0.75),
            (cx, cy + unit * 0.3, unit * 1.0),
        ]
        
        for (bx, by, br) in blobs {
            let blob = organicCirclePath(cx: bx, cy: by, radius: br, wobbleAmt: 0.15)
            context.fill(blob, with: .color(color.opacity(0.3)))
        }
    }
    
    // MARK: - Gergin — Şimşek / Zikzak (sert açılı, keskin)
    
    private func drawLightningZag(in context: GraphicsContext, size: CGSize, color: Color) {
        let cx = size.width * 0.5
        let topY = size.height * 0.15
        let botY = size.height * 0.60
        let totalH = botY - topY
        let thickness: CGFloat = min(size.width, size.height) * 0.07
        
        // Zikzak noktaları — sert, kaotik açılar
        let zigPoints: [CGPoint] = [
            CGPoint(x: cx - 5, y: topY),
            CGPoint(x: cx + thickness * 1.8, y: topY + totalH * 0.25),
            CGPoint(x: cx - thickness * 0.8, y: topY + totalH * 0.35),
            CGPoint(x: cx + thickness * 2.2, y: topY + totalH * 0.55),
            CGPoint(x: cx - thickness * 0.3, y: topY + totalH * 0.65),
            CGPoint(x: cx + thickness * 1.5, y: topY + totalH * 0.85),
            CGPoint(x: cx + 5, y: botY),
        ]
        
        // Her nokta etrafında kalınlık vererek filled bir şekil oluştur
        var lightning = Path()
        lightning.move(to: CGPoint(x: zigPoints[0].x - thickness * 0.3, y: zigPoints[0].y))
        
        for i in 1..<zigPoints.count {
            lightning.addLine(to: CGPoint(x: zigPoints[i].x - thickness * 0.3, y: zigPoints[i].y))
        }
        // Geri dön, sağ kenardan
        for i in stride(from: zigPoints.count - 1, through: 0, by: -1) {
            lightning.addLine(to: CGPoint(x: zigPoints[i].x + thickness * 0.3, y: zigPoints[i].y))
        }
        lightning.closeSubpath()
        
        context.fill(lightning, with: .color(color.opacity(0.4)))
        
        // Küçük kırıntılar
        for offset in [CGPoint(x: -thickness * 1.5, y: totalH * 0.7), CGPoint(x: thickness * 2, y: totalH * 0.4)] {
            let sparkX = cx + offset.x
            let sparkY = topY + offset.y
            let sparkR = thickness * 0.3
            let spark = Path(ellipseIn: CGRect(x: sparkX - sparkR, y: sparkY - sparkR, width: sparkR * 2, height: sparkR * 2))
            context.fill(spark, with: .color(color.opacity(0.3)))
        }
    }
    
    // MARK: - Yardımcı: Organik daire (tüm şekillerde tekrar kullanılır)
    
    /// Tam yuvarlak yerine kenarları hafif dalgalı, kağıt kesilmiş gibi duran daire.
    private func organicCirclePath(cx: CGFloat, cy: CGFloat, radius: CGFloat, wobbleAmt: CGFloat) -> Path {
        let points = 24
        var path = Path()
        
        for i in 0...points {
            let t = CGFloat(i) / CGFloat(points)
            let angle = t * .pi * 2
            let wobble = sin(angle * 5) * radius * wobbleAmt
                + cos(angle * 3) * radius * wobbleAmt * 0.5
            let r = radius + wobble
            let x = cx + cos(angle) * r
            let y = cy + sin(angle) * r
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}
