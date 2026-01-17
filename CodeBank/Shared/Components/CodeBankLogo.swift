import SwiftUI

/// Reusable CodeBank logo component that automatically switches between light/dark mode
struct CodeBankLogo: View {
    enum Size {
        case small      // For menu bar, headers
        case medium     // For unlock screen, setup
        case large      // For about window, onboarding
        
        var height: CGFloat {
            switch self {
            case .small: return 36
            case .medium: return 48
            case .large: return 72
            }
        }
    }
    
    let size: Size
    
    init(size: Size = .medium) {
        self.size = size
    }
    
    var body: some View {
        Image("CodeBankLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: size.height)
    }
}

#Preview("Small") {
    CodeBankLogo(size: .small)
        .padding()
}

#Preview("Medium") {
    CodeBankLogo(size: .medium)
        .padding()
}

#Preview("Large") {
    CodeBankLogo(size: .large)
        .padding()
}
