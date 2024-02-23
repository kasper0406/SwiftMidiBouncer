//
//  main.swift
//  Sound Generator
//
//  Created by Kasper Nielsen on 04/01/2024.
//

import Foundation

// Create dataset directory
let datasetDirectory: URL = URL(fileURLWithPath: "/Volumes/git/ml/datasets/midi-to-sound/v1")

let instruments = [
    InstrumentSpec(
        url: URL(fileURLWithPath: "/Volumes/git/ESX24/piano_YamahaC7/YamahaC7.exs"),
        lowKey: 21,
        highKey: 108,
        category: "piano",
        sampleName: "YamahaC7"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "/Volumes/git/ESX24/piano_BechsteinFelt/piano_BechsteinFelt.exs"),
        lowKey: 21,
        highKey: 108,
        category: "piano",
        sampleName: "BechsteinFelt"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "/Volumes/git/ESX24/violin_candp/violin_candp.exs"),
        lowKey: 55,
        highKey: 105,
        category: "violin",
        sampleName: "candp"
    )
]

let operationQueue = OperationQueue()
operationQueue.maxConcurrentOperationCount = 2

func createTemporaryCopyOfFile(originalFilePath: URL) throws -> URL {
    let fileManager = FileManager.default

    // Get the temporary directory
    let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

    // Generate a unique file name (you can also use a more specific name or extension)
    let tempFileURL = tempDirectoryURL.appendingPathComponent(UUID().uuidString)

    // Copy the original file to the temporary file path
    try fileManager.copyItem(atPath: originalFilePath.path, toPath: tempFileURL.path)
    return tempFileURL
}

var numTasks: Int64 = 0
for instrument in instruments {
    for i in 0..<10000 {
        let task = BlockOperation {
            do {
                let instrumentCopy = try createTemporaryCopyOfFile(originalFilePath: instrument.url)

                let renderer = try SampleRenderer()
                try renderer.useInstrument(instrumentPack: instrumentCopy)
                renderer.clearTracks()

                let generator = EventGenerator()

                for midiEvent in generator.generate(instrumentSpec: instrument) {
                    renderer.stage(note: midiEvent)
                }

                let fileName = "\(instrument.category)_\(instrument.sampleName)_\(i)"
                let aacOutputFile = datasetDirectory.appending(path: "\(fileName).aac")
                let csvOutputFile = datasetDirectory.appending(path: "\(fileName).csv")

                let csvString = noteEventsToCsv(notes: try renderer.getStagedEvents())
                try csvString.write(to: csvOutputFile, atomically: false, encoding: .utf8)
                try renderer.generateAac(outputUrl: aacOutputFile)

                try FileManager.default.removeItem(at: instrumentCopy)
            } catch let error {
                print("Failed to generate audio: \(error)")
            }
        }
        operationQueue.addOperation(task)
        numTasks += 1
    }
}
operationQueue.progress.totalUnitCount = numTasks

while !operationQueue.progress.isFinished {
    let progress = operationQueue.progress
    print("Completed \(progress.completedUnitCount) of \(progress.totalUnitCount) tasks")
    sleep(1)
}

operationQueue.waitUntilAllOperationsAreFinished()
