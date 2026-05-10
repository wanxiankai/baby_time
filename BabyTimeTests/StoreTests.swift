import XCTest
@testable import BabyTime

@MainActor
final class StoreTests: XCTestCase {
    private func makeStore() -> AppStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("babytime-test-\(UUID().uuidString).json")
        return AppStore(storageURL: url)
    }

    func testRegisterLoginAndLogout() {
        let store = makeStore()
        store.register(email: "Parent@Example.com", password: "password", displayName: "Parent")
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.activeAccount?.email, "parent@example.com")

        store.logout()
        XCTAssertFalse(store.isAuthenticated)

        store.login(email: "parent@example.com", password: "password")
        XCTAssertTrue(store.isAuthenticated)
    }

    func testChildProfileAndTimelineBuckets() {
        let store = makeStore()
        let birthday = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        store.register(email: "a@b.com", password: "password", displayName: "A")
        store.createChild(nickname: "小宝", birthday: birthday, gender: "未设置", note: "")

        XCTAssertEqual(store.selectedChild?.nickname, "小宝")
        XCTAssertEqual(store.selectedChild?.defaultMediaStorageMode, .localReference)
        XCTAssertEqual(AppStore.bucket(for: birthday, birthday: birthday), .birth)
        XCTAssertEqual(AppStore.bucket(for: Calendar.current.date(byAdding: .day, value: 5, to: birthday)!, birthday: birthday), .week1)
        XCTAssertEqual(AppStore.bucket(for: Calendar.current.date(byAdding: .month, value: 6, to: birthday)!, birthday: birthday), .month6)
        XCTAssertEqual(AppStore.bucket(for: Calendar.current.date(byAdding: .month, value: 7, to: birthday)!, birthday: birthday), .month7)
    }

    func testAddPhotoCreateCollectionAndSearch() {
        let store = makeStore()
        store.register(email: "a@b.com", password: "password", displayName: "A")
        store.createChild(nickname: "小宝", birthday: Date(), gender: "未设置", note: "")
        store.addSamplePhoto(title: "满月笑脸", note: "第一次笑")

        let photo = try! XCTUnwrap(store.currentPhotos.first)
        store.createCollection(title: "满月照", note: "纪念日", photoIDs: [photo.id], layoutTemplate: "grid")

        XCTAssertEqual(store.currentPhotos.count, 1)
        XCTAssertEqual(store.currentCollections.count, 1)
        XCTAssertTrue(store.search("笑脸").contains(.photo(photo)))
        XCTAssertTrue(store.search("满月照").contains(.collection(store.currentCollections[0])))
    }

    func testCollectionCanBeEditedAndTaggedLocally() {
        let store = makeStore()
        store.register(email: "a@b.com", password: "password", displayName: "A")
        store.createChild(nickname: "小宝", birthday: Date(), gender: "未设置", note: "")
        store.addSamplePhoto(title: "封面照片", note: "")
        store.addSamplePhoto(title: "第二张", note: "")

        let photos = store.currentPhotos
        store.createCollection(title: "旧标题", note: "", photoIDs: photos.map(\.id), layoutTemplate: "grid")
        store.addTag(name: "满月")
        let collection = try! XCTUnwrap(store.currentCollections.first)
        let cover = try! XCTUnwrap(photos.first)
        let tag = try! XCTUnwrap(store.state.tags.first)

        store.updateCollection(collection, title: "满月合集", note: "本地备注", layoutTemplate: "cover", coverPhotoID: cover.id)
        store.attach(tagID: tag.id, toCollection: collection.id)

        let updated = try! XCTUnwrap(store.currentCollections.first)
        XCTAssertEqual(updated.title, "满月合集")
        XCTAssertEqual(updated.note, "本地备注")
        XCTAssertEqual(updated.layoutTemplate, "cover")
        XCTAssertEqual(updated.coverPhotoID, cover.id)
        XCTAssertTrue(store.search("满月").contains(.collection(updated)))
    }

    func testLocalReferenceImportStoresAssetIdentifierAndMissingState() {
        let store = makeStore()
        store.register(email: "a@b.com", password: "password", displayName: "A")
        store.createChild(nickname: "小宝", birthday: Date(), gender: "未设置", note: "", storageMode: .localReference)

        store.importPhoto(assetIdentifier: "missing-local-asset", title: "本机索引照片", note: "")

        let photo = try! XCTUnwrap(store.currentPhotos.first)
        XCTAssertEqual(photo.storageMode, .localReference)
        XCTAssertEqual(photo.localAssetIdentifier, "missing-local-asset")
        XCTAssertEqual(photo.localAssetStatus, .missing)
        XCTAssertEqual(photo.cloudSyncStatus, .notRequired)
    }

    func testCloudBackupModeCreatesProviderAndBackupState() async {
        let store = makeStore()
        store.register(email: "a@b.com", password: "password", displayName: "A")
        store.createChild(nickname: "小宝", birthday: Date(), gender: "未设置", note: "", storageMode: .userCloudBackup, cloudProvider: .dropbox)

        XCTAssertEqual(store.selectedChild?.defaultMediaStorageMode, .userCloudBackup)
        XCTAssertEqual(store.selectedCloudAccount?.provider, .dropbox)

        store.importPhoto(assetIdentifier: "missing-cloud-asset", title: "云端备份照片", note: "")
        var photo = try! XCTUnwrap(store.currentPhotos.first)
        XCTAssertEqual(photo.storageMode, .userCloudBackup)
        XCTAssertEqual(photo.cloudProvider, .dropbox)
        XCTAssertEqual(photo.cloudSyncStatus, .uploading)

        try? await Task.sleep(nanoseconds: 1_000_000_000)
        photo = try! XCTUnwrap(store.currentPhotos.first)
        XCTAssertEqual(photo.cloudSyncStatus, .synced)
        XCTAssertNotNil(photo.cloudFileID)
    }

    func testTagsCategoriesAndBindings() {
        let store = makeStore()
        store.register(email: "a@b.com", password: "password", displayName: "A")
        store.createChild(nickname: "小宝", birthday: Date(), gender: "未设置", note: "")
        store.addSamplePhoto(title: "语言发展", note: "")
        store.addTag(name: "牙牙学语")
        let photo = try! XCTUnwrap(store.currentPhotos.first)
        let tag = try! XCTUnwrap(store.state.tags.first)
        let category = try! XCTUnwrap(store.state.categories.first)

        store.attach(tagID: tag.id, toPhoto: photo.id)
        store.attach(categoryID: category.id, toPhoto: photo.id)

        let updated = try! XCTUnwrap(store.currentPhotos.first)
        XCTAssertEqual(updated.tagIDs, [tag.id])
        XCTAssertEqual(updated.categoryIDs, [category.id])
        XCTAssertTrue(store.search("牙牙学语").contains(.photo(updated)))
    }

    func testSearchFindsTaxonomy() {
        let store = makeStore()
        store.addTag(name: "生日")
        store.addCategory(name: "语言发展")

        XCTAssertEqual(store.search("生日").first?.typeLabel, "Tag")
        XCTAssertEqual(store.search("语言").first?.typeLabel, "分类")
    }

    func testAudioCanBindToPhotoAndPersistLocally() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("babytime-audio-\(UUID().uuidString).m4a")
        try Data([1, 2, 3, 4]).write(to: url)

        let storageURL = FileManager.default.temporaryDirectory.appendingPathComponent("babytime-test-\(UUID().uuidString).json")
        let store = AppStore(storageURL: storageURL)
        store.register(email: "a@b.com", password: "password", displayName: "A")
        store.createChild(nickname: "小宝", birthday: Date(), gender: "未设置", note: "")
        store.addSamplePhoto(title: "照片", note: "")
        let photo = try XCTUnwrap(store.currentPhotos.first)

        store.saveAudioFile(from: url, title: "第一句", note: "本地音频", kind: .parentMessage, duration: 3, bindTo: (.photo, photo.id))

        let audio = try XCTUnwrap(store.currentAudios.first)
        XCTAssertEqual(store.audios(for: .photo, targetID: photo.id), [audio])

        let reloaded = AppStore(storageURL: storageURL)
        reloaded.selectChild(try XCTUnwrap(reloaded.state.children.first))
        XCTAssertEqual(reloaded.currentAudios.first?.title, "第一句")
        XCTAssertEqual(reloaded.audios(for: .photo, targetID: photo.id).first?.note, "本地音频")
    }
}
