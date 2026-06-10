import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SwiftData

// MARK: - File Documents

struct FinanceJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            self.data = data
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct FinanceCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .text] }
    
    var text: String
    
    init(text: String) {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let decoded = String(data: data, encoding: .utf8) {
            self.text = decoded
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - FinanceImportExportService

final class FinanceImportExportService {
    static let shared = FinanceImportExportService()
    
    private init() {}
    
    /// Export transactions to CSV formatted string
    func exportToCSV(transactions: [Transaction]) -> String {
        var csv = "ID,Title,Amount,Type,Category,Date,Note\n"
        let formatter = ISO8601DateFormatter()
        
        for tx in transactions {
            let idStr = tx.id.uuidString
            let titleStr = tx.title.escapedCSVField
            let amountStr = String(format: "%.2f", tx.amount)
            let typeStr = tx.type.rawValue
            let catStr = tx.category.escapedCSVField
            let dateStr = formatter.string(from: tx.date)
            let noteStr = tx.note.escapedCSVField
            
            csv += "\(idStr),\(titleStr),\(amountStr),\(typeStr),\(catStr),\(dateStr),\(noteStr)\n"
        }
        return csv
    }
    
    /// Export transactions to JSON Data representation of [TransactionDTO]
    func exportToJSON(transactions: [Transaction]) throws -> Data {
        let dtos = transactions.map { TransactionDTO(from: $0) }
        let encoder = Foundation.JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(dtos)
    }
    
    /// Imports transactions from JSON data. Supports both [TransactionDTO] and SyncPayload formats.
    func importFromJSON(data: Data) throws -> [TransactionDTO] {
        let decoder = Foundation.JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Try decoding directly as a list of TransactionDTO
        if let list = try? decoder.decode([TransactionDTO].self, from: data) {
            return list
        }
        
        // Fallback: try decoding as iCloud SyncPayload
        if let payload = try? decoder.decode(SyncPayload.self, from: data) {
            return payload.transactions
        }
        
        throw CocoaError(.fileReadCorruptFile)
    }
}

// MARK: - Helpers

extension String {
    var escapedCSVField: String {
        if contains(",") || contains("\"") || contains("\n") || contains("\r") {
            let escaped = replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return self
    }
}
