import SwiftUI

/// Detail content for API Key items
struct APIKeyDetailContent: View {
    let data: APIKeyData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Service name if available
            if !data.service.isEmpty {
                CopyableField(label: "Service", value: data.service)
            }
            
            // Environment if available
            if let environment = data.environment, !environment.isEmpty {
                CopyableField(label: "Environment", value: environment)
            }
            
            // Show all credential fields
            if data.fields.isEmpty {
                // Legacy: show single API key if no fields defined
                if !data.key.isEmpty {
                    CopyableField(label: "API Key", value: data.key, isSecret: true, isMonospaced: true)
                }
            } else {
                // Show all fields
                ForEach(data.fields) { field in
                    CopyableField(
                        label: field.name,
                        value: field.value,
                        isSecret: field.isSecret,
                        isMonospaced: field.isSecret
                    )
                }
            }
            
            // Notes section
            if let notes = data.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(notes)
                        .font(.body)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        // Legacy single key
        APIKeyDetailContent(data: APIKeyData(
            key: "your_api_key_here",
            service: "Stripe",
            environment: "Production"
        ))
        
        Divider()
        
        // Multiple fields
        APIKeyDetailContent(data: APIKeyData(
            service: "Stripe",
            environment: "Production",
            fields: [
                .secretKey("your_api_key_here"),
                .publishableKey("pk_live_abcdefghijklmnop1234567890"),
                .webhookSecret("whsec_abcdef123456"),
                .url(name: "Webhook URL", value: "https://api.example.com/webhooks/stripe")
            ],
            notes: "Main production keys for payment processing"
        ))
    }
    .padding()
    .frame(width: 400)
}
