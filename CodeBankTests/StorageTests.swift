import XCTest
@testable import CodeBank

final class StorageTests: XCTestCase {
    
    // MARK: - Model Tests
    
    func testProjectCreation() {
        let project = Project(name: "Test Project", icon: "folder.fill")
        
        XCTAssertEqual(project.name, "Test Project")
        XCTAssertEqual(project.icon, "folder.fill")
        XCTAssertNotNil(project.id)
        XCTAssertNotNil(project.createdAt)
        XCTAssertNotNil(project.updatedAt)
    }
    
    func testTagCreation() {
        let tag = Tag(name: "production", color: "red")
        
        XCTAssertEqual(tag.name, "production")
        XCTAssertEqual(tag.color, "red")
        XCTAssertNotNil(tag.swiftUIColor)
    }
    
    func testItemCreation() {
        let item = Item(name: "Test API Key", type: .apiKey)
        
        XCTAssertEqual(item.name, "Test API Key")
        XCTAssertEqual(item.type, .apiKey)
        XCTAssertEqual(item.icon, "key.fill")
    }
    
    // MARK: - Item Data Tests
    
    func testAPIKeyData() {
        let data = APIKeyData(
            key: "sk_test_123",
            service: "Stripe",
            environment: "Test",
            notes: "Test key"
        )
        
        XCTAssertEqual(data.key, "sk_test_123")
        XCTAssertEqual(data.service, "Stripe")
        XCTAssertEqual(data.environment, "Test")
    }
    
    func testDatabaseData() {
        let data = DatabaseData(
            host: "localhost",
            port: 5432,
            username: "user",
            password: "pass",
            databaseName: "testdb"
        )
        
        let connectionString = data.generateConnectionString()
        XCTAssertTrue(connectionString.contains("localhost"))
        XCTAssertTrue(connectionString.contains("5432"))
        XCTAssertTrue(connectionString.contains("testdb"))
    }
    
    func testSSHData() {
        let data = SSHData(
            user: "deploy",
            host: "server.example.com",
            port: 22,
            identityKeyPath: "~/.ssh/id_rsa"
        )
        
        let command = data.sshCommand()
        XCTAssertTrue(command.contains("ssh"))
        XCTAssertTrue(command.contains("deploy@server.example.com"))
        XCTAssertTrue(command.contains("-i"))
    }
    
    func testSSHDataCustomPort() {
        let data = SSHData(
            user: "admin",
            host: "server.com",
            port: 2222
        )
        
        let command = data.sshCommand()
        XCTAssertTrue(command.contains("-p 2222"))
    }
    
    func testCommandData() {
        let data = CommandData(
            command: "ls -la",
            shell: ShellType.zsh.rawValue,
            workingDirectory: "/tmp",
            requiresConfirmation: true,
            isDangerous: false
        )
        
        let fullCommand = data.fullCommand()
        XCTAssertTrue(fullCommand.contains("cd"))
        XCTAssertTrue(fullCommand.contains("/tmp"))
        XCTAssertTrue(fullCommand.contains("ls -la"))
    }
    
    // MARK: - Item Data Codable Tests
    
    func testItemDataEncoding() throws {
        let apiKeyData = APIKeyData(key: "test", service: "Test Service")
        let itemData = ItemData.apiKey(apiKeyData)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(itemData)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ItemData.self, from: data)
        
        if case .apiKey(let decodedData) = decoded {
            XCTAssertEqual(decodedData.key, "test")
            XCTAssertEqual(decodedData.service, "Test Service")
        } else {
            XCTFail("Decoded data should be apiKey type")
        }
    }
    
    func testAllItemTypesEncodable() throws {
        let types: [ItemData] = [
            .apiKey(APIKeyData()),
            .database(DatabaseData()),
            .server(ServerData()),
            .ssh(SSHData()),
            .command(CommandData()),
            .secureNote(SecureNoteData())
        ]
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for itemData in types {
            let data = try encoder.encode(itemData)
            let _ = try decoder.decode(ItemData.self, from: data)
        }
    }
    
    // MARK: - Primary Value Tests
    
    func testPrimaryValueAPIKey() {
        let data = ItemData.apiKey(APIKeyData(key: "my_secret_key"))
        XCTAssertEqual(data.primaryValue, "my_secret_key")
    }
    
    func testPrimaryValueSSH() {
        let data = ItemData.ssh(SSHData(user: "root", host: "server.com"))
        XCTAssertEqual(data.primaryValue, "root@server.com")
    }
    
    func testPrimaryValueCommand() {
        let data = ItemData.command(CommandData(command: "echo hello"))
        XCTAssertEqual(data.primaryValue, "echo hello")
    }
    
    // MARK: - Item Properties Tests
    
    func testItemIsExecutable() {
        let commandItem = Item(name: "Test", type: .command)
        let sshItem = Item(name: "Test", type: .ssh)
        let apiKeyItem = Item(name: "Test", type: .apiKey)
        
        XCTAssertTrue(commandItem.isExecutable)
        XCTAssertTrue(sshItem.isExecutable)
        XCTAssertFalse(apiKeyItem.isExecutable)
    }
    
    func testItemIsDangerous() {
        var commandItem = Item(name: "Test", type: .command)
        var data = commandItem.commandData!
        data.isDangerous = true
        commandItem.updateCommandData(data)
        
        XCTAssertTrue(commandItem.isDangerous)
    }
}
