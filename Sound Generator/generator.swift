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

protocol IntervalTransformation {
    func apply(intervals: [Int]) -> [Int]
}

enum TransformTo7thChord: CaseIterable, IntervalTransformation {
    case major7
    case minor7

    func apply(intervals: [Int]) -> [Int] {
        switch self {
        case .major7:
            return addInterval(interval: 11, intervals: intervals)
        case .minor7:
            return addInterval(interval: 10, intervals: intervals)
        }
    }
}

class IntervalDupOrDrop: IntervalTransformation {
    func apply(intervals: [Int]) -> [Int] {
        var transformed: [Int] = []
        for interval in intervals {
            while Double.random(in: 0..<1) < 0.2 {
                // Duplicate the interval
                transformed.append(interval)
            }
            // Drop the event with 20% probability
            if Double.random(in: 0..<1) < 0.8 {
                transformed.append(interval)
            }

        }
        return transformed
    }
}

class InvertionsTransformer: IntervalTransformation {
    func generateGaussianRandom(mean: Double, standardDeviation: Double) -> Double {
        let u1 = Double.random(in: 0..<1)
        let u2 = Double.random(in: 0..<1)

        let z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
        return z0 * standardDeviation + mean
    }

    func apply(intervals: [Int]) -> [Int] {
        // The interval is always relative to middle C.
        // On a piano we have ~4 octaves on either side to use
        // We pick an integer around 0 according to a normal distribution (favoring playing in the middle registers),
        // and then re-sample the intervals
        var newInterval: [Int] = []
        for interval in intervals {
            let shift = Int(round(generateGaussianRandom(mean: 0.0, standardDeviation: 1.0)))
            newInterval.append(shift * 12 + interval)
        }
        return newInterval
    }
}

func convertToInstrumentKeys(instrumentSpec: InstrumentSpec, intervals: [Int]) -> [Int] {
    var keys: [Int] = []

    let middleKey = (instrumentSpec.lowKey + instrumentSpec.highKey) / 2
    let startingKey = Int.random(in: 0..<12)

    for interval in intervals {
        let key = middleKey + startingKey + interval
        if key < instrumentSpec.lowKey {
            let offset = ceil((Double(instrumentSpec.lowKey) - Double(key)) / 12.0) * 12
            keys.append(key + Int(offset))
        } else if key > instrumentSpec.highKey {
            let offset = ceil((Double(key) - Double(instrumentSpec.highKey)) / 12.0) * 12
            keys.append(key - Int(offset))
        } else {
            keys.append(key)
        }
    }

    return keys
}

func makeIntervalsUnique(intervals: [Int]) -> [Int] {
    var unique: [Int] = []
    var seen: Set<Int> = Set()

    for interval in intervals {
        if !seen.contains(interval) {
            seen.insert(interval)
            unique.append(interval)
        }
    }

    return unique
}

class EventGenerator {

    let invertionsTransform = InvertionsTransformer()
    var transformations: [IntervalTransformation]

    init() {
        self.transformations = [IntervalDupOrDrop()] + TransformTo7thChord.allCases
    }

    func generate(instrumentSpec: InstrumentSpec, maxDuration: Double = 4.5) -> [Note] {
        var events: [Note] = []

        var time = 0.0
        while time < maxDuration && (events.isEmpty || Double.random(in: 0..<1) < 0.95) {
            let playType = PlayType.allCases.randomElement()!
            let chord = Chord.allCases.randomElement()!

            // The duration in seconds per key
            // TODO(knielsen): Make this be handled by every key in the chord
            let keyDuration = Double.random(in: 0.1..<2.0)

            // TODO(knielsen): Support transposing and other transformations on the intervals
            var intervals = chord.intervals()

            // Apply transformations at random until we either have 10 intervals to play or we throw a 20% dice
            let maxIntervalLength = 10
            while intervals.count < maxIntervalLength && Double.random(in: 0..<1) < 0.8 {
                let transform = transformations.randomElement()!
                intervals = transform.apply(intervals: intervals)
                intervals = Array(intervals.prefix(upTo: min(intervals.count, maxIntervalLength + 1)))
            }
            // Always apply the invertions transformer to use all of the available keys
            intervals = invertionsTransform.apply(intervals: intervals)
            if playType == PlayType.harmonic {
                intervals = makeIntervalsUnique(intervals: intervals)
            }

            let keys = convertToInstrumentKeys(instrumentSpec: instrumentSpec, intervals: intervals)
            for key in keys {
                if time >= maxDuration {
                    break
                }
                let velocity = UInt8.random(in: 10..<128)

                events.append(Note(time: time, duration: keyDuration, key: UInt8(key), velocity: velocity))
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
