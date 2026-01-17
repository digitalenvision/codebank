import XCTest
@testable import CodeBank

final class ImportExportTests: XCTestCase {
    
    // MARK: - Export File Format Tests
    
    func testExportFileStructure() throws {
        let exportFile = ExportFile(
            version: "1.0",
            exportDate: Date(),
            appVersion: "1.0.0",
            encrypted: false,
            projects: [Project(name: "Test")],
            items: [],
            tags: []
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportFile)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportFile.self, from: data)
        
        XCTAssertEqual(decoded.version, "1.0")
        XCTAssertEqual(decoded.appVersion, "1.0.0")
        XCTAssertFalse(decoded.encrypted)
        XCTAssertEqual(decoded.projects?.count, 1)
    }
    
    func testEncryptedExportFileStructure() throws {
        let exportFile = ExportFile(
            version: "1.0",
            exportDate: Date(),
            appVersion: "1.0.0",
            encrypted: true,
            salt: KeyDerivation.generateSalt(),
            encryptedData: Data([1, 2, 3, 4])
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportFile)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportFile.self, from: data)
        
        XCTAssertTrue(decoded.encrypted)
        XCTAssertNotNil(decoded.salt)
        XCTAssertNotNil(decoded.encryptedData)
        XCTAssertNil(decoded.projects)
    }
    
    // MARK: - Export Data Tests
    
    func testExportDataEncodeDecode() throws {
        let project = Project(name: "Test Project")
        let tag = Tag(name: "test-tag", color: "blue")
        let item = Item(name: "Test Item", type: .apiKey, projectId: project.id)
        
        let exportData = ExportData(
            version: "1.0",
            exportDate: Date(),
            appVersion: "1.0.0",
            projects: [project],
            items: [item],
            tags: [tag]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportData.self, from: data)
        
        XCTAssertEqual(decoded.projects.count, 1)
        XCTAssertEqual(decoded.items.count, 1)
        XCTAssertEqual(decoded.tags.count, 1)
        XCTAssertEqual(decoded.projects.first?.name, "Test Project")
    }
    
    // MARK: - Filename Generation Tests
    
    func testExportFilenameGeneration() {
        let service = ImportExportService.shared
        
        let encryptedFilename = service.generateExportFilename(encrypted: true)
        XCTAssertTrue(encryptedFilename.contains("CodeBank"))
        XCTAssertTrue(encryptedFilename.contains("encrypted"))
        XCTAssertTrue(encryptedFilename.hasSuffix(".codebank"))
        
        let plaintextFilename = service.generateExportFilename(encrypted: false)
        XCTAssertTrue(plaintextFilename.contains("plaintext"))
    }
    
    // MARK: - Item Types Export Tests
    
    func testAllItemTypesExportable() throws {
        let items: [Item] = [
            Item(name: "API Key", type: .apiKey, data: .apiKey(APIKeyData(key: "test"))),
            Item(name: "Database", type: .database, data: .database(DatabaseData(host: "localhost"))),
            Item(name: "Server", type: .server, data: .server(ServerData(hostname: "server.com"))),
            Item(name: "SSH", type: .ssh, data: .ssh(SSHData(user: "root", host: "server.com"))),
            Item(name: "Command", type: .command, data: .command(CommandData(command: "ls"))),
            Item(name: "Note", type: .secureNote, data: .secureNote(SecureNoteData(content: "secret")))
        ]
        
        let exportData = ExportData(
            version: "1.0",
            exportDate: Date(),
            appVersion: "1.0.0",
            projects: [],
            items: items,
            tags: []
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportData.self, from: data)
        
        XCTAssertEqual(decoded.items.count, 6)
        
        // Verify each type was preserved
        let types = decoded.items.map { $0.type }
        XCTAssertTrue(types.contains(.apiKey))
        XCTAssertTrue(types.contains(.database))
        XCTAssertTrue(types.contains(.server))
        XCTAssertTrue(types.contains(.ssh))
        XCTAssertTrue(types.contains(.command))
        XCTAssertTrue(types.contains(.secureNote))
    }
    
    // MARK: - Encryption Roundtrip Tests
    
    func testEncryptedExportRoundtrip() throws {
        let password = "testPassword123!"
        let salt = KeyDerivation.generateSalt()
        let key = try KeyDerivation.deriveKey(from: password, salt: salt)
        
        let exportData = ExportData(
            version: "1.0",
            exportDate: Date(),
            appVersion: "1.0.0",
            projects: [Project(name: "Test")],
            items: [Item(name: "Test Item", type: .apiKey)],
            tags: []
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(exportData)
        
        // Encrypt
        let encryptedData = try EncryptionEngine.encrypt(jsonData, key: key)
        
        // Decrypt
        let decryptedData = try EncryptionEngine.decrypt(encryptedData, key: key)
        
        // Decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportData.self, from: decryptedData)
        
        XCTAssertEqual(decoded.projects.count, 1)
        XCTAssertEqual(decoded.items.count, 1)
    }
}
