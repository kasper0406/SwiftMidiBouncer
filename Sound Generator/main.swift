//
//  main.swift
//  Sound Generator
//
//  Created by Kasper Nielsen on 04/01/2024.
//

import Foundation

if CommandLine.arguments.count != 4 {
    print("This program must be used as ./sound_generator <dataset> <partition_number> <samples_per_instrument>")
    exit(1)
}
let dataset = CommandLine.arguments[1]
let partitionNumber = CommandLine.arguments[2]
let samplesPerInstrument = Int(CommandLine.arguments[3])!

// Create dataset directory
let datasetDirectory: URL = URL(fileURLWithPath: "/Volumes/git/ml/datasets/midi-to-sound/\(dataset)/")

let instruments = [
    InstrumentSpec(
        url: URL(fileURLWithPath: "/Volumes/git/ESX24/yamaha_grand.exs"),
        lowKey: 21,
        highKey: 108,
        category: "piano",
        sampleName: "yamaha_grand",
        gainCorrection: 6.0
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "/Volumes/git/ESX24/grand_piano.exs"),
        lowKey: 21,
        highKey: 108,
        category: "piano",
        sampleName: "grand_piano"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "/Volumes/git/ESX24/bosendorfer_grand.exs"),
        lowKey: 21,
        highKey: 108,
        category: "piano",
        sampleName: "bosendorfer_grand",
        gainCorrection: -14.0
    )
]
let totalSamples = instruments.count * samplesPerInstrument

// print("Generating a total of \(totalSamples) samples for partition \(partitionNumber)")

let renderer = try SampleRenderer()
let generator = EventGenerator()

func updateLine(with newText: String) {
    let clearLineSequence = "\r" + String(repeating: " ", count: 80) + "\r"
    print(clearLineSequence, terminator: "")
    print(newText, terminator: "")
    fflush(stdout) // Ensure the output is immediately displayed
}

// updateLine(with: "Generating samples...")
var count = 0
for instrument in instruments {
    let instrumentCopy = try createTemporaryCopyOfFile(originalFilePath: instrument.url)
    try renderer.useInstrument(instrumentPack: instrumentCopy, instrument.gainCorrection)

    for i in 0..<samplesPerInstrument {
        renderer.clearTracks()
        renderer.pickRandomEffectPreset()

        generator.generate(instrumentSpec: instrument, renderer: renderer)

        let instrumentName = "\(instrument.category)_\(instrument.sampleName)"
        let fileName = "\(instrumentName)_\(i)"

        let datasetPartition = datasetDirectory.appending(path: "\(instrumentName)_\(partitionNumber)")
        if !FileManager.default.fileExists(atPath: datasetPartition.path) {
            try FileManager.default.createDirectory(at: datasetPartition, withIntermediateDirectories: false)
        }
        let aacOutputFile = datasetPartition.appending(path: "\(fileName).aac")
        let csvOutputFile = datasetPartition.appending(path: "\(fileName).csv")

        let csvString = noteEventsToCsv(events: try renderer.getStagedEvents())
        try csvString.write(to: csvOutputFile, atomically: false, encoding: .utf8)
        try renderer.generateAac(outputUrl: aacOutputFile)

        count += 1
        let completionPercent = (Double(count) / Double(totalSamples)) * 100
        updateLine(with: "\(String(format: "%.3f", completionPercent))% complete")
    }

    try FileManager.default.removeItem(at: instrumentCopy)
}
