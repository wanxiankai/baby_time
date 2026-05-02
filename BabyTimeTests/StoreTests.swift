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
    }

    func testSearchFindsTaxonomy() {
        let store = makeStore()
        store.addTag(name: "生日")
        store.addCategory(name: "语言发展")

        XCTAssertEqual(store.search("生日").first?.typeLabel, "Tag")
        XCTAssertEqual(store.search("语言").first?.typeLabel, "分类")
    }
}
