//
//  AssessmentArchiveBuilder.swift
//  
//

import Foundation
import JsonModel
import ResultModel
import BridgeClient

/// The archive builder is used to allow for inheritance patterns where the builder
/// needs to inherit from something other than the archive itself. This is used to
/// support older code that uses a UIViewController or `RSDTaskViewModel`.
public protocol ArchiveBuilder : AnyObject {
    
    /// A unique identifier that can be used to retain this task until it is complete.
    var uuid: UUID { get }

    /// An identifier that can be logging reports.
    var identifier: String { get }

    /// Build an archive asyncronously and return the result.
    func buildArchive() async throws -> DataArchive
    
    /// Cleanup after.
    func cleanup() async throws
}

/// Extends the archive builder to support saving adherence scoring to the `clientData`
/// property on an `AdherenceRecord` and to allow matching an adherence record to an
/// associated upload request.
public protocol ResultArchiveBuilder : ArchiveBuilder {
    
    /// A timestamp for tracking the archive.
    var startedOn: Date { get }
    
    /// A timestamp for tracking the archive.
    var endedOn: Date { get }
    
    /// Any adherence data that should be added to the adherence record. Limit 64kb.
    var adherenceData: JsonSerializable? { get }
}

/// The archive builder to use with an assessment result.
open class AssessmentArchiveBuilder : ResultArchiveBuilder {

    /// The result to be processed for archive and upload.
    public let assessmentResult: AssessmentResult
    
    /// File URL for the directory in which generated data files that are referenced using `FileResult`
    /// may be included. Asynchronous actions with recorders (and potentially steps) can save data to
    /// files during the progress of the task. This property specifies where such data was being written to
    /// allow the archive to delete the output directory once the results have been archived and encrypted
    /// for upload.
    let outputDirectory: URL?
    
    /// The archive that backs this builder.
    let archive: StudyDataUploadArchive
    
    public var identifier: String {
        archive.identifier
    }
    
    @available(*, deprecated, message: "Bridge Exporter V1 and V2 are no longer supported - schema identifier and revision are ignored.")
    public convenience init?(_ assessmentResult: AssessmentResult,
                 schedule: AssessmentScheduleInfo? = nil,
                 adherenceData: JsonSerializable? = nil,
                 outputDirectory: URL? = nil,
                 schemaIdentifier: String?,
                 schemaRevision: Int?,
                 dataGroups: [String]? = nil,
                 v2Format: BridgeUploaderInfoV2.FormatVersion = .v2_generic) {
        self.init(assessmentResult, schedule: schedule, adherenceData: adherenceData, outputDirectory: outputDirectory, dataGroups: dataGroups)
    }
    
    public init?(_ assessmentResult: AssessmentResult,
                 schedule: AssessmentScheduleInfo? = nil,
                 adherenceData: JsonSerializable? = nil,
                 outputDirectory: URL? = nil,
                 dataGroups: [String]? = nil) {
        self.assessmentResult = assessmentResult
        self.adherenceData = adherenceData?.appendingClientInfo()
        self.outputDirectory = outputDirectory
        guard let archive = StudyDataUploadArchive(identifier: assessmentResult.identifier,
                                                   schedule: schedule,
                                                   dataGroups: dataGroups)
        else {
            return nil
        }
        self.archive = archive
    }
    
    public var uuid: UUID { assessmentResult.taskRunUUID }
    public var startedOn: Date { assessmentResult.startDate }
    public var endedOn: Date { assessmentResult.endDate }
    public private(set) var adherenceData: JsonSerializable?
    
    public func cleanup() async throws {
        try outputDirectory.map {
            try FileManager.default.removeItem(at: $0)
        }
    }
    
    public func buildArchive() async throws -> DataArchive {

        // Iterate through all the results within this collection and add if they are `FileArchivable`.
        try addBranchResults(assessmentResult)
        
        // For assessment results that include "answer" results, create an "answers.json" file.
        if !answers.isEmpty {
            do {
                let data = try JSONSerialization.data(withJSONObject: answers, options: [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys])
                let schemaURL = URL(string: "answers_schema.json")!
                let jsonSchema = JsonSchema(id: schemaURL,
                                            description: assessmentResult.identifier,
                                            isArray: false,
                                            codingKeys: [],
                                            interfaces: nil,
                                            definitions: [],
                                            properties: answersProperties,
                                            required: nil,
                                            examples: nil)
                let manifestInfo = FileInfo(filename: "answers.json",
                                            timestamp: assessmentResult.endDate,
                                            contentType: "application/json",
                                            jsonSchema: schemaURL)
                try archive.addFile(data: data, fileInfo: manifestInfo, localSchema: jsonSchema)
            } catch {
                Logger.log(tag: .upload, error: error, message: "Failed to create answers file for \(assessmentResult.identifier)")
            }
        }
        
        // Add the top-level assessment if desired.
        if let (data, manifestInfo) = try assessmentResultFile() {
            try archive.addFile(data: data, fileInfo: manifestInfo)
        }
        
        // Close the archive.
        try archive.completeArchive()
        
        return archive
    }
    
    var answers: [String : JsonSerializable] = [:]
    var answersProperties: [String : JsonSchemaProperty] = [:]
    
    private func addBranchResults(_ branchResult: BranchNodeResult, _ stepPath: String? = nil) throws {
        try recursiveAddFiles(branchResult.stepHistory, stepPath)
        if let asyncResults = branchResult.asyncResults {
            try recursiveAddFiles(asyncResults, stepPath)
        }
    }
    
    private func recursiveAddFiles(_ results: [ResultData], _ stepPath: String? = nil) throws {
        try results.forEach {
            try recursiveAdd($0, stepPath)
        }
    }
    
    private func recursiveAdd(_ result: ResultData, _ stepPath: String? = nil) throws {
        let pathSuffix = stepPath.map { "\($0)/" } ?? ""
        let path = "\(pathSuffix)\(result.identifier)"
        
        if let branchResult = result as? BranchNodeResult {
            try addBranchResults(branchResult, path)
        }
        else if let collectionResult = result as? CollectionResult {
            try recursiveAddFiles(collectionResult.children, path)
        }
        else if let fileArchivable = result as? FileArchivable,
                let (fileInfo, data) = try fileArchivable.buildArchivableFileData(at: stepPath),
                let manifestInfo = manifestFileInfo(for: fileArchivable, fileInfo: fileInfo) {
            try archive.addFile(data: data, fileInfo: manifestInfo)
        }
        else if let answer = result as? AnswerResult,
                let (value, jsonType) = answer.flatAnswer() {
            let key = path.replacingOccurrences(of: "/", with: "_")
            answers[key] = value
            answersProperties[key] = .primitive(.init(jsonType: jsonType, description: answer.questionText))
        }
    }
    
    /// Return the FileInfo to use when including a file in the archive. This method is included to allow applications
    /// to modify the structure of an archive for assessments that were developed for use with Bridge Exporter 2.0.
    ///
    /// - returns: The `FileInfo` to use to add this file to the archive. If `nil` then the file should be skipped.
    open func manifestFileInfo(for result: FileArchivable, fileInfo: FileInfo) -> FileInfo? {
        fileInfo
    }
    
    /// The top-level assessment result file to include in the archive (if any).
    open func assessmentResultFile() throws -> (Data, FileInfo)? {
        guard let result = assessmentResult as? AssessmentResultObject else {
            return nil
        }
        let data = try result.jsonEncodedData()
        let fileInfo = FileInfo(filename: "assessmentResult.json",
                                timestamp: result.endDate,
                                contentType: "application/json",
                                identifier: result.identifier,
                                jsonSchema: result.jsonSchema)
        return (data, fileInfo)
    }
}

extension AnswerResult {
    func flatAnswer() -> (value: JsonSerializable?, jsonType: JsonType)? {
        // Exit early for types that are not supported
        guard let baseType = jsonAnswerType?.baseType ?? jsonValue?.jsonType,
              baseType != .null
        else {
            return nil
        }

        // If the value is null then exit early with a null value
        guard let value = jsonValue else {
            return (nil, baseType == .array ? .string : baseType)
        }
        
        switch value {
        case .boolean(let value):
            return (value, baseType)
        case .string(let value):
            return (value, baseType)
        case .integer(let value):
            return (value, baseType)
        case .number(let value):
            return (value.jsonNumber(), baseType)
        case .array(let value):
            return (value.map { "\($0)" }.joined(separator: ","), .string)
        case .object(let value):
            return (value, baseType)    // objects are supported as a json blob only
        default:
            return nil
        }
    }
}

fileprivate extension Dictionary where Key == String, Value == JsonSerializable {
    
    mutating func setIfNil(_ key: Key, _ value: Value) {
        guard self[key] == nil else { return }
        self[key] = value
    }
}

fileprivate extension JsonSerializable {
    
    func appendingClientInfo() -> JsonSerializable {
        guard let json = self as? [String : JsonSerializable]
        else {
            return self
        }
        let platform = IOSBridgeConfig()
        var dictionary = json
        dictionary.setIfNil("osName", platform.osName)
        dictionary.setIfNil("deviceName", platform.deviceName)
        dictionary.setIfNil("osVersion", platform.osVersion)
        dictionary.setIfNil("appVersion", platform.appVersion)
        return dictionary
    }
}
