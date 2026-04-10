//
//  MusicTrainingType.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

enum MusicTrainingType: Int, Codable {
    case rhythm = 0     // tap along / identify beat patterns
    case instrument = 1 // identify which instrument is playing
    case melody = 2     // recognise familiar melodies
}
