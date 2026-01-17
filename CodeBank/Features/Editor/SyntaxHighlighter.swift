import SwiftUI
import AppKit

/// A view that displays syntax-highlighted code
struct SyntaxHighlightedCodeView: NSViewRepresentable {
    let code: String
    let language: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        updateTextView(textView)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        if let textView = scrollView.documentView as? NSTextView {
            updateTextView(textView)
        }
    }
    
    private func updateTextView(_ textView: NSTextView) {
        let highlighted = highlightCode(code, language: language)
        textView.textStorage?.setAttributedString(highlighted)
    }
    
    private func highlightCode(_ code: String, language: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: code)
        let range = NSRange(location: 0, length: code.utf16.count)
        
        // Base styling
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        
        attributed.addAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ], range: range)
        
        // Shell/Bash highlighting
        if language == "bash" || language == "sh" || language == "zsh" || language == "shell" {
            applyShellHighlighting(to: attributed, code: code)
        }
        
        return attributed
    }
    
    private func applyShellHighlighting(to attributed: NSMutableAttributedString, code: String) {
        let nsCode = code as NSString
        
        // Comments
        highlightPattern(#"#.*$"#, in: attributed, code: nsCode, color: .systemGreen, options: .anchorsMatchLines)
        
        // Strings (double quotes)
        highlightPattern(#""[^"\\]*(?:\\.[^"\\]*)*""#, in: attributed, code: nsCode, color: .systemRed)
        
        // Strings (single quotes)
        highlightPattern(#"'[^']*'"#, in: attributed, code: nsCode, color: .systemRed)
        
        // Variables
        highlightPattern(#"\$\{?[a-zA-Z_][a-zA-Z0-9_]*\}?"#, in: attributed, code: nsCode, color: .systemCyan)
        
        // Keywords
        let keywords = ["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac", "function", "return", "exit", "break", "continue", "in", "select", "until"]
        for keyword in keywords {
            highlightPattern(#"\b\#(keyword)\b"#, in: attributed, code: nsCode, color: .systemPurple)
        }
        
        // Common commands
        let commands = ["cd", "ls", "rm", "mv", "cp", "mkdir", "touch", "cat", "echo", "grep", "sed", "awk", "find", "xargs", "curl", "wget", "git", "docker", "docker-compose", "npm", "yarn", "pip", "python", "node", "ssh", "scp", "rsync"]
        for command in commands {
            highlightPattern(#"(?<=^|\s|;|&&|\|\|)\#(command)\b"#, in: attributed, code: nsCode, color: .systemBlue)
        }
        
        // Operators
        highlightPattern(#"&&|\|\||[|><&;]"#, in: attributed, code: nsCode, color: .systemOrange)
        
        // Flags
        highlightPattern(#"\s-{1,2}[a-zA-Z0-9-]+"#, in: attributed, code: nsCode, color: .systemYellow)
    }
    
    private func highlightPattern(_ pattern: String, in attributed: NSMutableAttributedString, code: NSString, color: NSColor, options: NSRegularExpression.Options = []) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        
        let range = NSRange(location: 0, length: code.length)
        let matches = regex.matches(in: code as String, options: [], range: range)
        
        for match in matches {
            attributed.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }
}

/// A simple inline syntax highlighted text view
struct SyntaxHighlightedText: View {
    let code: String
    let language: String
    
    var body: some View {
        SyntaxHighlightedCodeView(code: code, language: language)
            .frame(minHeight: 40)
    }
}

