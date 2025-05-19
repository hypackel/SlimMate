import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack {
            Text("SlimMate Settings")
                .font(.title)
                .padding()
            // Add settings controls here later
            Text("Settings content goes here.")
            Spacer()
        }
        .padding()
        .frame(minWidth: 300, minHeight: 200)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 