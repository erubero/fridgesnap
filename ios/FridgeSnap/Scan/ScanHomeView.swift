import PhotosUI
import SwiftData
import SwiftUI

// Scan tab home: capture up to 5 photos, kick off the scan, reuse history.
struct ScanHomeView: View {
    @Bindable var model: ScanFlowModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalScan.createdAt, order: .reverse) private var history: [LocalScan]

    @State private var showCamera = false
    @State private var pickerItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack(path: $model.path) {
            ScrollView {
                VStack(spacing: 20) {
                    photoSection
                    scanButton
                    if !history.isEmpty { historySection }
                }
                .padding()
            }
            .navigationTitle("Scan")
            .navigationDestination(for: ScanFlowModel.Route.self) { route in
                switch route {
                case .review:
                    IngredientReviewView(model: model)
                case .levelSelect:
                    LazinessSelectorView(model: model)
                case .results:
                    RecipeResultsView(model: model)
                case .detail(let recipe):
                    RecipeDetailView(recipe: recipe, services: model.services)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker { model.addPhoto($0) }
                    .ignoresSafeArea()
            }
            .alert("FridgeSnap", isPresented: .init(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
            .alert("Free scans used", isPresented: $model.freeLimitHit) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You have used your 3 free scans. Unlimited scans arrive with FridgeSnap Pro at launch.")
            }
            .onChange(of: pickerItems) { _, items in
                Task { await loadPicked(items) }
            }
        }
    }

    private var photoSection: some View {
        VStack(spacing: 14) {
            if model.photos.isEmpty {
                ContentUnavailableView(
                    "Point the camera at the problem",
                    systemImage: "camera.viewfinder",
                    description: Text("Take up to 5 photos of your fridge, pantry, or counter. We will figure out dinner from there.")
                )
                .frame(minHeight: 220)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(model.photos.enumerated()), id: \.offset) { index, photo in
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 110, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        model.removePhoto(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white, .black.opacity(0.6))
                                    }
                                    .padding(6)
                                }
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                if CameraPicker.isAvailable {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!model.canAddMorePhotos)
                }

                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: 5 - model.photos.count,
                    matching: .images
                ) {
                    Label("Photos", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!model.canAddMorePhotos)
            }
        }
    }

    private var scanButton: some View {
        Button {
            Task {
                await model.runScan()
                saveToHistoryIfNeeded()
            }
        } label: {
            if model.isScanning {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Reading your fridge...")
                }
                .frame(maxWidth: .infinity)
            } else {
                Text("Scan \(model.photos.count) photo\(model.photos.count == 1 ? "" : "s")")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(model.photos.isEmpty || model.isScanning)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent scans")
                .font(.headline)
            ForEach(history.prefix(LocalScan.historyLimit)) { scan in
                Button {
                    model.reuse(scan: scan)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scan.createdAt, style: .date)
                                .font(.subheadline.weight(.semibold))
                            Text("\(scan.ingredientCount) ingredients")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loadPicked(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                model.addPhoto(image)
            }
        }
        pickerItems = []
    }

    private func saveToHistoryIfNeeded() {
        guard let scanID = model.scanID, !model.editor.isEmpty else { return }
        let existing = try? modelContext.fetch(FetchDescriptor<LocalScan>())
        guard existing?.contains(where: { $0.scanID == scanID }) != true else { return }
        modelContext.insert(LocalScan(scanID: scanID, ingredients: model.editor.ingredients))
        LocalScan.prune(in: modelContext)
        try? modelContext.save()
    }
}
