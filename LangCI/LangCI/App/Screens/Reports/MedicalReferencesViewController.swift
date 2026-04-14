// MedicalReferencesViewController.swift
// LangCI — Citations for medical / audiological content
//
// Required by App Store Review Guideline 1.4.1 (Safety — Physical Harm):
// any health or medical information an app presents must include clear
// citations to legitimate clinical sources.
//
// This screen lists every methodology used in LangCI's assessments and
// training modules, with tappable links to the original clinical sources.

import UIKit
import SafariServices

struct MedicalReference {
    let topic: String
    let description: String
    let sources: [ReferenceLink]
}

struct ReferenceLink {
    let title: String
    let url: URL
    let publisher: String
}

final class MedicalReferencesViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // MARK: - Data

    /// All medical references used across LangCI.
    /// Every clinical/health-related feature must have at least one citation here.
    static let references: [MedicalReference] = [

        MedicalReference(
            topic: "Ling 6 Sound Test",
            description: "The six sounds (/a/, /u/, /i/, /m/, /sh/, /s/) span the speech frequency range used by audiologists and speech-language pathologists to verify a cochlear implant user's detection across the audible spectrum.",
            sources: [
                ReferenceLink(
                    title: "Ling, D. (2002). Speech and the Hearing-Impaired Child",
                    url: URL(string: "https://www.agbell.org/")!,
                    publisher: "AG Bell Association"),
                ReferenceLink(
                    title: "The Ling 6 Sound Test — clinical overview",
                    url: URL(string: "https://www.cochlear.com/us/en/home/ongoing-care-and-support/rehabilitation-resources/rehabilitation-resources-for-adults/listening-practice/listening-check")!,
                    publisher: "Cochlear Americas"),
                ReferenceLink(
                    title: "Using the Ling 6 Sound Test at Home",
                    url: URL(string: "https://www.medel.com/en/blog/the-ling-six-sound-test")!,
                    publisher: "MED-EL"),
            ]),

        MedicalReference(
            topic: "Auditory-Verbal Therapy (AVT)",
            description: "Structured auditory training helps CI users re-learn to interpret sound. LangCI's training exercises follow AVT progression principles (detection → discrimination → identification → comprehension).",
            sources: [
                ReferenceLink(
                    title: "Estabrooks, W. (2020). Auditory-Verbal Therapy: Science, Research, and Practice",
                    url: URL(string: "https://www.pluralpublishing.com/publications/auditory-verbal-therapy-science-research-and-practice")!,
                    publisher: "Plural Publishing"),
                ReferenceLink(
                    title: "Principles of AVT",
                    url: URL(string: "https://agbell.org/families/listening-and-spoken-language-approach/principles-of-lsl-specialists/")!,
                    publisher: "AG Bell Academy for Listening and Spoken Language"),
            ]),

        MedicalReference(
            topic: "Sound Detection Testing (Trials Grid)",
            description: "The 9-trial-per-sound paradigm used in Audiologist Mode reflects standard clinical practice for aided threshold confirmation. Scoring is presented as raw accuracy percentages only — no diagnosis is inferred.",
            sources: [
                ReferenceLink(
                    title: "American Academy of Audiology — Clinical Practice Guidelines for Cochlear Implants",
                    url: URL(string: "https://www.audiology.org/practice-guidelines/")!,
                    publisher: "American Academy of Audiology"),
                ReferenceLink(
                    title: "ASHA Practice Portal — Cochlear Implants",
                    url: URL(string: "https://www.asha.org/practice-portal/professional-issues/cochlear-implants/")!,
                    publisher: "American Speech-Language-Hearing Association"),
            ]),

        MedicalReference(
            topic: "Music Perception Training",
            description: "CI users often struggle with pitch, melody, and timbre perception. Regular music training has been shown to improve perception over time.",
            sources: [
                ReferenceLink(
                    title: "Looi, V., Gfeller, K., & Driscoll, V. (2012). Music appreciation and training for cochlear implant recipients",
                    url: URL(string: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3600595/")!,
                    publisher: "Seminars in Hearing (NIH / PubMed Central)"),
                ReferenceLink(
                    title: "Music & Hearing — clinical information",
                    url: URL(string: "https://www.nidcd.nih.gov/health/cochlear-implants")!,
                    publisher: "NIDCD (National Institute on Deafness)"),
            ]),

        MedicalReference(
            topic: "Listening Fatigue Tracking",
            description: "Listening fatigue is a recognised effect in CI users due to the increased cognitive load of processing electrical stimulation. Self-reported fatigue logs help identify patterns.",
            sources: [
                ReferenceLink(
                    title: "Hornsby, B. W. Y., Naylor, G., & Bess, F. H. (2016). A Taxonomy of Fatigue Concepts and Their Relation to Hearing Loss",
                    url: URL(string: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4975968/")!,
                    publisher: "Ear & Hearing (NIH / PubMed Central)"),
            ]),

        MedicalReference(
            topic: "Minimal-Pair Discrimination",
            description: "Phoneme-level contrast training (e.g. /b/ vs /p/, /sh/ vs /s/) is a core auditory training task for CI users.",
            sources: [
                ReferenceLink(
                    title: "ASHA — Auditory Rehabilitation for Adults",
                    url: URL(string: "https://www.asha.org/practice-portal/professional-issues/aural-rehabilitation-for-adults/")!,
                    publisher: "American Speech-Language-Hearing Association"),
            ]),

        MedicalReference(
            topic: "Reading Aloud / Prosody Practice",
            description: "Reading aloud with feedback is a common auditory-verbal technique to reinforce self-monitoring of speech production and pitch variation.",
            sources: [
                ReferenceLink(
                    title: "Auditory Self-Monitoring in CI users — Perkell et al. (2007)",
                    url: URL(string: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2474792/")!,
                    publisher: "Journal of Speech, Language, and Hearing Research (NIH / PubMed Central)"),
            ]),
    ]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sources & References"
        view.backgroundColor = .lcBackground
        navigationItem.largeTitleDisplayMode = .always

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Ref")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // Footer disclaimer — required to clarify scope (not diagnostic)
        let footer = UILabel()
        footer.numberOfLines = 0
        footer.text = """
LangCI is an assistive training and practice tool for cochlear implant users. It is NOT a diagnostic medical device and does NOT replace clinical evaluation by a qualified audiologist, speech-language pathologist, or otolaryngologist. All scores, percentages, and trends shown in the app are descriptive only — they do not constitute a medical opinion, recommendation, or treatment plan.

Always consult your healthcare provider regarding changes to your hearing, device programming, or rehabilitation plan.
"""
        footer.font = UIFont.systemFont(ofSize: 12)
        footer.textColor = .secondaryLabel
        footer.translatesAutoresizingMaskIntoConstraints = false

        let footerContainer = UIView()
        footerContainer.addSubview(footer)
        NSLayoutConstraint.activate([
            footer.topAnchor.constraint(equalTo: footerContainer.topAnchor, constant: 16),
            footer.bottomAnchor.constraint(equalTo: footerContainer.bottomAnchor, constant: -24),
            footer.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor, constant: 20),
            footer.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor, constant: -20),
        ])
        footerContainer.frame.size.height = 180
        tableView.tableFooterView = footerContainer
    }

    private func openURL(_ url: URL) {
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = .lcTeal
        present(safari, animated: true)
    }
}

// MARK: - Table

extension MedicalReferencesViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        Self.references.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // 1 row for description + 1 row per source
        1 + Self.references[section].sources.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Self.references[section].topic
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Ref", for: indexPath)
        let ref = Self.references[indexPath.section]

        if indexPath.row == 0 {
            var config = cell.defaultContentConfiguration()
            config.text = ref.description
            config.textProperties.font = UIFont.lcBody()
            config.textProperties.numberOfLines = 0
            cell.contentConfiguration = config
            cell.selectionStyle = .none
            cell.accessoryType = .none
        } else {
            let link = ref.sources[indexPath.row - 1]
            var config = cell.defaultContentConfiguration()
            config.text = link.title
            config.secondaryText = link.publisher
            config.textProperties.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            config.textProperties.color = .lcTeal
            config.textProperties.numberOfLines = 0
            config.secondaryTextProperties.font = UIFont.systemFont(ofSize: 12)
            config.secondaryTextProperties.color = .secondaryLabel
            config.image = UIImage(systemName: "arrow.up.right.square")
            config.imageProperties.tintColor = .lcTeal
            cell.contentConfiguration = config
            cell.accessoryType = .disclosureIndicator
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row > 0 else { return }
        let ref = Self.references[indexPath.section]
        let link = ref.sources[indexPath.row - 1]
        openURL(link.url)
    }
}
