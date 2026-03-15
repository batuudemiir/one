import SwiftUI

enum MascotPose: String {
    case hi = "hi"
    case sitHi = "sit-hi"
    case going = "going"
    case sleep = "sleep"
    case sleepPhoto = "sleep_photo"
    case oneMusic = "one_music"
    case onePicture = "one_picture"
    case oneQuestions = "one_questions"
    case oneFire = "one_fire"
    case photoSelect = "photoselect"
    case photoSelecting = "photoselecting"
    case photoSelected = "photoselected"
    case noState = "no_state"
    case error = "error"
}

struct OneMascotView: View {
    let pose: MascotPose
    var size: CGFloat = 120
    var message: String? = nil
    
    var body: some View {
        VStack(spacing: ONETokens.spacingMD) {
            Image(pose.rawValue)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                // Wabi-sabi hissiyatı için hafif bir gölge ve yumuşaklık
                .shadow(color: ONETokens.oneInk.opacity(0.05), radius: 10, x: 0, y: 5)
            
            if let message = message {
                Text(message)
                    .displaySM()
                    .foregroundColor(ONETokens.oneAsh)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ONETokens.spacingXL)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: pose) // Pozlar arası geçişler şık olsun
    }
}

#Preview {
    ZStack {
        ONETokens.oneCream.ignoresSafeArea()
        OneMascotView(pose: .hi, size: 150, message: "Merhaba! Ben One.\nSana eşlik etmek için buradayım.")
    }
}
