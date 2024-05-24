//
//  misc.swift
//  Sound Generator
//
//  Created by Kasper Nielsen on 11/01/2024.
//

import Foundation
import AVFoundation

struct InstrumentSpec {
    // File information
    var url: URL

    // Register information in Midi key numbering
    var keyRange: ClosedRange<Int>

    // The name of the instrument
    var category: String // Category, fx `piano, `viloa`, `violin`, etc.
    var sampleName: String // Fx `Yamaha7C`, 'c-and-p`, etc.

    var gainCorrection: Float?
}

func isBufferAllZeros(buffer: AVAudioPCMBuffer) -> Bool {
    if let bufferData = buffer.floatChannelData {
        for channel in 0..<Int(buffer.format.channelCount) {
            for sample in 0..<Int(buffer.frameLength) {
                let value = bufferData.advanced(by: channel).pointee.advanced(by: sample).pointee
                if value != 0 {
                    return false
                }
            }
        }
        return true
    }
    return true
}

func roundToDecimal(_ value: Double, places: Int) -> Double {
    let multiplier = pow(10.0, Double(places))
    return round(value * multiplier) / multiplier
}

func beatsToSeconds(_ beats: Double, _ tempo: Double) -> Double {
    return roundToDecimal(beats / (tempo / 60.0), places: 2)
}

func noteEventsToCsv(events: [MidiEvent]) -> String {
    var tempo = 120.0
    var firstEventTime: Double?

    var csv = ""
    for event in events {
        switch event {
        case .NoteEvent(_, let note):
            let velocityFraction = String(format: "%.2f", Double(note.velocity)/127.0)

            let timeInSeconds = beatsToSeconds(note.time, tempo)
            let durationInSeconds = beatsToSeconds(note.duration, tempo)

            // Kind of hacky...
            // We normalize the audio such that the first sound will be made by the first event
            // Adjust the csv accordingly
            if firstEventTime == nil {
                firstEventTime = timeInSeconds
            }

            let adjustedTime = timeInSeconds - firstEventTime!
            csv += "\(adjustedTime),\(durationInSeconds),\(note.key),\(velocityFraction)\n"
        case .MessageEvent(_, let message):
            switch message {
            case .Tempo(let newTempo):
                tempo = newTempo
                csv += "%tempo=\(newTempo)\n"
            case .TimeSignature(let newTimeSignature):
                csv += "%timeSignature=\(newTimeSignature.notesPerBar)/\(newTimeSignature.noteValue)\n"
            case .EffectSettings(let effectSettings):
                switch effectSettings {
                case .Compressor(let compressorSpec):
                    csv += "%compressor," + compressorSpec
                case .Eq(let eqSpec):
                    csv += "%eq," + eqSpec
                case .Reverb(let reverbSpec):
                    csv += "%reverb," + reverbSpec
                case .TimePitch(let timePitchSpec):
                    csv += "%timepitch," + timePitchSpec
                }
                csv += "\n"
            }
        }

    }
    return csv
}

func createTemporaryCopyOfFile(originalFilePath: URL) throws -> URL {
    let fileManager = FileManager.default

    // Get the temporary directory
    let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

    // Generate a unique file name (you can also use a more specific name or extension)
    var tempFileURL = tempDirectoryURL.appendingPathComponent(UUID().uuidString)
    tempFileURL = tempFileURL.appendingPathExtension(originalFilePath.pathExtension)

    // Copy the original file to the temporary file path
    try fileManager.copyItem(atPath: originalFilePath.path, toPath: tempFileURL.path)
    return tempFileURL
}
