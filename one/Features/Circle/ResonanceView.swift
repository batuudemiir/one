//
//  ResonanceView.swift
//  one
//
//  v2.6 — Rezonans gönderme ve görüntüleme bileşeni.
//  Arkadaşın paylaşımına kendi mood rengin + opsiyonel şarkı önerisiyle
//  tepki vermeyi sağlar. Yorumdan daha hafif, emoji'den daha anlamlı.
//

import SwiftUI
import CloudKit
import Combine

// MARK: - ViewModel

@MainActor
final class ResonanceViewModel: ObservableObject {
    @Published var resonances: [Resonance] = []
    @Published var isLoading = false
    @Published var hasSent = false
    @Published var isSending = false
    @Published var errorMessage: String?
    
    let shareRecordName: String
    let receiverID: String
    
    private var currentUserID: String? {
        CloudKitManager.shared.currentUser?["userID"] as? String
    }
    
    init(shareRecordName: String, receiverID: String) {
        self.shareRecordName = shareRecordName
        self.receiverID = receiverID
    }
    
    func load() {
        isLoading = true
        CloudKitManager.shared.fetchResonances(forShare: shareRecordName) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            switch result {
            case .success(let list):
                self.resonances = list
                if let uid = self.currentUserID {
                    self.hasSent = list.contains { $0.senderID == uid }
                }
            case .failure(let err):
                ONELogger.error("Rezonans fetch hatası: \(err.localizedDescription)", category: .circle)
            }
        }
    }
    
    func send(moodColor: String, moodWord: String,
              songID: String? = nil, songName: String? = nil, songArtist: String? = nil) {
        guard !hasSent, !isSending else { return }
        
        // Rate limit: günde max 5 rezonans
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = "resonance_count_\(dateFormatter.string(from: Date()))"
        let count = UserDefaults.standard.integer(forKey: todayKey)
        guard count < 5 else {
            errorMessage = NSLocalizedString("resonance.rateLimit", comment: "")
            return
        }

        isSending = true
        CloudKitManager.shared.sendResonance(
            toShare: shareRecordName,
            receiverID: receiverID,
            moodColor: moodColor,
            moodWord: moodWord,
            songSuggestionID: songID,
            songSuggestionName: songName,
            songSuggestionArtist: songArtist
        ) { [weak self] result in
            guard let self else { return }
            self.isSending = false
            switch result {
            case .success:
                self.hasSent = true
                UserDefaults.standard.set(count + 1, forKey: todayKey)
                ONEHaptics.songSaved()
                self.load()
            case .failure(let err):
                self.errorMessage = err.localizedDescription
            }
        }
    }
}

// MARK: - Resonance Bubble (received)

private struct ResonanceBubble: View {
    let resonance: Resonance
    
    var body: some View {
        VStack(spacing: 6) {
            // Sender initial + mood color ring
            ZStack {
                Circle()
                    .fill(Color(hex: resonance.moodColor).opacity(0.15))
                    .frame(width: 46, height: 46)
                Circle()
                    .stroke(Color(hex: resonance.moodColor), lineWidth: 2.5)
                    .frame(width: 46, height: 46)
                
                // Sender initial (display name preferred, moodWord fallback)
                let initial = resonance.senderDisplayName?.first.map { String($0).uppercased() }
                    ?? String(resonance.moodWord.prefix(1)).uppercased()
                Text(initial)
                    .bodyLG()
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: resonance.moodColor))
            }
            
            // Mood word
            Text(resonance.moodWord)
                .monoMicro()
                .fontWeight(.medium)
                .foregroundColor(ONETokens.oneCharcoal)
                .lineLimit(1)

            // Song suggestion indicator
            if resonance.songSuggestionName != nil {
                Image(systemName: "music.note")
                    .monoMicro()
                    .foregroundColor(ONETokens.oneAsh)
            }
        }
        .frame(width: 60)
    }
}

// MARK: - Resonance Send Sheet

struct ResonanceSendSheet: View {
    @ObservedObject var vm: ResonanceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMood: MoodOption?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                // Title
                VStack(spacing: 6) {
                    Image(systemName: "waveform.circle.fill")
                        .displayLG()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [ONETokens.oneBlue, ONETokens.moodIndigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text(NSLocalizedString("resonance.sheetTitle", comment: "Rezonans Gönder"))
                        .displaySM()
                        .fontWeight(.bold)
                        .foregroundColor(ONETokens.oneInk)

                    Text(NSLocalizedString("resonance.sheetSubtitle", comment: ""))
                        .bodySM()
                        .foregroundColor(ONETokens.oneAsh)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 8)
                
                // Mood grid (reuse MoodOption.all)
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("resonance.pickMood", comment: "Rengini seç"))
                        .monoBase()
                        .fontWeight(.semibold)
                        .foregroundColor(ONETokens.oneAsh)
                        .textCase(.uppercase)
                        .tracking(1.2)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(MoodOption.all) { mood in
                            MoodChip(
                                mood: mood,
                                isSelected: selectedMood?.key == mood.key
                            ) {
                                withAnimation(ONEAnimation.micro) {
                                    selectedMood = mood
                                }
                                ONEHaptics.moodSelected()
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Send CTA
                Button(action: sendResonance) {
                    HStack(spacing: 8) {
                        if vm.isSending {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        }
                        Text(NSLocalizedString("resonance.sendCTA", comment: "Rezonansı Gönder"))
                            .bodyLG()
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Group {
                            if let m = selectedMood {
                                LinearGradient(
                                    colors: [m.color, m.color.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            } else {
                                LinearGradient(
                                    colors: [ONETokens.oneStone, ONETokens.oneStone],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCard))
                }
                .disabled(selectedMood == nil || vm.isSending)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .background(ONETokens.oneCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: vm.hasSent) { _, sent in
                if sent { dismiss() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .bodySM()
                            .fontWeight(.medium)
                            .foregroundColor(ONETokens.oneAsh)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(ONETokens.oneSilver))
                    }
                }
            }
        }
    }
    
    private func sendResonance() {
        guard let mood = selectedMood else { return }
        vm.send(
            moodColor: mood.color.toHex(),
            moodWord: ONEMood(rawValue: mood.key)?.meaning ?? mood.label
        )
    }
}

// MARK: - Mood Chip

private struct MoodChip: View {
    let mood: MoodOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(mood.color)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                    )
                    .shadow(color: isSelected ? mood.color.opacity(0.5) : .clear, radius: 6, x: 0, y: 2)
                    .scaleEffect(isSelected ? 1.1 : 1.0)

                Text(ONEMood(rawValue: mood.key)?.meaning ?? mood.label)
                    .monoMicro()
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? ONETokens.oneInk : ONETokens.oneAsh)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
