//
//  generate_form_midi.swift
//  Sound Generator
//
//  Created by Kasper Nielsen on 09/05/2024.
//

import Foundation
import AVFoundation

func transpositionRange(_ instrument: InstrumentSpec, _ events: [MidiEvent]) -> ClosedRange<Int> {
    var minNote: Int = 255
    var maxNote: Int = 0
    for event in events {
        if case let MidiEvent.NoteEvent(_, note) = event {
            minNote = min(Int(note.key), minNote)
            maxNote = max(Int(note.key), maxNote)
        }
    }
    let lowerBound = -(minNote - instrument.keyRange.lowerBound)
    let upperBound = instrument.keyRange.upperBound - maxNote
    return lowerBound ... upperBound
}

func generate_from_midi(midiFile: URL, instruments: [InstrumentSpec], outputDirectory: URL) throws {
    let renderer = try SampleRenderer()

    try renderer.loadFromMidiFile(midiFileURL: midiFile)
    let trackCount = renderer.getTrackCount()

    for instrument in instruments {
        let instrumentCopy = try createTemporaryCopyOfFile(originalFilePath: instrument.url)
        try renderer.useInstrument(instrumentPack: instrumentCopy, instrument.gainCorrection)

        for track in 0..<trackCount {
            print("Processing track \(track)")
            renderer.soloTrack(trackSelect: track)

            let originalEvents = try renderer.getStagedEvents(trackSelect: track)
            if originalEvents.isEmpty {
                print("Skipping track \(track) as it is empty")
                continue
            }

            let transpositions = transpositionRange(instrument, originalEvents)
            print("Doing transpositions \(transpositions) for track \(track)")

            renderer.transpose(trackSelect: track, amount: transpositions.lowerBound)
            for transposition in transpositions {
                print("Bouncinng transposition \(transposition) for track \(track)")
                renderer.pickRandomEffectPreset()
                renderer.transpose(trackSelect: track, amount: 1)

                let instrumentName = "\(instrument.category)_\(instrument.sampleName)"
                let fileName = "\(track)_\(instrumentName)_\(transposition)"
                let aacOutputFile = outputDirectory.appending(path: "\(fileName).aac")
                let csvOutputFile = outputDirectory.appending(path: "\(fileName).csv")

                let csvString = noteEventsToCsv(events: try renderer.getStagedEvents(trackSelect: track))
                try csvString.write(to: csvOutputFile, atomically: false, encoding: .utf8)
                try renderer.generateAac(outputUrl: aacOutputFile)
            }
            renderer.transpose(trackSelect: track, amount: -transpositions.count)
        }

        try FileManager.default.removeItem(at: instrumentCopy)
    }
}
