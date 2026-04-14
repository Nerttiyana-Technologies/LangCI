// PatientListViewController.swift
// LangCI — Browse, search, edit, and delete patients
//
// This is the audiologist's patient roster. Also provides the
// right-to-erasure action (swipe-to-delete deletes the patient and
// disassociates their sessions; the "Delete all sessions" action
// fully erases their history from the device).

import UIKit

final class PatientListViewController: UIViewController {

    private let patientService = ServiceLocator.shared.patientService!
    private let sessionService = ServiceLocator.shared.soundDetectionService!

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let searchController = UISearchController(searchResultsController: nil)

    private var patients: [Patient] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Patients"
        view.backgroundColor = .lcBackground
        navigationItem.largeTitleDisplayMode = .always

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search by name or identifier"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        loadPatients()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadPatients()
    }

    private func loadPatients(query: String = "") {
        Task {
            if query.isEmpty {
                patients = (try? await patientService.getAllPatients()) ?? []
            } else {
                patients = (try? await patientService.searchPatients(query: query)) ?? []
            }
            await MainActor.run { self.tableView.reloadData() }
        }
    }
}

// MARK: - Search

extension PatientListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        loadPatients(query: searchController.searchBar.text ?? "")
    }
}

// MARK: - Table

extension PatientListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(patients.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        if patients.isEmpty {
            var config = cell.defaultContentConfiguration()
            config.text = "No patients yet"
            config.secondaryText = "Start an audiologist test to add one."
            config.textProperties.color = .secondaryLabel
            cell.contentConfiguration = config
            cell.selectionStyle = .none
            cell.accessoryType = .none
            return cell
        }

        let patient = patients[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = patient.name
        config.secondaryText = patient.identifier
        config.textProperties.font = UIFont.lcBodyBold()
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !patients.isEmpty, indexPath.row < patients.count else { return }
        lcHaptic(.light)
        let vc = PatientProgressViewController(patient: patients[indexPath.row])
        navigationController?.pushViewController(vc, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !patients.isEmpty, indexPath.row < patients.count else { return nil }
        let patient = patients[indexPath.row]

        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            self?.confirmFullErasure(patient: patient, completion: done)
        }
        delete.image = UIImage(systemName: "trash.fill")

        return UISwipeActionsConfiguration(actions: [delete])
    }

    private func confirmFullErasure(patient: Patient, completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: "Delete \(patient.name)?",
            message: "This permanently deletes the patient AND all their test sessions and trials from this device. This cannot be undone.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(false) })
        alert.addAction(UIAlertAction(title: "Delete Everything", style: .destructive) { [weak self] _ in
            guard let self = self else { completion(false); return }
            Task {
                // Delete all sessions + trials (cascade)
                try? await self.sessionService.deleteAllSessions(forPatient: patient.id)
                // Then delete the patient record itself
                try? await self.patientService.deletePatient(id: patient.id)
                await MainActor.run {
                    self.loadPatients(query: self.searchController.searchBar.text ?? "")
                    completion(true)
                }
            }
        })
        present(alert, animated: true)
    }
}
