#!/usr/bin/env swift
// speak.swift — speak stdin (or argv) text using a macOS voice, including Personal Voice.
// The `say` CLI cannot access Personal Voice; AVSpeechSynthesizer can, after authorization.
//
// Usage:
//   echo "text" | swift speak.swift                 # default: first Personal Voice, else Samantha
//   swift speak.swift --voice "Samantha" "text"
//   swift speak.swift --list                        # list reachable voices (incl. Personal)
//   swift speak.swift --rate 0.5 --voice personal   # `personal` = first Personal Voice
//
// Exit codes: 0 ok · 2 no text · 3 voice not found · 4 personal-voice not authorized

import AVFoundation
import Foundation

// ---- args ----
var args = Array(CommandLine.arguments.dropFirst())
var wantList = false
var voiceQuery: String? = nil
var rate: Float? = nil
var textParts: [String] = []

while !args.isEmpty {
    let a = args.removeFirst()
    switch a {
    case "--list": wantList = true
    case "--voice": voiceQuery = args.isEmpty ? nil : args.removeFirst()
    case "--rate": rate = args.isEmpty ? nil : Float(args.removeFirst())
    default: textParts.append(a)
    }
}

// ---- request Personal Voice authorization (required before personal voices appear) ----
func authorizePersonalVoices() {
    let sem = DispatchSemaphore(value: 0)
    AVSpeechSynthesizer.requestPersonalVoiceAuthorization { _ in sem.signal() }
    _ = sem.wait(timeout: .now() + 30)
}
authorizePersonalVoices()

let allVoices = AVSpeechSynthesisVoice.speechVoices()
let personalVoices = allVoices.filter { $0.voiceTraits.contains(.isPersonalVoice) }

if wantList {
    let auth = AVSpeechSynthesizer.personalVoiceAuthorizationStatus
    FileHandle.standardError.write("Personal Voice authorization: \(auth.rawValue) (3 == authorized)\n".data(using: .utf8)!)
    for v in allVoices {
        let tag = v.voiceTraits.contains(.isPersonalVoice) ? " [PERSONAL]" : ""
        print("\(v.name)\t\(v.language)\t\(v.identifier)\(tag)")
    }
    exit(0)
}

// ---- resolve voice ----
// `nil` / empty / "system" / "default" means: don't pin a voice — let
// AVSpeechSynthesizer use the OS default system voice. Portable across machines
// that don't have any particular named voice installed. Signalled by returning
// nil here AND voiceQuery being one of those sentinels (checked at the call site).
func isSystemDefault(_ query: String?) -> Bool {
    guard let q = query?.lowercased(), !q.isEmpty else { return true }
    return q == "system" || q == "default"
}

func resolveVoice(_ query: String?) -> AVSpeechSynthesisVoice? {
    guard let q = query, !q.isEmpty else { return nil }   // system default
    if q.lowercased() == "personal" { return personalVoices.first }
    // exact name → identifier → name-prefix (so "Ava" matches "Ava (Premium)",
    // preferring Premium over Enhanced over Default) → language code.
    if let v = allVoices.first(where: { $0.name.caseInsensitiveCompare(q) == .orderedSame }) { return v }
    if let v = allVoices.first(where: { $0.identifier == q }) { return v }
    let ql = q.lowercased()
    let prefixMatches = allVoices.filter { $0.name.lowercased().hasPrefix(ql) }
    func rank(_ v: AVSpeechSynthesisVoice) -> Int {
        if v.identifier.contains(".premium.") { return 0 }
        if v.identifier.contains(".enhanced.") { return 1 }
        return 2
    }
    if let v = prefixMatches.sorted(by: { rank($0) < rank($1) }).first { return v }
    return AVSpeechSynthesisVoice(language: q)
}

let voice = resolveVoice(voiceQuery)
if voice == nil && !isSystemDefault(voiceQuery) {
    if voiceQuery?.lowercased() == "personal" {
        FileHandle.standardError.write("No Personal Voice available/authorized.\n".data(using: .utf8)!)
        exit(4)
    }
    FileHandle.standardError.write("Voice not found: \(voiceQuery ?? "")\n".data(using: .utf8)!)
    exit(3)
}

// ---- text: argv remainder, else stdin ----
var text = textParts.joined(separator: " ")
if text.isEmpty {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    text = String(data: data, encoding: .utf8) ?? ""
}
text = text.trimmingCharacters(in: .whitespacesAndNewlines)
guard !text.isEmpty else {
    FileHandle.standardError.write("No text to speak.\n".data(using: .utf8)!)
    exit(2)
}

let voiceLabel = voice.map { "\($0.name) [\($0.language)]" } ?? "system default"
FileHandle.standardError.write("Speaking with: \(voiceLabel)\n".data(using: .utf8)!)

// ---- speak (synchronous via delegate) ----
let synth = AVSpeechSynthesizer()
final class Done: NSObject, AVSpeechSynthesizerDelegate {
    let sem = DispatchSemaphore(value: 0)
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { sem.signal() }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { sem.signal() }
}
let done = Done()
synth.delegate = done

let utt = AVSpeechUtterance(string: text)
if let v = voice { utt.voice = v }   // unset => OS default system voice
if let r = rate { utt.rate = r }     // 0.0–1.0; default ~0.5

synth.speak(utt)
_ = done.sem.wait(timeout: .now() + 120)
exit(0)
