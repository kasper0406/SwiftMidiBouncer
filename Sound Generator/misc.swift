//
//  misc.swift
//  Sound Generator
//
//  Created by Kasper Nielsen on 11/01/2024.
//

import Foundation
import AVFoundation

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

func noteEventsToCsv(notes: [Note]) -> String {
    var csv = ""
    for note in notes {
        let velocityFraction = String(format: "%.2f", Double(note.velocity)/127.0)
        csv += "\(note.time),\(note.duration),\(note.key),\(velocityFraction)\n"
    }
    return csv
}
