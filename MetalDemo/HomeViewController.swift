//
//  HomeViewController.swift
//  MetalQueen
//
//  Created by Condy on 2021/8/7.
//

import UIKit

class HomeViewController: UIViewController {
    
    static let identifier = "homeCellIdentifier"
    
    lazy var viewModel: HomeViewModel = {
        var identifier = view.restorationIdentifier
        if identifier == "520" {
            title = "Graphic"//"图像处理"
            return HomeViewModel.init(viewType: .image)
        } else if identifier == "521" {
            title = "Camera"//"相机采集"
            return HomeViewModel.init(viewType: .camera)
        } else {
            title = "Video"//"视频特效"
            return HomeViewModel.init(viewType: .player)
        }
    }()
    
    lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.delegate = self
        table.dataSource = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: HomeViewController.identifier)
        table.backgroundColor = UIColor.background?.withAlphaComponent(0.1)
        table.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        table.contentInsetAdjustmentBehavior = .never
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 50
        table.sectionHeaderHeight = 30
        table.sectionFooterHeight = 0.00001
        table.showsVerticalScrollIndicator = false
        table.showsHorizontalScrollIndicator = false
        table.cellLayoutMarginsFollowReadableWidth = false
        table.tableFooterView = UIView()
        table.keyboardDismissMode = UIScrollView.KeyboardDismissMode.onDrag
        return table
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        let tabBarHeight = tabBarController?.tabBar.frame.size.height ?? 0
        NSLayoutConstraint.activate([
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -tabBarHeight),
            tableView.topAnchor.constraint(equalTo: view.topAnchor, constant: 64),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = false
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
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.text = "\(indexPath.row + 1). " + "\(element)"
        cell.textLabel?.font = UIFont.systemFont(ofSize: 14)
        cell.textLabel?.textColor = UIColor.defaultTint
        cell.detailTextLabel?.textColor = UIColor.defaultTint?.withAlphaComponent(0.5)
        cell.detailTextLabel?.text = element.rawValue
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 13)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let type = viewModel.datas[indexPath.section][indexPath.row]
        let vc = viewModel.setupViewController(type)
        vc.title = type.rawValue
        tabBarController?.tabBar.isHidden = true
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension UIColor {
    static let background = UIColor(named: "background")
    static let background2 = UIColor(named: "background2")
    static let defaultTint = UIColor(named: "defaultTint")
}
