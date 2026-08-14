import SwiftUI
import Contacts
import ContactsUI

// MARK: - Contact Row Model
private struct CNContactRow: Identifiable {
    let id: String           // CNContact.identifier
    let fullName: String
    let phone: String
    let email: String
    let company: String
    let notes: String
}

// MARK: - AppleContactsPicker
/// Custom SwiftUI sheet that fetches all Contacts, provides a real search bar,
/// multi-select, and then imports the chosen contacts into PipelineStore.
struct AppleContactsPicker: View {

    @Binding var isPresented: Bool
    var onImported: (Int) -> Void
    var pipeline: PipelineStore

    @State private var contacts: [CNContactRow] = []
    @State private var selected: Set<String> = []
    @State private var searchText = ""
    @State private var authStatus: CNAuthorizationStatus = .notDetermined
    @State private var isLoading = true

    private var filtered: [CNContactRow] {
        guard !searchText.isEmpty else { return contacts }
        let q = searchText.lowercased()
        return contacts.filter {
            $0.fullName.lowercased().contains(q) ||
            $0.phone.lowercased().contains(q) ||
            $0.email.lowercased().contains(q) ||
            $0.company.lowercased().contains(q)
        }
    }

    var body: some View {
        // Only present the sheet when isPresented is true
        Color.clear
            .sheet(isPresented: $isPresented, onDismiss: { selected = []; searchText = "" }) {
                contactsSheet
            }
    }

    // MARK: - Sheet content
    private var contactsSheet: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading contacts…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if authStatus == .denied || authStatus == .restricted {
                    deniedView
                } else if contacts.isEmpty {
                    ContentUnavailableView("No Contacts", systemImage: "person.slash",
                                          description: Text("No contacts found in your address book."))
                } else {
                    contactList
                }
            }
            .navigationTitle("Import Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .toolbar,
                        prompt: "Search by name, phone, email…")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
            // Floating import bar — always visible even when search keyboard is up
            .safeAreaInset(edge: .bottom) {
                if !selected.isEmpty {
                    Button(action: importSelected) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Import \(selected.count) Contact\(selected.count == 1 ? "" : "s")")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.accentColor)
                                .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selected.isEmpty)
                }
            }
        }
        .onAppear { loadContacts() }
    }

    // MARK: - Contact list
    private var contactList: some View {
        List(filtered) { row in
            let isSel = selected.contains(row.id)
            let alreadyImported = pipeline.contactMetadata.contains {
                $0.id == PipelineStore.contactKey(row.fullName)
            }
            Button {
                if alreadyImported { return }
                if isSel { selected.remove(row.id) } else { selected.insert(row.id) }
                HapticManager.impact()
            } label: {
                HStack(spacing: 14) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(avatarColor(row.fullName).opacity(0.15))
                            .frame(width: 42, height: 42)
                        Text(initials(row.fullName))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(avatarColor(row.fullName))
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.fullName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(alreadyImported ? .secondary : .primary)
                        if !row.phone.isEmpty {
                            Text(row.phone)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else if !row.email.isEmpty {
                            Text(row.email)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        if alreadyImported {
                            Text("Already imported")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    // Checkmark / already-imported indicator
                    if alreadyImported {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(.tertiaryLabel))
                            .font(.system(size: 20))
                    } else if isSel {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.system(size: 20))
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(Color(.tertiaryLabel))
                            .font(.system(size: 20))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }

    // MARK: - Denied view
    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Contacts Access Required")
                .font(.headline)
            Text("Go to Settings → Privacy → Contacts and allow access for this app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                if let u = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(u)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load contacts
    private func loadContacts() {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)
        authStatus = status

        switch status {
        case .authorized, .limited:
            fetchContacts(store: store)
        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, _ in
                DispatchQueue.main.async {
                    authStatus = CNContactStore.authorizationStatus(for: .contacts)
                    if granted { fetchContacts(store: store) } else { isLoading = false }
                }
            }
        default:
            isLoading = false
        }
    }

    private func fetchContacts(store: CNContactStore) {
        DispatchQueue.global(qos: .userInitiated).async {
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactMiddleNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor,
                CNContactJobTitleKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)
            request.sortOrder = .userDefault

            var rows: [CNContactRow] = []
            do {
                try store.enumerateContacts(with: request) { contact, _ in
                    let first  = contact.givenName.trimmingCharacters(in: .whitespaces)
                    let middle = contact.middleName.trimmingCharacters(in: .whitespaces)
                    let last   = contact.familyName.trimmingCharacters(in: .whitespaces)
                    let full   = [first, middle, last].filter { !$0.isEmpty }.joined(separator: " ")
                    guard !full.isEmpty else { return }

                    let phone = contact.phoneNumbers.first?.value.stringValue
                        .trimmingCharacters(in: .whitespaces) ?? ""
                    let email = (contact.emailAddresses.first?.value as String?)?
                        .trimmingCharacters(in: .whitespaces) ?? ""
                    let company = [
                        contact.organizationName.trimmingCharacters(in: .whitespaces),
                        contact.jobTitle.trimmingCharacters(in: .whitespaces)
                    ].filter { !$0.isEmpty }.joined(separator: " · ")

                    rows.append(CNContactRow(id: contact.identifier, fullName: full,
                                            phone: phone, email: email,
                                            company: company, notes: ""))
                }
            } catch { }

            DispatchQueue.main.async {
                contacts = rows
                isLoading = false
            }
        }
    }

    // MARK: - Import
    private func importSelected() {
        let existingIDs = Set(pipeline.contactMetadata.map { $0.id })
        var count = 0
        for row in contacts where selected.contains(row.id) {
            let key = PipelineStore.contactKey(row.fullName)
            guard !existingIDs.contains(key) else { continue }
            var meta = ContactMetadata(id: key, displayName: row.fullName)
            meta.phone      = row.phone
            meta.email      = row.email
            meta.company    = row.company
            meta.notes      = row.notes
            meta.isImported = true
            pipeline.upsertContactMetadata(meta)
            count += 1
        }
        HapticManager.success()
        isPresented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onImported(count)
        }
    }

    // MARK: - Helpers
    private func avatarColor(_ name: String) -> Color {
        let colors: [Color] = [.blue, .indigo, .purple, .pink, .orange, .teal, .green, .cyan]
        return colors[abs(name.hashValue) % colors.count]
    }
    private func initials(_ name: String) -> String {
        let p = name.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        return p.count >= 2
            ? (String(p[0].prefix(1)) + String(p[1].prefix(1))).uppercased()
            : String(name.prefix(2)).uppercased()
    }
}
