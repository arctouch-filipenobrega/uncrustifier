//
//  SourceEditorCommand.swift
//  Uncrustifier
//
//  Created by Nook Harquail on 9/9/16
//

import Foundation
import XcodeKit

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    
    static let cfgOptionsPath = Bundle.main.path(forResource: "cfgOptions", ofType: "plist")!
    static let cfgOptions = NSDictionary(contentsOfFile: cfgOptionsPath) as! [String: String]
    
    var commandPath: String {
        return Bundle.main.path(forResource: "uncrustify", ofType: nil)!
    }
    
    var commandConfigPath: String {
        let selection = SharedFileManager.readSelection()!
        
        
        // if config option is in cfgOptions plist, use bundled config
        if let configName = SourceEditorCommand.cfgOptions[selection]{
            return Bundle.main.path(forResource: configName, ofType: nil)!
        }
        else{
            // otherwise, use custom config path
            return SharedFileManager.customConfigPath()?.relativePath ?? ""
        }
    }
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void) {
        let errorPipe = Pipe()
        let outputPipe = Pipe()
        
        let task = Process()
        task.standardError = errorPipe
        task.standardInput = invocation.buffer.completeBuffer
        task.standardOutput = outputPipe
        task.launchPath = commandPath
        
        // configure uncrustify to format with specified cfg, format for Objective-C, and strip messages
        task.arguments = [ "-c=\(commandConfigPath)","-l=OC+","-q"]
        
        let inputPipe = Pipe()
        task.standardInput = inputPipe
        let stdinHandle = inputPipe.fileHandleForWriting
        
        // write text to stdin (where uncrustify reads from)
        if let data = invocation.buffer.completeBuffer.data(using: .utf8) {
            stdinHandle.write(data)
            stdinHandle.closeFile()
        }
        
        task.launch()
        task.waitUntilExit()
        
        errorPipe.fileHandleForReading.readDataToEndOfFile()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        if let outputString = String(data: outputData, encoding: .utf8) {
            
            invocation.buffer.lines.removeAllObjects()
            outputString.enumerateLines(invoking: { (s:String, _) in
                invocation.buffer.lines.add(s)
            })
            
        }
        
        // fixes crash if there is no selection when completion handler is called
        invocation.buffer.selections.add(XCSourceTextRange(start: XCSourceTextPosition(line: 0, column: 0), end: XCSourceTextPosition(line: 0, column: 0)))
        
        completionHandler(nil)
    }
}
