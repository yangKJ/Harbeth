//
//  HomeViewController.swift
//  MetalQueen
//
//  Created by Condy on 2021/8/7.
//

import UIKit
import Harbeth

class HomeViewController: UIViewController {
    
    static let identifier = "homeCellIdentifier"
    
    lazy var viewModel: HomeViewModel = {
        switch view.restorationIdentifier {
        case "520":
            title = "Image"//"图像处理"
            return HomeViewModel.init(viewType: .image)
        case "521":
            title = "Camera"//"相机采集"
            return HomeViewModel.init(viewType: .camera)
        case "522":
            title = "Video"//"视频特效"
            return HomeViewModel.init(viewType: .player)
        default:
            return HomeViewModel.init(viewType: .image)
        }
    }()
    
    lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.delegate = self
        table.dataSource = self
        table.register(HomeTableViewCell.self, forCellReuseIdentifier: HomeViewController.identifier)
        table.backgroundColor = UIColor.systemBackground
        table.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        table.contentInsetAdjustmentBehavior = .automatic
        table.rowHeight = 70
        table.sectionHeaderHeight = 40
        table.sectionFooterHeight = 10
        table.showsVerticalScrollIndicator = false
        table.showsHorizontalScrollIndicator = false
        table.separatorStyle = .none
        return table
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupUI()
    }
    
    private func setupNavigationBar() {
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        let tabBarHeight = tabBarController?.tabBar.frame.size.height ?? 0
        NSLayoutConstraint.activate([
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -tabBarHeight),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tabBarController?.tabBar.isHidden = false
    }
    
    var datas: [(key: String, value: [ViewControllerType])] {
        get {
            self.viewModel.datas.sorted(by: { $0.0 > $1.0 })
        }
    }
}

// MARK: - Custom Table View Cell
class HomeTableViewCell: UITableViewCell {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let numberLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(red: 0.36, green: 0.28, blue: 0.98, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.05
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        addSubview(containerView)
        containerView.addSubview(numberLabel)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            
            numberLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            numberLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            numberLabel.widthAnchor.constraint(equalToConstant: 30),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: numberLabel.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: numberLabel.trailingAnchor, constant: 12),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
        ])
    }
    
    func configure(with title: String, subtitle: String, number: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        numberLabel.text = number
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        if selected {
            UIView.animate(withDuration: 0.2) {
                self.containerView.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
            } completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    self.containerView.transform = .identity
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource,UITableViewDelegate
extension HomeViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.datas.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return datas[section].value.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return datas[section].key
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            headerView.textLabel?.textColor = UIColor(red: 0.36, green: 0.28, blue: 0.98, alpha: 1.0)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let element = datas[indexPath.section].value[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: HomeViewController.identifier, for: indexPath) as! HomeTableViewCell
        cell.configure(with: "\(element)", subtitle: element.rawValue, number: "\(indexPath.row + 1).")
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let type = datas[indexPath.section].value[indexPath.row]
        let vc = viewModel.setupViewController(type)
        vc.title = type.rawValue
        tabBarController?.tabBar.isHidden = true
        navigationController?.pushViewController(vc, animated: true)
    }
}
