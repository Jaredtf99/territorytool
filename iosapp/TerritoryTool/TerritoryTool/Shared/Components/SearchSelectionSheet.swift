import SwiftUI

struct SearchSelectionSheet<T: Identifiable, Content: View>: View {
    let title: String
    @Binding var searchText: String
    let items: [T]
    let isLoading: Bool
    let onSelect: (T) -> Void
    let content: (T) -> Content
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if items.isEmpty && !searchText.isEmpty {
                    Text("common.no_results")
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(items) { item in
                        Button {
                            onSelect(item)
                            dismiss()
                        } label: {
                            content(item)
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SelectionRow: View {
    let title: String
    let value: String?
    let placeholder: LocalizedStringKey
    let icon: String
    let action: () -> Void
    var onClear: (() -> Void)? = nil
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                
                if let value = value {
                    Text(value)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                } else {
                    Text(placeholder)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if value != nil, let onClear = onClear {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
