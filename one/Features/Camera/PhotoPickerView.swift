//
//  PhotoPickerView.swift
//  one
//
//  Photo picker for daily memories - Camera only
//

import SwiftUI

// MARK: - Camera Picker
struct CameraPicker: View {
    @Binding var selectedImage: UIImage?

    var body: some View {
        CameraView(image: $selectedImage)
            .ignoresSafeArea()
    }
}
