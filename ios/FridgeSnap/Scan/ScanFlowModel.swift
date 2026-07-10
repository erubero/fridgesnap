import Foundation
import SwiftUI

// Drives the whole core loop: photos -> scan -> review -> level -> recipes.
@MainActor
@Observable
final class ScanFlowModel {
    enum Route: Hashable {
        case review
        case levelSelect
        case results
        case detail(Recipe)
    }

    private let services: AppServices

    var path = NavigationPath()
    var photos: [UIImage] = []
    var isScanning = false
    var isGenerating = false
    var errorMessage: String?
    var freeLimitHit = false

    private(set) var scanID: String?
    var editor = IngredientEditor(ingredients: [])
    var selectedLevel: LazinessLevel = .lazyAF
    var servings = 2
    var recipes: [Recipe] = []
    var generationCount = 0

    init(services: AppServices) {
        self.services = services
    }

    var canAddMorePhotos: Bool { photos.count < 5 }

    func addPhoto(_ image: UIImage) {
        guard canAddMorePhotos else { return }
        photos.append(image)
    }

    func removePhoto(at index: Int) {
        guard photos.indices.contains(index) else { return }
        photos.remove(at: index)
    }

    func runScan() async {
        guard !photos.isEmpty, !isScanning else { return }
        isScanning = true
        errorMessage = nil
        defer { isScanning = false }
        do {
            let compressed = photos.compactMap(ImagePipeline.compress)
            guard !compressed.isEmpty else {
                errorMessage = "Could not read those photos. Try different ones."
                return
            }
            let response = try await services.scan.scan(images: compressed)
            scanID = response.scanID
            editor = IngredientEditor(ingredients: response.ingredients, scanDate: .now)
            generationCount = 0
            path.append(Route.review)
        } catch ServiceError.freeLimitReached {
            freeLimitHit = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reuse(scan: LocalScan) {
        scanID = scan.scanID
        // Anchored to the original scan date so due labels stay honest when
        // an old scan is reused ("due Friday" becomes "past its date").
        editor = IngredientEditor(ingredients: scan.ingredients, scanDate: scan.createdAt)
        generationCount = 0
        photos = []
        path.append(Route.review)
    }

    func proceedToLevelSelect() {
        guard !editor.isEmpty else {
            errorMessage = "Add at least one ingredient first."
            return
        }
        path.append(Route.levelSelect)
    }

    func generate(regenerate: Bool = false) async {
        guard let scanID, !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }
        do {
            recipes = try await services.generation.generate(
                scanID: scanID,
                ingredients: editor.requestIngredients,
                level: selectedLevel,
                servings: servings
            )
            generationCount += 1
            if !regenerate {
                path.append(Route.results)
            }
        } catch ServiceError.rateLimited(let message) {
            errorMessage = message
        } catch ServiceError.freeLimitReached {
            freeLimitHit = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startOver() {
        path = NavigationPath()
        photos = []
        scanID = nil
        editor = IngredientEditor(ingredients: [])
        recipes = []
        generationCount = 0
        errorMessage = nil
    }
}
