//
//  Ling6Attempt.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct Ling6Attempt: Identifiable, Codable {
    var id: Int
    var sessionId: Int
    var session: Ling6Session?

    /// One of: ah, ee, oo, sh, s, m
    var sound: String = ""

    /// Could the user hear that a sound was made?
    var isDetected: Bool

    /// Could the user correctly identify which sound it was?
    var isRecognised: Bool

    /// 0-5
    var sortOrder: Int

}
