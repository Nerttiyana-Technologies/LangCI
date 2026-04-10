// FamilyMemberService.swift
// LangCI

import Foundation

protocol FamilyMemberService {
    func getAllMembers() async throws -> [FamilyMember]
    func getMember(id: Int) async throws -> FamilyMember?
    func saveMember(_ member: FamilyMember) async throws -> FamilyMember
    func deleteMember(id: Int) async throws
    func getMemberCount() async throws -> Int

    /// Returns the total number of approved recordings across all family members.
    func getTotalRecordingCount() async throws -> Int
}
