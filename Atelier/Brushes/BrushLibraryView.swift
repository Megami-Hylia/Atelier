import SwiftUI
import UniformTypeIdentifiers

struct BrushJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct BrushLibraryView: View {
    @ObservedObject var store: BrushStore
    @State private var query = ""
    @State private var recents = false
    @State private var favorites = false
    @State private var searching = false
    @State private var editMode = EditMode.inactive
    @State private var editingBrush: BrushPreset?
    @State private var name = ""
    @State private var nameAction: NameAction?
    @State private var showName = false
    @State private var importing = false
    @State private var exporting = false
    @State private var exportDocument = BrushJSONDocument(data: Data())
    @State private var managingLibraries = false
    @State private var confirmingReset = false
    @State private var deleteCandidate: BrushPreset?

    private enum NameAction {
        case newSet, renameSet(BrushSet), renameBrush(BrushPreset)
    }

    private var visibleBrushes: [BrushPreset] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !search.isEmpty {
            return store.brushes.filter { brush in
                brush.name.localizedCaseInsensitiveContains(search) ||
                store.sets.contains { $0.id == brush.setID && $0.name.localizedCaseInsensitiveContains(search) } ||
                store.libraries.contains { library in library.name.localizedCaseInsensitiveContains(search) && store.sets.contains { $0.libraryID == library.id && $0.id == brush.setID } }
            }
        }
        if favorites { return store.brushes.filter { store.favoriteIDs.contains($0.id) } }
        return recents ? store.recentBrushes : store.brushes.filter { $0.setID == store.selectedSetID }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let message = store.errorMessage {
                    HStack(alignment: .top) {
                        Text(message).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                        Spacer()
                        Button("Chiudi") { store.errorMessage = nil }
                    }
                    .padding().background(Color.red.opacity(0.08))
                    .accessibilityElement(children: .combine)
                }
                HStack {
                    Text("Libreria pennelli").font(.system(size: 22, weight: .bold))
                    Spacer()
                    Button { searching.toggle(); if !searching { query = "" } } label: { Image(systemName: "magnifyingglass").frame(width: 32, height: 44) }
                        .accessibilityLabel("Cerca pennelli")
                    Menu {
                        ForEach(store.libraries) { library in
                            Button(library.name) {
                                store.selectedLibraryID = library.id
                                store.selectedSetID = store.sets.first { $0.libraryID == library.id }?.id ?? ""
                                recents = false; favorites = false
                            }
                        }
                        Divider()
                        Button("Gestisci librerie", systemImage: "books.vertical") { managingLibraries = true }
                    } label: {
                        Image(systemName: "books.vertical").frame(width: 32, height: 44).accessibilityLabel("Scegli libreria")
                    }
                    Menu {
                        Button(editMode == .active ? "Fine riordino" : "Riordina pennelli e set", systemImage: "arrow.up.arrow.down") { editMode = editMode == .active ? .inactive : .active }
                        Button("Nuovo pennello", systemImage: "plus") { editingBrush = store.createBrush(in: store.selectedSetID) }
                        Button("Nuovo set", systemImage: "folder.badge.plus") { name = ""; nameAction = .newSet; showName = true }
                        Button("Importa JSON Atelier", systemImage: "square.and.arrow.down") { importing = true }
                        Button("Esporta libreria selezionata", systemImage: "square.and.arrow.up") { prepareExport(libraryID: store.selectedLibraryID) }
                        Button("Esporta tutte le librerie", systemImage: "square.and.arrow.up") { prepareExport() }
                        Divider()
                        Button("Ripristina i preset originali", systemImage: "arrow.counterclockwise") { confirmingReset = true }
                    } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                    .accessibilityLabel("Aggiungi, importa o esporta pennelli")
                }
                .padding(.horizontal)
                if searching {
                    TextField("Cerca pennelli, set e librerie", text: $query)
                        .textFieldStyle(.roundedBorder).padding(.horizontal).padding(.bottom, 10)
                }
                HStack(spacing: 0) {
                    List {
                        Button {
                            recents = true; favorites = false
                        } label: { Label("Recenti", systemImage: "clock") }
                        .listRowBackground(recents ? Color(white: 0.22) : Color.clear)
                        Button { favorites = true; recents = false } label: { Label("Preferiti", systemImage: "star") }
                            .listRowBackground(favorites ? Color(white: 0.22) : Color.clear)
                        ForEach(store.sets.filter { $0.libraryID == store.selectedLibraryID }) { set in
                            Button {
                                recents = false; favorites = false; store.selectedSetID = set.id
                            } label: { Label(set.name, systemImage: "paintbrush.pointed").font(.system(size: 12, weight: .medium)).foregroundStyle(.primary).lineLimit(2).padding(.vertical, 5) }
                            .listRowBackground(!recents && !favorites && store.selectedSetID == set.id ? Color(white: 0.22) : Color.clear)
                            .contextMenu {
                                Button("Rinomina") { name = set.name; nameAction = .renameSet(set); showName = true }
                                Button("Duplica set") { store.duplicateSet(set) }
                                Button("Esporta set JSON Atelier") { prepareExport(setID: set.id) }
                                Button("Elimina set e sposta i pennelli", role: .destructive) { store.deleteSet(set) }
                            }
                        }
                        .onMove { store.moveSets(in: store.selectedLibraryID, from: $0, to: $1) }
                    }
                    .listStyle(.plain).font(.system(size: 12, weight: .medium)).listRowSeparator(.hidden).scrollContentBackground(.hidden).background(Color(white: 0.13)).frame(width: 152)
                    Divider()
                    List {
                        ForEach(visibleBrushes) { brush in
                            HStack(spacing: 10) {
                                Button { if store.selectedID == brush.id { editingBrush = brush } else { store.select(brush) } } label: {
                                    VStack(alignment: .leading, spacing: 1) {
                                        HStack {
                                            Text(brush.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                            Spacer(minLength: 4)
                                            if store.favoriteIDs.contains(brush.id) { Image(systemName: "star.fill").font(.system(size: 10)) }
                                            Image(systemName: "paintbrush.pointed.fill").font(.system(size: 11))
                                        }.foregroundStyle(.white)
                                        BrushPreview(brush: brush, lightOnDark: true).frame(height: 48).clipped()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                            }
                            .padding(.horizontal, 8).padding(.vertical, 6)
                            .background(store.selectedID == brush.id ? Color(red: 0.03, green: 0.43, blue: 1) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                            .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                            .listRowSeparator(.hidden).listRowBackground(Color.clear)
                            .accessibilityAddTraits(store.selectedID == brush.id ? .isSelected : [])
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Elimina", role: .destructive) { deleteCandidate = brush }
                                Button("Duplica") { _ = store.duplicate(brush) }.tint(.gray)
                                Button("Esporta") { prepareExport(brush: brush) }.tint(.blue)
                            }
                            .moveDisabled(!query.isEmpty || recents || favorites)
                            .contextMenu {
                                Button(store.favoriteIDs.contains(brush.id) ? "Rimuovi dai preferiti" : "Aggiungi ai preferiti", systemImage: "star") { store.toggleFavorite(brush) }
                                Button("Modifica") { editingBrush = brush }
                                Button("Rinomina") { name = brush.name; nameAction = .renameBrush(brush); showName = true }
                                Button("Duplica") { _ = store.duplicate(brush) }
                                Menu("Sposta nel set") {
                                    ForEach(store.sets) { set in Button(set.name) { store.moveBrush(brush, to: set.id) } }
                                }
                                Button("Esporta pennello JSON Atelier") { prepareExport(brush: brush) }
                                if store.factoryVersion(of: brush) != nil { Button("Ripristina originale") { store.reset(brush) } }
                                Button("Elimina", role: .destructive) { deleteCandidate = brush }
                            }
                        }
                        .onMove { offsets, destination in
                            if query.isEmpty && !recents && !favorites { store.moveBrushes(in: store.selectedSetID, from: offsets, to: destination) }
                        }
                        if visibleBrushes.isEmpty {
                            Text(!query.isEmpty ? "Nessun risultato." : favorites ? "Nessun preferito. Tieni premuto un pennello per aggiungerlo." : recents ? "I pennelli selezionati compariranno qui." : "Set vuoto. Aggiungi o sposta un pennello.")
                                .foregroundStyle(.secondary).padding(.vertical)
                        }
                    }
                    .listStyle(.plain).scrollContentBackground(.hidden).background(Color(white: 0.1))
                }
            }
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .environment(\.editMode, $editMode)
            .fullScreenCover(item: $editingBrush) { BrushStudioView(store: store, brush: $0) }
            .sheet(isPresented: $managingLibraries) { BrushLibrariesView(store: store) }
            .alert("Nome", isPresented: $showName) {
                TextField("Nome", text: $name)
                Button("Annulla", role: .cancel) {}
                Button("Salva") { applyName() }
            }
            .confirmationDialog("Ripristinare tutti i preset originali Atelier? I pennelli personali vengono conservati.", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Ripristina preset", role: .destructive) { store.restoreFactoryPresets() }
            }
            .confirmationDialog("Eliminare questo pennello?", isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } }), titleVisibility: .visible) {
                Button("Elimina", role: .destructive) { if let brush = deleteCandidate { store.deleteBrush(brush) }; deleteCandidate = nil }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get(); let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 32_000_000 else { throw BrushArchiveError.invalid("File oltre 32 MB.") }
                    try store.importData(Data(contentsOf: url))
                } catch { store.errorMessage = "Importazione: \(error.localizedDescription)" }
            }
            .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json, defaultFilename: "Atelier-brush-library") { result in
                if case .failure(let error) = result { store.errorMessage = "Esportazione: \(error.localizedDescription)" }
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 0, idealWidth: 480, minHeight: 520, idealHeight: 650)
    }

    private func applyName() {
        switch nameAction {
        case .newSet: _ = store.createSet(name: name, libraryID: store.selectedLibraryID)
        case .renameSet(let set): store.renameSet(set, to: name)
        case .renameBrush(let brush): store.renameBrush(brush, to: name)
        case .none: break
        }
    }

    private func prepareExport(brush: BrushPreset? = nil, libraryID: String? = nil, setID: String? = nil) {
        do { exportDocument = BrushJSONDocument(data: try store.exportData(brush: brush, libraryID: libraryID, setID: setID)); exporting = true }
        catch { store.errorMessage = error.localizedDescription }
    }
}

private struct BrushLibrariesView: View {
    @ObservedObject var store: BrushStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var editing: BrushLibrary?
    @State private var naming = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.libraries) { library in
                    Button {
                        store.selectedLibraryID = library.id
                        store.selectedSetID = store.sets.first { $0.libraryID == library.id }?.id ?? ""
                        dismiss()
                    } label: {
                        HStack { Text(library.name).foregroundStyle(.primary); Spacer(); if store.selectedLibraryID == library.id { Image(systemName: "checkmark") } }
                    }
                    .contextMenu {
                        Button("Rinomina") { editing = library; name = library.name; naming = true }
                        Button("Elimina e conserva i pennelli", role: .destructive) { store.deleteLibrary(library) }
                    }
                }
            }
            .navigationTitle("Librerie")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Chiudi") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Nuova", systemImage: "plus") { editing = nil; name = ""; naming = true } }
            }
            .alert("Nome libreria", isPresented: $naming) {
                TextField("Nome", text: $name)
                Button("Annulla", role: .cancel) {}
                Button("Salva") { if let editing { store.renameLibrary(editing, to: name) } else { store.createLibrary(name: name) } }
            }
        }
    }
}
