import PhotosUI
import SwiftUI

// MARK: - Profile picture
// The learner's picture and name at the top of Profile (design: https://claude.ai/artifact/VFTxNkJDH4kWkuYagEAgLz):
// an own photo (library or camera) or a funny character, the level as a badge on the bottom right.
// Everything stays on the phone: the photo is a small JPEG in Application Support, name and character in UserDefaults.

enum ProfileStore {
    static let nameKey = "profile.name"
    static let avatarKey = "profile.avatar"

    struct Avatar: Identifiable {
        let id: String
        let emoji: String
        let color: Color
    }

    /// Funny characters for those who do not want a photo (owner's wish: funnier than plain animals).
    static let avatars: [Avatar] = [
        Avatar(id: "nerd", emoji: "🤓", color: Color(red: 1, green: 0.90, blue: 0.78)),
        Avatar(id: "cool", emoji: "😎", color: Color(red: 0.85, green: 0.90, blue: 1)),
        Avatar(id: "disguise", emoji: "🥸", color: Color(red: 0.95, green: 0.87, blue: 0.96)),
        Avatar(id: "cowboy", emoji: "🤠", color: Color(red: 1, green: 0.95, blue: 0.72)),
        Avatar(id: "dino", emoji: "🦖", color: Color(red: 0.87, green: 0.95, blue: 0.89)),
        Avatar(id: "octopus", emoji: "🐙", color: Color(red: 1, green: 0.85, blue: 0.85)),
        Avatar(id: "sloth", emoji: "🦥", color: Color(red: 0.91, green: 0.89, blue: 0.84)),
        Avatar(id: "frog", emoji: "🐸", color: Color(red: 0.84, green: 0.95, blue: 0.95)),
        Avatar(id: "alien", emoji: "👽", color: Color(red: 0.88, green: 0.96, blue: 0.82)),
        Avatar(id: "robot", emoji: "🤖", color: Color(red: 0.87, green: 0.89, blue: 0.95)),
        Avatar(id: "ghost", emoji: "👻", color: Color(red: 0.93, green: 0.91, blue: 1)),
        Avatar(id: "penguin", emoji: "🐧", color: Color(red: 0.84, green: 0.92, blue: 1)),
    ]

    static func avatar(_ id: String) -> Avatar? { avatars.first { $0.id == id } }

    private static var photoURL: URL? {
        guard let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("profile.jpg")
    }

    static func photo() -> UIImage? {
        guard let url = photoURL, let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// A square, 400 px, from the middle of the photo.
    static func savePhoto(_ image: UIImage) {
        guard let url = photoURL else { return }
        let side = min(image.size.width, image.size.height)
        let target = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: target)
        let square = renderer.image { _ in
            let scale = target.width / side
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (target.width - size.width) / 2, y: (target.height - size.height) / 2,
                                  width: size.width, height: size.height))
        }
        try? square.jpegData(compressionQuality: 0.85)?.write(to: url, options: .atomic)
    }

    static func deletePhoto() {
        if let url = photoURL { try? FileManager.default.removeItem(at: url) }
    }
}

/// The round picture: a character, the photo, or the first letter of the name; optionally the level badge
/// (bottom right) and a small pencil (top right).
struct ProfileAvatarView: View {
    let photo: UIImage?
    let avatar: String
    let name: String
    var size: CGFloat = 96
    var level: String? = nil
    var showEdit = false

    var body: some View {
        ZStack {
            if let character = ProfileStore.avatar(avatar) {
                Circle().fill(character.color)
                Text(character.emoji).font(.system(size: size * 0.48))
            } else if let photo {
                Image(uiImage: photo).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle())
            } else {
                Circle().fill(DS.accent.opacity(0.16))
                if let letter = name.trimmingCharacters(in: .whitespaces).first {
                    Text(String(letter).uppercased()).font(.system(size: size * 0.42, weight: .heavy)).foregroundColor(DS.accent)
                } else {
                    Image(systemName: "person.fill").font(.system(size: size * 0.40)).foregroundColor(DS.accent)
                }
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(DS.surface, lineWidth: 4))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 5)
        .overlay(alignment: .topTrailing) {
            if showEdit {
                Image(systemName: "pencil").font(.system(size: 12, weight: .bold)).foregroundColor(DS.onGold)
                    .frame(width: 26, height: 26)
                    .background(DS.gold, in: Circle())
                    .overlay(Circle().stroke(DS.ground, lineWidth: 3))
                    .offset(x: 2, y: -2)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let level {
                Text(level).font(.system(size: 13, weight: .black)).foregroundColor(.white)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(DS.accent, in: Capsule())
                    .overlay(Capsule().stroke(DS.ground, lineWidth: 3))
                    .offset(x: 8, y: 2)
            }
        }
    }
}

/// Choosing the picture and the name: photo from the library or the camera, or one of the characters.
struct ProfilePictureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ProfileStore.nameKey) private var savedName = ""
    @AppStorage(ProfileStore.avatarKey) private var savedAvatar = ""
    /// Called after saving, so Profile reads the photo again.
    let onSave: () -> Void

    @State private var photo: UIImage?
    @State private var avatar = ""
    @State private var name = ""
    @State private var photoChanged = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ProfileAvatarView(photo: photo, avatar: avatar, name: name, size: 84)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    HStack(spacing: 10) {
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            source(t("profile.choosePhoto"), "photo.on.rectangle")
                        }
                        if PhotoCapture.available {
                            Button { showCamera = true } label: { source(t("profile.takePhoto"), "camera.fill") }
                        }
                    }
                    .buttonStyle(.pressable)
                    label(t("profile.orCharacter"))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(ProfileStore.avatars) { character in
                            Button { avatar = character.id } label: {
                                Text(character.emoji).font(.system(size: 30))
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                                    .background(character.color, in: Circle())
                                    .overlay(Circle().stroke(DS.gold, lineWidth: avatar == character.id ? 3 : 0).padding(-4))
                            }
                            .buttonStyle(.pressable)
                            .accessibilityAddTraits(avatar == character.id ? .isSelected : [])
                        }
                    }
                    label(t("profile.name"))
                    TextField(t("profile.namePlaceholder"), text: $name)
                        .textInputAutocapitalization(.words)
                        .padding(12)
                        .background(DS.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, DS.gutter)
                .padding(.bottom, 24)
            }
            .background(DS.ground.ignoresSafeArea())
            .navigationTitle(t("profile.pictureTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(t("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(t("profile.save")) { save() }.bold() }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            photo = ProfileStore.photo()
            avatar = savedAvatar
            name = savedName
        }
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await MainActor.run { use(image) }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            PhotoCapture { image in use(image) }.ignoresSafeArea()
        }
    }

    private func use(_ image: UIImage) {
        photo = image
        photoChanged = true
        avatar = ""  // a photo replaces the character
    }

    private func save() {
        if !avatar.isEmpty {
            ProfileStore.deletePhoto()
        } else if photoChanged, let photo {
            ProfileStore.savePhoto(photo)
        }
        savedAvatar = avatar
        savedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave()
        dismiss()
    }

    private func source(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundColor(DS.accent)
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(DS.ink)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased()).font(.caption.weight(.semibold)).foregroundColor(DS.muted).padding(.leading, 2)
    }
}
