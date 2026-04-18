//
//  DoneScreen.swift
//  one
//
//  Post-save confirmation screen
//

import SwiftUI

struct DoneScreen: View {
    @ObservedObject var vm: ColorPickerViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Wave animation
    @State private var waveScale: CGFloat = 0
    @State private var waveOpacity: Double = 1
    @State private var backgroundTinted = false

    // Staggered content reveal
    @State private var showCheck = false
    @State private var showTitle = false
    @State private var showMeta = false
    @State private var showMedia = false

    private var moodColor: Color { vm.selectedMood?.color ?? ONETokens.oneInk }

    var body: some View {
        ZStack {
            // Faz 2: Settling background tint (mood renginin %12 opaklığı)
            ONETokens.oneCream
                .overlay(moodColor.opacity(backgroundTinted ? 0.12 : 0))
                .animation(.easeInOut(duration: ONEAnimation.durationLong), value: backgroundTinted)
                .ignoresSafeArea()

            // Faz 1: Renk dalgası — merkezden yayılan daire
            GeometryReader { geo in
                Circle()
                    .fill(moodColor)
                    .frame(
                        width: max(geo.size.width, geo.size.height) * 2.8,
                        height: max(geo.size.width, geo.size.height) * 2.8
                    )
                    .scaleEffect(waveScale)
                    .opacity(waveOpacity)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            // Faz 3: İçerik — staggered giriş
            VStack(spacing: 0) {
                Spacer()

                Circle()
                    .fill(ONETokens.oneInk)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.system(size: 26, weight: .medium))
                    )
                    .scaleEffect(reduceMotion ? 1 : (showCheck ? 1 : 0.4))
                    .opacity(showCheck ? 1 : 0)
                    .animation(
                        reduceMotion ? .easeOut(duration: 0.15) : ONEAnimation.cardSpring.delay(0.45),
                        value: showCheck
                    )
                    .padding(.bottom, 36)

                Text(NSLocalizedString("done.saved", comment: ""))
                    .displayXL()
                    .foregroundColor(ONETokens.oneInk)
                    .padding(.bottom, 12)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: reduceMotion ? 0 : (showTitle ? 0 : 10))
                    .animation(
                        reduceMotion ? .easeOut(duration: 0.15) : ONEAnimation.panelSpring.delay(0.55),
                        value: showTitle
                    )

                Text("\(vm.selectedSong?.name ?? "") · \(vm.selectedMood?.label ?? "")")
                    .monoSM(tracking: 1.5)
                    .foregroundColor(ONETokens.oneAsh)
                    .padding(.bottom, 8)
                    .opacity(showMeta ? 1 : 0)
                    .offset(y: reduceMotion ? 0 : (showMeta ? 0 : 8))
                    .animation(
                        reduceMotion ? .easeOut(duration: 0.15) : ONEAnimation.panelSpring.delay(0.65),
                        value: showMeta
                    )

                if vm.calendarSyncEnabled {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 11))
                        Text(NSLocalizedString("done.calendarAdded", comment: ""))
                            .monoBase()
                    }
                    .foregroundColor(ONETokens.oneGreen)
                    .padding(.bottom, 52)
                    .opacity(showMeta ? 1 : 0)
                    .animation(
                        reduceMotion ? .easeOut(duration: 0.15) : ONEAnimation.panelSpring.delay(0.72),
                        value: showMeta
                    )
                } else {
                    Spacer().frame(height: 60)
                }

                VStack(spacing: 16) {
                    if let photo = vm.selectedPhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 12)
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(moodColor)
                            .frame(width: 90, height: 90)
                            .shadow(color: moodColor.opacity(0.3), radius: 20, x: 0, y: 12)
                    }

                    Text(NSLocalizedString(vm.selectedPhoto != nil ? "done.todaysMemory" : "done.todaysColor", comment: ""))
                        .monoBase(tracking: 2)
                        .foregroundColor(ONETokens.oneAsh)
                        .padding(.top, 4)

                    Text(vm.selectedMood?.label ?? "")
                        .displayMD()
                        .foregroundColor(ONETokens.oneInk)
                }
                .opacity(showMedia ? 1 : 0)
                .scaleEffect(reduceMotion ? 1 : (showMedia ? 1 : 0.92))
                .animation(
                    reduceMotion ? .easeOut(duration: 0.15) : ONEAnimation.cardSpring.delay(0.75),
                    value: showMedia
                )

                Spacer()
            }
        }
        .onAppear {
            if reduceMotion {
                // Reduce Motion: dalga ve arka plan animasyonu atlanır,
                // içerik anında görünür
                waveOpacity = 0
                backgroundTinted = true
                showCheck = true
                showTitle = true
                showMeta = true
                showMedia = true
            } else {
                // Faz 1: Dalga yayılır ve solar
                withAnimation(.easeOut(duration: 0.7)) {
                    waveScale = 1
                }
                withAnimation(.easeIn(duration: 0.5).delay(0.35)) {
                    waveOpacity = 0
                }

                // Faz 2: Arka plan rengi oturur
                withAnimation(.easeInOut(duration: ONEAnimation.durationLong).delay(0.2)) {
                    backgroundTinted = true
                }

                // Faz 3: İçerik staggered giriş
                showCheck = true
                showTitle = true
                showMeta = true
                showMedia = true
            }
        }
    }
}
