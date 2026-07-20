//
//  SaveRipple.metal
//  one
//
//  Kayıt anının dalgası. SwiftUI'ın `.distortionEffect` çağırdığı
//  stitchable fonksiyonlar — çizim değil, altındaki pikselleri yer değiştirme.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

/// Merkezden dışa yayılan tek bir dalga cephesi.
///
/// Halka çizmek yerine örnekleme konumunu kaydırıyoruz: dalganın geçtiği
/// yerde ekranın kendisi buruşuyor. Kayıt "üstüne bir animasyon koymak"
/// değil, o anın ekrana çarpması olsun diye.
///
/// - position: hedef pikselin konumu (points)
/// - origin: dalganın merkezi
/// - time: tetiklemeden bu yana geçen saniye
/// - amplitude: en yüksek yer değiştirme (points)
/// - frequency: dalga sıklığı
/// - decay: sönümlenme hızı — yüksek değer daha çabuk dinginleşir
/// - speed: cephenin yayılma hızı (points/saniye)
[[ stitchable ]] float2 oneSaveRipple(
    float2 position,
    float2 origin,
    float time,
    float amplitude,
    float frequency,
    float decay,
    float speed
) {
    float2 delta = position - origin;
    float dist = length(delta);

    // Tam merkezde normalize() tanımsız — orayı hiç oynatma.
    if (dist < 0.0001) {
        return position;
    }

    // Cephe henüz buraya varmadıysa piksel yerinde durur. Bu gecikme
    // olmadan tüm ekran aynı anda titrer ve dalga hissi kaybolur.
    float delay = dist / speed;
    float t = max(0.0, time - delay);

    float wave = amplitude * sin(frequency * t) * exp(-decay * t);

    // Uzaklıkla zayıflama: kenarlarda dalga zaten sönmüş olmalı, yoksa
    // ekranın dışından içeri örnekleme yapıp kenarları eziyor.
    float falloff = 1.0 / (1.0 + dist * 0.004);

    return position + normalize(delta) * wave * falloff;
}

/// Dalganın geçtiği yerde rengin hafifçe taşması.
///
/// Cephe üzerinde kırmızı ve mavi kanalları birbirinden ayırıyoruz —
/// prizmatik bir kenar. Çok az: efekt fark edilmeli ama "bozuk ekran"
/// gibi durmamalı, o yüzden şiddet 1 pikselin altında tutuluyor.
[[ stitchable ]] half4 oneSaveChroma(
    float2 position,
    SwiftUI::Layer layer,
    float2 origin,
    float time,
    float speed,
    float width,
    float strength
) {
    float dist = length(position - origin);
    float front = time * speed;

    // Sadece cephenin ince bandında çalış.
    float band = 1.0 - smoothstep(0.0, width, abs(dist - front));
    if (band <= 0.001) {
        return layer.sample(position);
    }

    float2 dir = (dist < 0.0001) ? float2(0.0) : normalize(position - origin);
    float2 shift = dir * band * strength;

    half4 base = layer.sample(position);
    half r = layer.sample(position + shift).r;
    half b = layer.sample(position - shift).b;

    return half4(r, base.g, b, base.a);
}
