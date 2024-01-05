//
//  main.swift
//  Sound Generator
//
//  Created by Kasper Nielsen on 04/01/2024.
//

import Foundation

import CoreAudio
import AudioToolbox
import AVFoundation

func isBufferAllZeros(buffer: AVAudioPCMBuffer) -> Bool {
    if let bufferData = buffer.floatChannelData {
        for channel in 0..<Int(buffer.format.channelCount) {
            for sample in 0..<Int(buffer.frameLength) {
                let value = bufferData.advanced(by: channel).pointee.advanced(by: sample).pointee;
                if value != 0 {
                    return false;
                }
            }
        }
        return true
    }
    return true
}

// Assuming you have a MIDI file URL
let midiFileURL: URL = URL(string: "/Users/knielsen/Desktop/test-midi.mid")!
// let pianoSounds: URL = URL(string: "/Library/Application Support/Logic/Sampler Instruments/01 Acoustic Pianos/Steinway Grand Piano 2.exs")!
// let pianoSounds: URL = URL(string: "/Users/knielsen/Downloads/YamahaC7/YamahaC7.exs")!
let pianoSounds: URL = URL(string: "/Volumes/git/ESX24/TestPianoSamples/TestPianoSamples.exs")!

// Create and configure the engine and the sequencer
let engine = AVAudioEngine()

// Enable manual rendering mode
// let format = engine.mainMixerNode.outputFormat(forBus: 0)
let sampleRate = 44100.0
// let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
let format = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: sampleRate, channels: 2, interleaved: false)!
let maxFrames: AVAudioFrameCount = 4096

// Attach and connect a sampler or other audio nodes
let sampler = AVAudioUnitSampler()
sampler.overallGain = 12

try! engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: maxFrames)

engine.attach(sampler)
engine.connect(sampler, to: engine.mainMixerNode, format: format)
engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)

// Load the MIDI file into the sequencer and set it to write events to the sampler
let sequencer = AVAudioSequencer(audioEngine: engine)
try! sequencer.load(from: midiFileURL)
var maxTrackLengthInSeconds = 0.0
sequencer.tracks.forEach { track in
    track.destinationAudioUnit = sampler
    maxTrackLengthInSeconds = max(maxTrackLengthInSeconds, track.lengthInSeconds)
}

// Start the engine
try! engine.start()
try! sequencer.start()

// Load the Piano instrument
try! sampler.loadInstrument(at: pianoSounds)

// Buffer to hold rendered audio
let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: engine.manualRenderingMaximumFrameCount)!

// Create an audio file to write to
// let outputFileURL: URL = URL(string: "/Users/knielsen/Desktop/test-sequenced.wav")!
let outputFileURL: URL = URL(string: "/Users/knielsen/Desktop/test-sequenced.aac")!
let wavSettings: [String: Any] = [
    AVFormatIDKey: kAudioFormatLinearPCM,
    AVLinearPCMBitDepthKey: 32,
    AVNumberOfChannelsKey: 2,
    AVSampleRateKey: sampleRate
]

let aacSettings: [String: Any] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: sampleRate,
    AVNumberOfChannelsKey: 2
]

do {
    // let outputFile = try AVAudioFile(forWriting: outputFileURL, settings: wavSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
    let outputFile = try AVAudioFile(forWriting: outputFileURL, settings: aacSettings, commonFormat: .pcmFormatFloat32, interleaved: false)

    // Render loop
    while sequencer.isPlaying && sequencer.currentPositionInSeconds < maxTrackLengthInSeconds {
        print("Sampling at position \(sequencer.currentPositionInSeconds)s")
        
        let framesToRender = min(buffer.frameCapacity, engine.manualRenderingMaximumFrameCount)
        let status = try! engine.renderOffline(framesToRender, to: buffer)
        
        switch status {
        case .success:
            // Write the rendered audio to the file
            try! outputFile.write(from: buffer)
        case .insufficientDataFromInputNode:
            // More data is needed to continue rendering
            break
        case .cannotDoInCurrentContext, .error:
            // An error occurred. Handle it here.
            throw NSError(domain: "AudioRenderError", code: 0, userInfo: nil)
        default:
            // Handle other cases
            break
        }
    }
} catch { print("Failed to generate audio file!") }

// Sequencer and engine can be stopped now
sequencer.stop()
engine.stop()
