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
    
    /// Parse CSV string into an array of fields per row (RFC 4180 compliant)
    func parseCSV(text: String) -> [[String]] {
        var result: [[String]] = []
        let chars = Array(text)
        var currentField = ""
        var currentRecord: [String] = []
        var insideQuotes = false
        var i = 0
        
        while i < chars.count {
            let char = chars[i]
            
            if char == "\"" {
                if insideQuotes && i + 1 < chars.count && chars[i + 1] == "\"" {
                    currentField.append("\"")
                    i += 2
                    continue
                } else {
                    insideQuotes.toggle()
                    i += 1
                    continue
                }
            } else if char == "," {
                if insideQuotes {
                    currentField.append(char)
                } else {
                    currentRecord.append(currentField)
                    currentField = ""
                }
            } else if char == "\r" || char == "\n" {
                if insideQuotes {
                    currentField.append(char)
                } else {
                    currentRecord.append(currentField)
                    if !currentRecord.isEmpty && !(currentRecord.count == 1 && currentRecord[0].isEmpty) {
                        result.append(currentRecord)
                    }
                    currentRecord = []
                    currentField = ""
                    
                    if char == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" {
                        i += 1
                    }
                }
            } else {
                currentField.append(char)
            }
            i += 1
        }
        
        if !currentField.isEmpty || !currentRecord.isEmpty {
            currentRecord.append(currentField)
            result.append(currentRecord)
        }
        
        return result
    }
    
    /// Imports transactions from CSV string. Supports column auto-detection and robust formatting fallbacks.
    func importFromCSV(text: String) throws -> [TransactionDTO] {
        let records = parseCSV(text: text)
        guard !records.isEmpty else { return [] }
        
        var headerRow: [String] = []
        var dataRows = records
        
        // Check if first row is a header
        let firstRow = records[0].map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        let hasHeader = firstRow.contains("title") || firstRow.contains("amount") || firstRow.contains("название") || firstRow.contains("сумма") || firstRow.contains("id")
        
        var idIndex = -1
        var titleIndex = 0
        var amountIndex = 1
        var typeIndex = 2
        var categoryIndex = 3
        var dateIndex = 4
        var noteIndex = 5
        
        if hasHeader {
            headerRow = firstRow
            dataRows = Array(records.dropFirst())
            
            if let idx = headerRow.firstIndex(where: { $0.contains("id") || $0.contains("uuid") }) { idIndex = idx }
            if let idx = headerRow.firstIndex(where: { $0.contains("title") || $0.contains("name") || $0.contains("название") || $0.contains("описание") }) { titleIndex = idx }
            if let idx = headerRow.firstIndex(where: { $0.contains("amount") || $0.contains("value") || $0.contains("сумма") }) { amountIndex = idx }
            if let idx = headerRow.firstIndex(where: { $0.contains("type") || $0.contains("тип") }) { typeIndex = idx }
            if let idx = headerRow.firstIndex(where: { $0.contains("category") || $0.contains("категория") }) { categoryIndex = idx }
            if let idx = headerRow.firstIndex(where: { $0.contains("date") || $0.contains("дата") || $0.contains("время") }) { dateIndex = idx }
            if let idx = headerRow.firstIndex(where: { $0.contains("note") || $0.contains("comment") || $0.contains("заметка") || $0.contains("комментарий") }) { noteIndex = idx }
        }
        
        var dtos: [TransactionDTO] = []
        let dateFormatter = ISO8601DateFormatter()
        
        let altDateFormatter = DateFormatter()
        altDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let simpleDateFormatter = DateFormatter()
        simpleDateFormatter.dateFormat = "dd.MM.yyyy"
        
        for row in dataRows {
            guard row.count > max(titleIndex, amountIndex) else { continue }
            
            let title = row[titleIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            
            let amountStr = row[amountIndex].replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
            let amount = Double(amountStr) ?? 0.0
            
            let typeStr = (typeIndex >= 0 && typeIndex < row.count) ? row[typeIndex].trimmingCharacters(in: .whitespacesAndNewlines) : "Расход"
            let typeRaw: String
            let typeLower = typeStr.lowercased()
            if typeLower.contains("income") || typeLower.contains("доход") || typeLower.contains("plus") || typeLower.contains("+") {
                typeRaw = TransactionType.income.rawValue
            } else {
                typeRaw = TransactionType.expense.rawValue
            }
            
            let category = (categoryIndex >= 0 && categoryIndex < row.count) ? row[categoryIndex].trimmingCharacters(in: .whitespacesAndNewlines) : "Другое"
            
            var date = Date()
            if dateIndex >= 0 && dateIndex < row.count {
                let dateStr = row[dateIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                if let d = dateFormatter.date(from: dateStr) {
                    date = d
                } else if let d = altDateFormatter.date(from: dateStr) {
                    date = d
                } else if let d = simpleDateFormatter.date(from: dateStr) {
                    date = d
                }
            }
            
            let note = (noteIndex >= 0 && noteIndex < row.count) ? row[noteIndex].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let id = (idIndex >= 0 && idIndex < row.count ? UUID(uuidString: row[idIndex].trimmingCharacters(in: .whitespacesAndNewlines)) : nil) ?? UUID()
            
            let dto = TransactionDTO(
                id: id,
                title: title,
                amount: amount,
                type: typeRaw,
                category: category,
                date: date,
                note: note
            )
            dtos.append(dto)
        }
        
        return dtos
    }
}

// MARK: - TransactionDTO Memberwise Initializer

extension TransactionDTO {
    init(id: UUID, title: String, amount: Double, type: String, category: String, date: Date, note: String) {
        self.id = id
        self.title = title
        self.amount = amount
        self.type = type
        self.category = category
        self.date = date
        self.note = note
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
