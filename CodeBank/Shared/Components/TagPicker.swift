import SwiftUI

/// A picker for selecting tags
struct TagPicker: View {
    @Binding var selectedTagIds: [UUID]
    let availableTags: [Tag]
    var onCreateTag: ((String, String) -> Void)? = nil
    
    @State private var isShowingPopover = false
    @State private var newTagName = ""
    @State private var newTagColor = "blue"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Selected tags
            if !selectedTagIds.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(selectedTags) { tag in
                        TagChip(tag: tag, isSelected: true) {
                            selectedTagIds.removeAll { $0 == tag.id }
                        }
                    }
                }
            }
            
            // Add tag button
            Button {
                isShowingPopover = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                    Text(selectedTagIds.isEmpty ? "Add Tags" : "Add More")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
                tagPopoverContent
            }
        }
    }
    
    private var selectedTags: [Tag] {
        selectedTagIds.compactMap { id in
            availableTags.first { $0.id == id }
        }
    }
    
    private var unselectedTags: [Tag] {
        availableTags.filter { tag in
            !selectedTagIds.contains(tag.id)
        }
    }
    
    private var tagPopoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)
            
            if !unselectedTags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(unselectedTags) { tag in
                        TagChip(tag: tag, isSelected: false) {
                            selectedTagIds.append(tag.id)
                        }
                    }
                }
            } else if availableTags.isEmpty {
                Text("No tags created yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("All tags selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if onCreateTag != nil {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create New Tag")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        TextField("Tag name", text: $newTagName)
                            .textFieldStyle(.roundedBorder)
                        
                        Picker("Color", selection: $newTagColor) {
                            ForEach(Tag.availableColors, id: \.self) { color in
                                HStack {
                                    Circle()
                                        .fill(Tag.colorMap[color] ?? .blue)
                                        .frame(width: 12, height: 12)
                                    Text(color.capitalized)
                                }
                                .tag(color)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 100)
                        
                        Button("Add") {
                            onCreateTag?(newTagName, newTagColor)
                            newTagName = ""
                        }
                        .disabled(newTagName.isEmpty)
                    }
                }
            }
        }
        .padding()
        .frame(width: 300)
    }
}

/// A single tag chip
struct TagChip: View {
    let tag: Tag
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(tag.swiftUIColor)
                    .frame(width: 8, height: 8)
                
                Text(tag.name)
                    .font(.caption)
                
                if isSelected {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(tag.swiftUIColor.opacity(0.15))
                    .overlay {
                        Capsule()
                            .strokeBorder(tag.swiftUIColor.opacity(0.3), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

/// A simple flow layout for wrapping content
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }
        
        totalHeight = currentY + lineHeight
        
        return (CGSize(width: maxX, height: totalHeight), positions)
    }
}

#Preview {
    TagPicker(
        selectedTagIds: .constant([]),
        availableTags: Tag.samples
    ) { name, color in
        print("Create tag: \(name) - \(color)")
    }
    .padding()
    .frame(width: 400)
}
