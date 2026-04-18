//
//  PhotoPickerView.swift
//  one
//
//  Photo picker for daily memories - Camera only
//

import SwiftUI

struct PhotoPickerButton: View {
    @Binding var selectedPhoto: UIImage?
    @State private var showPicker = false
    
    var body: some View {
        Button(action: { showPicker = true }) {
            HStack(spacing: 12) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ONETokens.oneCreamMid)
                        .frame(width: 44, height: 44)
                    
                    if let photo = selectedPhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18))
                            .foregroundColor(ONETokens.oneAsh)
                    }
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedPhoto == nil ? NSLocalizedString("today.addPhoto", comment: "") : NSLocalizedString("today.photoAdded", comment: ""))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(ONETokens.oneCharcoal)
                        .tracking(-0.1)
                    
                    Text(NSLocalizedString("photo.optionalHint", comment: ""))
                        .font(.system(size: 9.5, weight: .light, design: .monospaced))
                        .foregroundColor(ONETokens.oneAsh)
                        .tracking(0.3)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(ONETokens.oneAsh)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(
                        ONETokens.oneCreamLow,
                        style: StrokeStyle(
                            lineWidth: 1.5,
                            dash: selectedPhoto == nil ? [4] : []
                        )
                    )
            )
        }
        .fullScreenCover(isPresented: $showPicker) {
            CameraPicker(selectedImage: $selectedPhoto)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Camera Picker
struct CameraPicker: View {
    @Binding var selectedImage: UIImage?

    var body: some View {
        CameraView(image: $selectedImage)
            .ignoresSafeArea()
    }
}
