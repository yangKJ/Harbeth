//
//  HomeViewController.swift
//  MetalQueen
//
//  Created by Condy on 2021/8/7.
//

import UIKit

class HomeViewController: UIViewController {

    static let identifier = "homeCellIdentifier"
    var viewModel: HomeViewModel = HomeViewModel()
    
    lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.delegate = self
        table.dataSource = self
        table.showsVerticalScrollIndicator = false
        table.showsHorizontalScrollIndicator = false
        table.cellLayoutMarginsFollowReadableWidth = false
        table.sectionHeaderHeight = UITableView.automaticDimension
        table.register(UITableViewCell.self, forCellReuseIdentifier: HomeViewController.identifier)
        table.backgroundColor = UIColor.gray.withAlphaComponent(0.1)
        table.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        table.contentInsetAdjustmentBehavior = .automatic
        return table
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupInit()
        setupUI()
    }
    
    func setupInit() {
        title = "Metal"
        view.backgroundColor = UIColor.background
    }
    
    func setupUI() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
}

// MARK: - UITableViewDataSource,UITableViewDelegate
extension HomeViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.datas.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.datas[section].count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel.section[section]
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let element = viewModel.datas[indexPath.section][indexPath.row]
        let cell = UITableViewCell(style: .value1, reuseIdentifier: HomeViewController.identifier)
        cell.selectionStyle = .none
        cell.textLabel?.text = "\(indexPath.row + 1). " + element.rawValue
        cell.textLabel?.font = UIFont.systemFont(ofSize: 14)
        cell.textLabel?.textColor = UIColor.defaultTint
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let type = viewModel.datas[indexPath.section][indexPath.row]
        let vc = FilterViewController()
        let tuple = type.setupFilterObject()
        vc.filter = tuple.filter
        vc.callback = tuple.callback
        if let maxmin = tuple.maxminValue {
            vc.slider.minimumValue = maxmin.min
            vc.slider.maximumValue = maxmin.max
            vc.slider.value = maxmin.current
        } else {
            vc.slider.isHidden = true
        }
        vc.originImage = type.image
        vc.title = type.rawValue
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension UIColor {
    static let background = UIColor(named: "background")
    static let background2 = UIColor(named: "background2")
    static let defaultTint = UIColor(named: "defaultTint")
}
