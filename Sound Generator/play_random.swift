//
//  play_random.swift
//  Sound Generator
//
//  Created by Kasper Nielsen on 09/05/2024.
//

import Foundation

func play_random(partitionNumber: String, samplesPerInstrument: Int, instruments: [InstrumentSpec], datasetDirectory: URL) throws {
    let totalSamples = instruments.count * samplesPerInstrument

    // print("Generating a total of \(totalSamples) samples for partition \(partitionNumber)")

    let renderer = try SampleRenderer()
    let maxDuration = 6.0
    renderer.setCutoff(maxDuration) // Do not generate more than 6 seconds of audio

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

            generator.generate(instrumentSpec: instrument, renderer: renderer, maxDuration: maxDuration)

            let instrumentName = "\(instrument.category)_\(instrument.sampleName)"
            let fileName = "\(instrumentName)_\(i)"

            let datasetPartition = datasetDirectory.appending(path: "\(instrumentName)_\(partitionNumber)")
            if !FileManager.default.fileExists(atPath: datasetPartition.path) {
                try FileManager.default.createDirectory(at: datasetPartition, withIntermediateDirectories: false)
            }
            let aacOutputFile = datasetPartition.appending(path: "\(fileName).aac")
            // let wavOutputFile = datasetPartition.appending(path: "\(fileName).wav")
            let csvOutputFile = datasetPartition.appending(path: "\(fileName).csv")
            let midiOutputFile = datasetPartition.appending(path: "\(fileName).mid")

            let csvString = noteEventsToCsv(events: try renderer.getStagedEvents())
            try csvString.write(to: csvOutputFile, atomically: false, encoding: .utf8)
            try renderer.generateAac(outputUrl: aacOutputFile)
            let skipDuration = try SampleRenderer.normalizeAudioFile(audioFileUrl: aacOutputFile)

            // try renderer.generateWav(outputUrl: wavOutputFile)
            try renderer.writeMidiFile(midiFileURL: midiOutputFile)

            count += 1
            let completionPercent = (Double(count) / Double(totalSamples)) * 100
            updateLine(with: "\(String(format: "%.3f", completionPercent))% complete")
        }

        try FileManager.default.removeItem(at: instrumentCopy)
    }

}
