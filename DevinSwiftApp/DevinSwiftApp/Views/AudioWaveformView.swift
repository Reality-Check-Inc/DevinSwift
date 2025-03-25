import SwiftUI

struct AudioWaveformView: View {
    var levels: [Float]
    var color: Color = .blue
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: CGFloat(level * 50))
            }
        }
        .frame(height: 50)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .animation(.easeInOut(duration: 0.1), value: levels)
    }
}
