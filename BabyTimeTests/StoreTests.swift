import XCTest
@testable import BabyTime

@MainActor
final class StoreTests: XCTestCase {
    private func makeStore() -> AppStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("babytime-test-\(UUID().uuidString).json")
        return AppStore(storageURL: url)
    }

    private func makeAuthedStoreWithChild(birthday: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!) -> AppStore {
        let store = makeStore()
        store.register(email: "parent@example.com", password: "password", displayName: "Parent")
        store.createChild(nickname: "小宝", birthday: birthday, gender: "未设置", note: "")
        return store
    }

    // MARK: - Auth

    func testRegisterLoginAndLogout() {
        let store = makeStore()
        store.register(email: "Parent@Example.com", password: "password", displayName: "Parent")
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.activeAccount?.email, "parent@example.com")
        // 登录完成后默认 Tab 应为 timeline。
        XCTAssertEqual(store.selectedTab, .timeline)

        store.logout()
        XCTAssertFalse(store.isAuthenticated)

        // 即使登录前 Tab 被切到其他位置，登录成功后也会回到 timeline。
        store.selectedTab = .settings
        store.login(email: "parent@example.com", password: "password")
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.selectedTab, .timeline)
    }

    func testRegisterRejectsInvalidInput() {
        let store = makeStore()
        store.register(email: "no-at-symbol", password: "password", displayName: "X")
        XCTAssertFalse(store.isAuthenticated)
        XCTAssertNotNil(store.errorMessage)

        store.errorMessage = nil
        store.register(email: "ok@example.com", password: "123", displayName: "X")
        XCTAssertFalse(store.isAuthenticated)
        XCTAssertNotNil(store.errorMessage)
    }

    // MARK: - Default timeline nodes

    func testCreateChildGeneratesDefaultTimelineNodes() {
        let birthday = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let store = makeAuthedStoreWithChild(birthday: birthday)

        let nodes = store.currentNodes
        // 出生第一天 + 第一周 + 第 1~12 个月 + 一周岁 = 15 个
        XCTAssertEqual(nodes.count, 15)
        XCTAssertTrue(nodes.allSatisfy(\.isDefault))
        XCTAssertEqual(nodes.first?.name, "出生第一天")
        XCTAssertEqual(nodes.last?.name, "一周岁")

        // 默认节点必须按时间正序。
        let dates = nodes.map(\.date)
        XCTAssertEqual(dates, dates.sorted())

        // 出生第一天应该恰好落在生日当天。
        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDate(nodes[0].date, inSameDayAs: birthday))
    }

    // MARK: - Add / Update / Delete node

    func testAddTimelineNodeInsertsAtCorrectPositionByDate() {
        let birthday = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let store = makeAuthedStoreWithChild(birthday: birthday)
        let originalCount = store.currentNodes.count

        // 在 100 天后插入一个自定义节点（应该位于第一周与第 4 个月之间附近）。
        let date = Calendar.current.date(byAdding: .day, value: 100, to: birthday)!
        let added = store.addTimelineNode(name: "抓周", date: date)
        XCTAssertNotNil(added)

        let nodes = store.currentNodes
        XCTAssertEqual(nodes.count, originalCount + 1)

        // 列表仍按时间正序。
        let dates = nodes.map(\.date)
        XCTAssertEqual(dates, dates.sorted())

        // 自定义节点的 isDefault == false。
        let custom = try! XCTUnwrap(nodes.first(where: { $0.name == "抓周" }))
        XCTAssertFalse(custom.isDefault)
    }

    func testAddTimelineNodeRejectsEmptyName() {
        let store = makeAuthedStoreWithChild()
        let originalCount = store.currentNodes.count
        let result = store.addTimelineNode(name: "   ", date: Date())
        XCTAssertNil(result)
        XCTAssertEqual(store.currentNodes.count, originalCount)
        XCTAssertNotNil(store.errorMessage)
    }

    func testAddTimelineNodeWithoutChildFails() {
        let store = makeStore()
        store.register(email: "a@b.com", password: "password", displayName: "A")
        let result = store.addTimelineNode(name: "随便", date: Date())
        XCTAssertNil(result)
        XCTAssertNotNil(store.errorMessage)
    }

    func testAddTimelineNodeDeduplicatesSameDayAndName() {
        let store = makeAuthedStoreWithChild()
        let date = Date()
        let first = try! XCTUnwrap(store.addTimelineNode(name: "重复", date: date))
        let second = try! XCTUnwrap(store.addTimelineNode(name: "重复", date: date))
        // 重名不再追加新节点。
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(store.currentNodes.filter { $0.name == "重复" }.count, 1)
    }

    func testUpdateTimelineNode() {
        let store = makeAuthedStoreWithChild()
        let original = try! XCTUnwrap(store.currentNodes.first)
        let newDate = Calendar.current.date(byAdding: .day, value: 3, to: original.date)!
        store.updateTimelineNode(original, name: "改名后", date: newDate)

        let updated = try! XCTUnwrap(store.state.nodes.first { $0.id == original.id })
        XCTAssertEqual(updated.name, "改名后")
        XCTAssertEqual(updated.date, newDate)
    }

    func testDeleteTimelineNodeUnlinksRelatedMedia() throws {
        let store = makeAuthedStoreWithChild()
        let node = try XCTUnwrap(store.currentNodes.first)

        // 在节点上挂一张照片和一段音频。
        let photo = try XCTUnwrap(store.addSamplePhoto(title: "样例", note: "", date: node.date, nodeID: node.id))
        XCTAssertEqual(photo.nodeID, node.id)

        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("audio-\(UUID().uuidString).m4a")
        try Data([0, 1, 2]).write(to: audioURL)
        store.saveAudioFile(from: audioURL, title: "音频", note: "", kind: .parentMessage, duration: 1, bindTo: nil, nodeID: node.id)
        let audio = try XCTUnwrap(store.currentAudios.first)
        XCTAssertEqual(audio.nodeID, node.id)

        store.deleteTimelineNode(node)

        // 节点被删，但照片和音频仍保留，只是 nodeID 置空。
        XCTAssertNil(store.state.nodes.first { $0.id == node.id })
        let updatedPhoto = try XCTUnwrap(store.state.photos.first { $0.id == photo.id })
        XCTAssertNil(updatedPhoto.nodeID)
        let updatedAudio = try XCTUnwrap(store.state.audios.first { $0.id == audio.id })
        XCTAssertNil(updatedAudio.nodeID)
    }

    // MARK: - Photo ↔ Node 关联与解除

    func testSamplePhotoAutoAttachesToBestMatchingNode() throws {
        let birthday = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let store = makeAuthedStoreWithChild(birthday: birthday)

        // 在出生后 5 天拍的照片应该落在 “出生第一周” 节点。
        let date = Calendar.current.date(byAdding: .day, value: 5, to: birthday)!
        _ = store.addSamplePhoto(title: "5天", note: "", date: date)

        let photo = try XCTUnwrap(store.currentPhotos.first)
        let attachedNode = try XCTUnwrap(photo.nodeID.flatMap { id in store.state.nodes.first { $0.id == id } })
        XCTAssertEqual(attachedNode.name, "出生第一周")
    }

    func testPhotosForNodeReturnsOnlyAttachedPhotos() throws {
        let store = makeAuthedStoreWithChild()
        let node = try XCTUnwrap(store.currentNodes.first)

        let attached = try XCTUnwrap(store.addSamplePhoto(title: "已挂载", note: "", date: node.date, nodeID: node.id))
        // 显式不挂载到节点。
        _ = store.addSamplePhoto(title: "未挂载", note: "", date: node.date, nodeID: UUID())

        let photos = store.photos(forNode: node.id)
        XCTAssertEqual(photos.count, 1)
        XCTAssertEqual(photos.first?.id, attached.id)
    }

    func testAttachPhotoToNode() throws {
        let store = makeAuthedStoreWithChild()
        let node = try XCTUnwrap(store.currentNodes.first)

        // 创建一张没挂任何节点的照片。
        _ = store.addSamplePhoto(title: "孤儿", note: "", date: node.date, nodeID: UUID())
        let orphan = try XCTUnwrap(store.currentPhotos.first { $0.nodeID != node.id })

        store.attachPhoto(photoID: orphan.id, toNode: node.id)
        let updated = try XCTUnwrap(store.state.photos.first { $0.id == orphan.id })
        XCTAssertEqual(updated.nodeID, node.id)
    }

    func testRemovePhotoFromNodeOnlyDetachesAssociation() throws {
        let store = makeAuthedStoreWithChild()
        let node = try XCTUnwrap(store.currentNodes.first)
        let photo = try XCTUnwrap(store.addSamplePhoto(title: "待解除", note: "", date: node.date, nodeID: node.id))
        XCTAssertEqual(store.photos(forNode: node.id).count, 1)

        store.removePhotoFromNode(photoID: photo.id, nodeID: node.id)

        // 与该节点的关联应被清除。
        XCTAssertEqual(store.photos(forNode: node.id).count, 0)
        // 但照片记录本身仍然存在（只是 nodeID 置空）。
        let stillThere = try XCTUnwrap(store.state.photos.first { $0.id == photo.id })
        XCTAssertNil(stillThere.nodeID)
        XCTAssertEqual(store.currentPhotos.count, 1)
    }

    func testRemovePhotoFromNodeIgnoresOtherNodes() throws {
        let store = makeAuthedStoreWithChild()
        let nodeA = try XCTUnwrap(store.currentNodes.first)
        let nodeB = try XCTUnwrap(store.currentNodes.dropFirst().first)
        let photo = try XCTUnwrap(store.addSamplePhoto(title: "属于A", note: "", date: nodeA.date, nodeID: nodeA.id))

        // 用 B 的 id 来"误"删除：不应该解除照片与 A 的关联。
        store.removePhotoFromNode(photoID: photo.id, nodeID: nodeB.id)
        let still = try XCTUnwrap(store.state.photos.first { $0.id == photo.id })
        XCTAssertEqual(still.nodeID, nodeA.id)
    }

    // MARK: - 首页聚合视图

    func testTimelineSummariesShowPreviewAndCounts() throws {
        let birthday = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let store = makeAuthedStoreWithChild(birthday: birthday)
        let node = try XCTUnwrap(store.currentNodes.first { $0.name == "出生第一天" })

        // 给该节点添加 5 张照片。
        for i in 0..<5 {
            _ = store.addSamplePhoto(title: "p\(i)", note: "", date: node.date, nodeID: node.id)
        }

        let summary = try XCTUnwrap(store.timelineSummaries().first { $0.node.id == node.id })
        XCTAssertEqual(summary.totalPhotoCount, 5)
        // 首页只展示前 3 张。
        XCTAssertEqual(summary.previewPhotos.count, 3)

        // 检查别的节点（没有照片的）应该是 0 张，前端会展示"去添加"占位。
        let empty = try XCTUnwrap(store.timelineSummaries().first { $0.totalPhotoCount == 0 })
        XCTAssertEqual(empty.previewPhotos.count, 0)
    }

    func testTimelineSummariesPreviewLessThanThreeShowsAll() throws {
        let store = makeAuthedStoreWithChild()
        let node = try XCTUnwrap(store.currentNodes.first)
        _ = store.addSamplePhoto(title: "p1", note: "", date: node.date, nodeID: node.id)
        _ = store.addSamplePhoto(title: "p2", note: "", date: node.date, nodeID: node.id)
        let summary = try XCTUnwrap(store.timelineSummaries().first { $0.node.id == node.id })
        XCTAssertEqual(summary.totalPhotoCount, 2)
        XCTAssertEqual(summary.previewPhotos.count, 2)
    }

    // MARK: - 兼容性 / 其它业务

    func testAddPhotoCreateCollectionAndSearch() throws {
        let store = makeAuthedStoreWithChild()
        _ = store.addSamplePhoto(title: "满月笑脸", note: "第一次笑")
        let photo = try XCTUnwrap(store.currentPhotos.first)
        store.createCollection(title: "满月照", note: "纪念日", photoIDs: [photo.id], layoutTemplate: "grid")

        XCTAssertEqual(store.currentPhotos.count, 1)
        XCTAssertEqual(store.currentCollections.count, 1)
        XCTAssertTrue(store.search("笑脸").contains(.photo(photo)))
        XCTAssertTrue(store.search("满月照").contains(.collection(store.currentCollections[0])))
    }

    func testCollectionCanBeEditedAndTaggedLocally() throws {
        let store = makeAuthedStoreWithChild()
        _ = store.addSamplePhoto(title: "封面照片", note: "")
        _ = store.addSamplePhoto(title: "第二张", note: "")
        let photos = store.currentPhotos
        store.createCollection(title: "旧标题", note: "", photoIDs: photos.map(\.id), layoutTemplate: "grid")
        store.addTag(name: "满月")
        let collection = try XCTUnwrap(store.currentCollections.first)
        let cover = try XCTUnwrap(photos.first)
        let tag = try XCTUnwrap(store.state.tags.first)

        store.updateCollection(collection, title: "满月合集", note: "本地备注", layoutTemplate: "cover", coverPhotoID: cover.id)
        store.attach(tagID: tag.id, toCollection: collection.id)

        let updated = try XCTUnwrap(store.currentCollections.first)
        XCTAssertEqual(updated.title, "满月合集")
        XCTAssertEqual(updated.note, "本地备注")
        XCTAssertEqual(updated.layoutTemplate, "cover")
        XCTAssertEqual(updated.coverPhotoID, cover.id)
        XCTAssertTrue(store.search("满月").contains(.collection(updated)))
    }

    func testImportPhotoStoresAssetIdentifierAndMissingState() throws {
        let store = makeAuthedStoreWithChild()
        _ = store.importPhoto(assetIdentifier: "missing-local-asset", title: "本机索引照片", note: "")

        let photo = try XCTUnwrap(store.currentPhotos.first)
        XCTAssertEqual(photo.localAssetIdentifier, "missing-local-asset")
        XCTAssertEqual(photo.localAssetStatus, .missing)
    }

    func testSearchFindsNodeTagAndCategory() {
        let store = makeAuthedStoreWithChild()
        store.addTag(name: "生日")
        store.addCategory(name: "语言发展")

        XCTAssertTrue(store.search("生日").contains { $0.typeLabel == "Tag" })
        XCTAssertTrue(store.search("语言").contains { $0.typeLabel == "分类" })
        // 默认节点名应该能搜到。
        XCTAssertTrue(store.search("一周岁").contains { $0.typeLabel == "时间节点" })
    }

    func testTagsCategoriesAndBindings() throws {
        let store = makeAuthedStoreWithChild()
        _ = store.addSamplePhoto(title: "语言发展", note: "")
        store.addTag(name: "牙牙学语")
        let photo = try XCTUnwrap(store.currentPhotos.first)
        let tag = try XCTUnwrap(store.state.tags.first)
        let category = try XCTUnwrap(store.state.categories.first)

        store.attach(tagID: tag.id, toPhoto: photo.id)
        store.attach(categoryID: category.id, toPhoto: photo.id)

        let updated = try XCTUnwrap(store.currentPhotos.first)
        XCTAssertEqual(updated.tagIDs, [tag.id])
        XCTAssertEqual(updated.categoryIDs, [category.id])
        XCTAssertTrue(store.search("牙牙学语").contains(.photo(updated)))
    }

    func testAudioCanBindToPhotoAndPersistLocally() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("babytime-audio-\(UUID().uuidString).m4a")
        try Data([1, 2, 3, 4]).write(to: url)

        let storageURL = FileManager.default.temporaryDirectory.appendingPathComponent("babytime-test-\(UUID().uuidString).json")
        let store = AppStore(storageURL: storageURL)
        store.register(email: "a@b.com", password: "password", displayName: "A")
        store.createChild(nickname: "小宝", birthday: Date(), gender: "未设置", note: "")
        _ = store.addSamplePhoto(title: "照片", note: "")
        let photo = try XCTUnwrap(store.currentPhotos.first)

        store.saveAudioFile(from: url, title: "第一句", note: "本地音频", kind: .parentMessage, duration: 3, bindTo: (.photo, photo.id))

        let audio = try XCTUnwrap(store.currentAudios.first)
        XCTAssertEqual(store.audios(for: .photo, targetID: photo.id), [audio])

        let reloaded = AppStore(storageURL: storageURL)
        reloaded.selectChild(try XCTUnwrap(reloaded.state.children.first))
        XCTAssertEqual(reloaded.currentAudios.first?.title, "第一句")
        XCTAssertEqual(reloaded.audios(for: .photo, targetID: photo.id).first?.note, "本地音频")
    }

    func testAudioCanBindToNode() throws {
        let store = makeAuthedStoreWithChild()
        let node = try XCTUnwrap(store.currentNodes.first)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("babytime-audio-\(UUID().uuidString).m4a")
        try Data([7, 7, 7]).write(to: url)
        store.saveAudioFile(from: url, title: "节点音频", note: "", kind: .moment, duration: 2, bindTo: (.node, node.id))

        let audios = store.audios(forNode: node.id)
        XCTAssertEqual(audios.count, 1)
        XCTAssertEqual(audios.first?.title, "节点音频")
        XCTAssertEqual(audios.first?.nodeID, node.id)
    }
}
