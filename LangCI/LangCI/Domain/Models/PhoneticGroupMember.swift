//
//  PhoneticGroupMember.swift
//  LangCI
//
//  Created by Suresh Subramanian on 06/04/26.
//

import Foundation

struct PhoneticGroupMember: Codable {
    var phoneticGroupId: Int
    var phoneticGroup: PhoneticGroup?
    
    var wordEntryId: Int
    var wordEntry: WordEntry?
}
