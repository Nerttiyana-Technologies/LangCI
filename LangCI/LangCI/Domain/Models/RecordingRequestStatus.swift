//
//  RecordingRequestStatus.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

enum RecordingRequestStatus: Int, Codable {
    case pending = 0
    case completed = 1
    case expired = 2
    case cancelled = 3
}
