import SwiftUI

enum AccountEditorMode: Identifiable {
    case add
    case edit(ZaloAccount)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let account):
            return "edit-\(account.id.uuidString)"
        }
    }
}

struct AccountEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: AccountEditorMode
    let defaultZoomScale: Double
    let onSave: (String, String, AccountColor, Double) -> Void

    @State private var name: String
    @State private var note: String
    @State private var color: AccountColor
    @State private var zoomScale: Double

    init(
        mode: AccountEditorMode,
        defaultZoomScale: Double,
        onSave: @escaping (String, String, AccountColor, Double) -> Void
    ) {
        self.mode = mode
        self.defaultZoomScale = defaultZoomScale
        self.onSave = onSave

        switch mode {
        case .add:
            _name = State(initialValue: "")
            _note = State(initialValue: "")
            _color = State(initialValue: .blue)
            _zoomScale = State(initialValue: defaultZoomScale)
        case .edit(let account):
            _name = State(initialValue: account.name)
            _note = State(initialValue: account.note)
            _color = State(initialValue: account.color)
            _zoomScale = State(initialValue: account.zoomScale)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin tài khoản") {
                    TextField("Tên hiển thị (VD: Zalo Bán Hàng)", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Ghi chú (VD: SĐT hoặc mục đích)", text: $note)
                }

                Section("Màu nhận diện") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                        ForEach(AccountColor.allCases) { item in
                            Button {
                                color = item
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(item.swiftUIColor)
                                            .frame(width: 34, height: 34)
                                        if color == item {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    Text(item.displayName)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Mức thu phóng Zalo Web")
                            Spacer()
                            Text("\(Int(round(zoomScale * 100)))%")
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                        }

                        Slider(
                            value: $zoomScale,
                            in: ZaloAccount.minZoomScale...ZaloAccount.maxZoomScale,
                            step: 0.05
                        )

                        Button("Đặt về mặc định thiết bị (\(Int(round(defaultZoomScale * 100)))%)") {
                            zoomScale = defaultZoomScale
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Hiển thị")
                } footer: {
                    Text("Trên iPhone, mức 75%–85% giúp giao diện Zalo Web cân đối hơn khi cầm dọc; xoay ngang có trải nghiệm gần giống iPad.")
                }
            }
            .navigationTitle(isEditing ? "Sửa tài khoản" : "Thêm tài khoản Zalo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Lưu" : "Tạo") {
                        onSave(name, note, color, zoomScale)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
