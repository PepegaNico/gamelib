import SwiftUI

enum LibrarySortMode: String, CaseIterable, Identifiable {
    case playtimeDesc = "Meistgespielt"
    case nameAsc = "Name"
    case lastPlayedDesc = "Zuletzt gespielt"

    var id: String { rawValue }
}

/// The other three nav destinations land in later phases — shown here
/// (disabled) so the sidebar shell already exists rather than growing
/// piecemeal.
private enum SidebarDestination: String, CaseIterable, Identifiable {
    case library = "Bibliothek"
    case store = "Store"
    case wishlist = "Wishlist"
    case updates = "Updates"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .library: return "square.grid.2x2"
        case .store: return "cart"
        case .wishlist: return "heart"
        case .updates: return "bell"
        }
    }

    var isAvailable: Bool { self == .library }
}

struct LibraryView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(LibraryViewModel.self) private var library

    @State private var selection: SidebarDestination? = .library
    @State private var searchText = ""
    @State private var sortMode: LibrarySortMode = .playtimeDesc
    @State private var showFilters = false
    @State private var onlyUnplayed = false
    @State private var onlyControllerSupport = false
    @State private var onlyGerman = false

    var body: some View {
        NavigationSplitView {
            List(SidebarDestination.allCases, selection: $selection) { destination in
                Label(destination.rawValue, systemImage: destination.systemImage)
                    .foregroundStyle(destination.isAvailable ? .primary : .secondary)
                    .opacity(destination.isAvailable ? 1 : 0.5)
            }
            .navigationTitle("GameLib")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Abmelden", role: .destructive) { auth.signOut() }
                        .font(.footnote)
                }
            }
        } detail: {
            content
        }
        .task {
            await library.load(accounts: auth.accounts)
            await library.prefetchAppDetails()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .library, .none:
            libraryGrid
        default:
            ContentUnavailableView(
                "Bald verfügbar",
                systemImage: "hourglass",
                description: Text("Dieser Bereich folgt in einer späteren Ausbaustufe.")
            )
        }
    }

    private var libraryGrid: some View {
        ScrollView {
            if library.isLoading && library.steamGames.isEmpty {
                ProgressView("Lade Bibliothek…")
                    .padding(.top, 80)
            } else if let error = library.errorMessage, library.steamGames.isEmpty {
                ContentUnavailableView(
                    "Fehler",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                .padding(.top, 40)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                    ForEach(filteredGames) { game in
                        GameCard(game: game)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Bibliothek")
        .searchable(text: $searchText, prompt: "Spiele durchsuchen")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Sortieren", selection: $sortMode) {
                        ForEach(LibrarySortMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await library.load(accounts: auth.accounts)
                        await library.prefetchAppDetails()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            filterSheet
        }
    }

    private var filterSheet: some View {
        NavigationStack {
            Form {
                Toggle("Nur ungespielt", isOn: $onlyUnplayed)
                Toggle("Controller-Unterstützung", isOn: $onlyControllerSupport)
                Toggle("Deutsche Sprache", isOn: $onlyGerman)
            }
            .navigationTitle("Filter")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { showFilters = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var filteredGames: [SteamGame] {
        var games = library.steamGames

        if !searchText.isEmpty {
            games = games.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        if onlyUnplayed {
            games = games.filter { !$0.hasBeenPlayed }
        }
        if onlyControllerSupport {
            games = games.filter { library.appDetailsCache[$0.appId]?.fullControllerSupport == true }
        }
        if onlyGerman {
            games = games.filter { library.appDetailsCache[$0.appId]?.supportsGerman == true }
        }

        switch sortMode {
        case .playtimeDesc:
            games.sort { $0.playtimeForeverMinutes > $1.playtimeForeverMinutes }
        case .nameAsc:
            games.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .lastPlayedDesc:
            games.sort { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
        }

        return games
    }
}
