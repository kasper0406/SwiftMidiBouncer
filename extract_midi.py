import mido
import csv

midi_file = mido.MidiFile('midi.mid')
ticks_per_beat = midi_file.ticks_per_beat
tempo = None

# Iterate over all messages in the MIDI file
for i, track in enumerate(midi_file.tracks):
    name = None
    notes = []
    active_notes = {}
    current_time = 0

    for msg in track:
        if msg.type == "set_tempo":
            tempo = msg.tempo

        current_time += msg.time
        if msg.type == 'instrument_name':
            name = msg.name
        if msg.type == 'note_on':
            if msg.note in active_notes:
                raise f"The note {msg.note} is already active!"
            start_time = mido.tick2second(current_time, ticks_per_beat, tempo)
            active_notes[msg.note] = { 'velocity': msg.velocity, 'start_time': start_time }
        if msg.type == 'note_off':
            if msg.note not in active_notes:
                raise f"The note {msg.note} is not active!"
            attack = active_notes.pop(msg.note)
            start_time = attack['start_time']
            end_time = mido.tick2second(current_time, ticks_per_beat, tempo)
            duration = end_time - attack['start_time']
            note = msg.note
            velocity = float(attack['velocity']) / 128.0
            notes.append([ start_time, duration, note, velocity ])

    if len(notes) > 0:
        print(f"Writing file {name}.csv")
        with open(f"{name}.csv", "w") as file:
            writer = csv.writer(file)
            for event in notes:
                writer.writerow(event)
