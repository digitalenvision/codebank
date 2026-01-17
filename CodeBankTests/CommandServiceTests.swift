import XCTest
@testable import CodeBank

final class CommandServiceTests: XCTestCase {
    
    // MARK: - Shell Escaping Tests
    
    func testShellEscapingSimple() {
        let input = "hello world"
        let escaped = input.shellEscaped
        XCTAssertEqual(escaped, "'hello world'")
    }
    
    func testShellEscapingWithSingleQuotes() {
        let input = "it's a test"
        let escaped = input.shellEscaped
        XCTAssertEqual(escaped, "'it'\\''s a test'")
    }
    
    func testDoubleQuoteEscaping() {
        let input = "say \"hello\""
        let escaped = input.doubleQuoteEscaped
        XCTAssertTrue(escaped.contains("\\\""))
    }
    
    func testDoubleQuoteEscapingDollarSign() {
        let input = "$HOME/path"
        let escaped = input.doubleQuoteEscaped
        XCTAssertTrue(escaped.contains("\\$"))
    }
    
    // MARK: - SSH Command Generation Tests
    
    func testSSHCommandBasic() {
        let data = SSHData(user: "root", host: "server.com")
        let command = data.sshCommand()
        
        XCTAssertEqual(command, "ssh root@server.com")
    }
    
    func testSSHCommandWithCustomPort() {
        let data = SSHData(user: "admin", host: "server.com", port: 2222)
        let command = data.sshCommand()
        
        XCTAssertEqual(command, "ssh -p 2222 admin@server.com")
    }
    
    func testSSHCommandWithIdentityKey() {
        let data = SSHData(
            user: "deploy",
            host: "server.com",
            port: 22,
            identityKeyPath: "~/.ssh/deploy_key"
        )
        let command = data.sshCommand()
        
        XCTAssertTrue(command.contains("-i"))
        XCTAssertTrue(command.contains("deploy_key"))
        XCTAssertTrue(command.contains("deploy@server.com"))
    }
    
    func testSSHCommandWithAllOptions() {
        let data = SSHData(
            user: "admin",
            host: "example.com",
            port: 3022,
            identityKeyPath: "/path/to/key"
        )
        let command = data.sshCommand()
        
        XCTAssertTrue(command.hasPrefix("ssh"))
        XCTAssertTrue(command.contains("-p 3022"))
        XCTAssertTrue(command.contains("-i"))
        XCTAssertTrue(command.contains("admin@example.com"))
    }
    
    // MARK: - Command Data Tests
    
    func testCommandFullCommandWithWorkingDirectory() {
        let data = CommandData(
            command: "ls -la",
            workingDirectory: "/tmp"
        )
        let fullCommand = data.fullCommand()
        
        XCTAssertEqual(fullCommand, "cd \"/tmp\" && ls -la")
    }
    
    func testCommandFullCommandWithoutWorkingDirectory() {
        let data = CommandData(command: "echo hello")
        let fullCommand = data.fullCommand()
        
        XCTAssertEqual(fullCommand, "echo hello")
    }
    
    func testCommandFullCommandWithTildePath() {
        let data = CommandData(
            command: "git status",
            workingDirectory: "~/projects"
        )
        let fullCommand = data.fullCommand()
        
        XCTAssertTrue(fullCommand.contains("cd"))
        XCTAssertTrue(fullCommand.contains("~/projects"))
    }
    
    // MARK: - Command Preview Tests
    
    func testCommandPreview() {
        let item = Item(
            name: "Test Command",
            type: .command,
            data: .command(CommandData(command: "docker ps -a"))
        )
        
        let preview = CommandService.shared.previewCommand(item)
        XCTAssertEqual(preview, "docker ps -a")
    }
    
    func testSSHPreview() {
        let item = Item(
            name: "Test SSH",
            type: .ssh,
            data: .ssh(SSHData(user: "root", host: "server.com", port: 22))
        )
        
        let preview = CommandService.shared.previewCommand(item)
        XCTAssertEqual(preview, "ssh root@server.com")
    }
    
    func testPreviewNonExecutableItem() {
        let item = Item(name: "API Key", type: .apiKey)
        
        let preview = CommandService.shared.previewCommand(item)
        XCTAssertNil(preview)
    }
    
    // MARK: - String Extension Tests
    
    func testTildeExpansion() {
        let path = "~/Documents"
        let expanded = path.expandingTildeInPath
        
        XCTAssertFalse(expanded.contains("~"))
        XCTAssertTrue(expanded.hasPrefix("/"))
    }
    
    func testTildeAbbreviation() {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        let abbreviated = homePath.abbreviatingWithTildeInPath
        
        XCTAssertTrue(abbreviated.hasPrefix("~"))
    }
    
    func testStringMasking() {
        let secret = "sk_live_1234567890abcdef"
        let masked = secret.masked()
        
        XCTAssertTrue(masked.hasPrefix("sk_l"))
        XCTAssertTrue(masked.hasSuffix("cdef"))
        XCTAssertTrue(masked.contains("•"))
    }
    
    func testStringMaskingShort() {
        let secret = "abc"
        let masked = secret.masked()
        
        XCTAssertEqual(masked, "•••")
    }
    
    func testStringTruncation() {
        let long = "This is a very long string that needs to be truncated"
        let truncated = long.truncated(to: 20)
        
        XCTAssertEqual(truncated.count, 20)
        XCTAssertTrue(truncated.hasSuffix("…"))
    }
    
    func testStringTruncationShort() {
        let short = "Hello"
        let truncated = short.truncated(to: 20)
        
        XCTAssertEqual(truncated, "Hello")
    }
    
    // MARK: - Shell Argument Splitting Tests
    
    func testShellArgumentSplittingSimple() {
        let command = "ls -la /tmp"
        let args = command.splitShellArguments()
        
        XCTAssertEqual(args, ["ls", "-la", "/tmp"])
    }
    
    func testShellArgumentSplittingWithQuotes() {
        let command = "echo \"hello world\""
        let args = command.splitShellArguments()
        
        XCTAssertEqual(args, ["echo", "hello world"])
    }
    
    func testShellArgumentSplittingWithSingleQuotes() {
        let command = "echo 'hello world'"
        let args = command.splitShellArguments()
        
        XCTAssertEqual(args, ["echo", "hello world"])
    }
    
    // MARK: - Validation Tests
    
    func testValidHostname() {
        XCTAssertTrue("example.com".isValidHostname)
        XCTAssertTrue("sub.example.com".isValidHostname)
        XCTAssertTrue("server-1.example.com".isValidHostname)
        XCTAssertFalse("-invalid.com".isValidHostname)
    }
    
    func testValidIPAddress() {
        XCTAssertTrue("192.168.1.1".isValidIPAddress)
        XCTAssertTrue("10.0.0.1".isValidIPAddress)
        XCTAssertFalse("256.1.1.1".isValidIPAddress)
        XCTAssertFalse("not.an.ip".isValidIPAddress)
    }
    
    func testValidPort() {
        XCTAssertTrue("22".isValidPort)
        XCTAssertTrue("80".isValidPort)
        XCTAssertTrue("65535".isValidPort)
        XCTAssertFalse("0".isValidPort)
        XCTAssertFalse("65536".isValidPort)
        XCTAssertFalse("abc".isValidPort)
    }
}
