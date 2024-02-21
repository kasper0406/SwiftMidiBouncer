//
//  generator.swift
//  Sound Generator
//
//  Created by Kasper Nielsen on 21/02/2024.
//

import Foundation

enum Chord: CaseIterable {
    case major
    case minor
    case diminished
    case augmented
    case random
    case single

    func intervals() -> [Int] {
        switch self {
        case .major:
            return [0, 4, 7, 12]
        case .minor:
            return [0, 3, 7, 12]
        case .diminished:
            return [0, 3, 6, 12]
        case .augmented:
            return [0, 4, 8, 12]
        case .random:
            // TODO(knielsen): Consider making this have a dynamic number of intervals
            return [Int.random(in: 0...12), Int.random(in: 0...12), Int.random(in: 0...12), Int.random(in: 0...12)]
        case .single:
            return [0]
        }
    }
}

enum PlayType: CaseIterable {
    case appegio
    case harmonic
    // case Tripolet
}

func addInterval(interval: Int, intervals: [Int]) -> [Int] {
    var newList: [Int] = intervals
    newList.append(interval)
    return newList.sorted()
}

enum MaybeTransformTo7thChord: CaseIterable {
    case no
    case major7
    case minor7

    func apply(intervals: [Int]) -> [Int] {
        switch self {
        case .no:
            return intervals
        case .major7:
            return addInterval(interval: 11, intervals: intervals)
        case .minor7:
            return addInterval(interval: 10, intervals: intervals)
        }
    }
}

class EventGenerator {

    func generate(instrumentSpec: InstrumentSpec, maxDuration: Double = 4.5) -> [Note] {
        var events: [Note] = []

        let middleKey = (instrumentSpec.lowKey + instrumentSpec.highKey) / 2

        var time = 0.0
        while time < maxDuration && (events.isEmpty || Double.random(in: 0..<1) < 0.95) {
            let playType = PlayType.allCases.randomElement()!
            let chord = Chord.allCases.randomElement()!
            let startingKey = Int.random(in: 0..<12)

            // The duration in seconds per key
            // TODO(knielsen): Make this be handled by every key in the chord
            let keyDuration = Double.random(in: 0.1..<1.0)

            // TODO(knielsen): Support transposing and other transformations on the intervals
            for interval in chord.intervals() {
                if time >= maxDuration {
                    break
                }

                let velocity = UInt8.random(in: 10..<128)
                let key = UInt8(middleKey + startingKey + interval)

                events.append(Note(time: time, duration: keyDuration, key: key, velocity: velocity))
                if playType == PlayType.appegio {
                    time += keyDuration
                }
            }
            if playType == PlayType.harmonic {
                time += keyDuration
            }

            let delay = Double.random(in: 0..<0.5)
            time += delay
        }

        return events
    }
}
