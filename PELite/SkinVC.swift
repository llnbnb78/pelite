import UIKit

struct Skin {
    let name: String
    let tint: UIColor
    let code: String
}

final class SkinVC: UITableViewController {
    private let skins: [Skin] = [
        Skin(name: "暗夜幽兰 · 动态", tint: UIColor(red: 0.36, green: 0.28, blue: 0.86, alpha: 1), code: "M416_SKIN_NIGHT"),
        Skin(name: "极光玫瑰 · 全息", tint: UIColor(red: 0.92, green: 0.26, blue: 0.52, alpha: 1), code: "AKM_SKIN_AURORA"),
        Skin(name: "深海鳞纹 · 曳光", tint: UIColor(red: 0.10, green: 0.55, blue: 0.72, alpha: 1), code: "SCAR_SKIN_ABYSS"),
        Skin(name: "熔岩核心 · 挥砍", tint: UIColor(red: 0.95, green: 0.45, blue: 0.12, alpha: 1), code: "MEL_LAVA"),
        Skin(name: "星轨白鸽 · 降落伞", tint: UIColor(red: 0.85, green: 0.88, blue: 0.95, alpha: 1), code: "PARA_STAR")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "美化包 · 皮肤库"
        tableView.separatorInset = .zero
        tableView.register(SkinCell.self, forCellReuseIdentifier: "c")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "已应用", style: .plain, target: self, action: #selector(applied))
    }

    override func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { skins.count }
    override func tableView(_ t: UITableView, cellForRowAt i: IndexPath) -> UITableViewCell {
        let c = t.dequeueReusableCell(withIdentifier: "c", for: i) as! SkinCell
        c.bind(skins[i.row])
        return c
    }
    override func tableView(_ t: UITableView, didSelectRowAt i: IndexPath) {
        t.deselectRow(at: i, animated: true)
        let s = skins[i.row]
        let d = UIAlertController(title: s.name, message: "应用该皮肤将同步更新壁纸与图标", preferredStyle: .alert)
        d.addAction(UIAlertAction(title: "取消", style: .cancel))
        d.addAction(UIAlertAction(title: "一键应用", style: .default) { _ in
            ApplyVC.present(from: self, skin: s)
        })
        present(d, animated: true)
    }

    @objc private func applied() {
        let a = UIAlertController(title: "已应用皮肤", message: "当前：\(UserDefaults.standard.string(forKey: "applied") ?? "默认皮肤")",
                                  preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "好", style: .default))
        present(a, animated: true)
    }
}

final class SkinCell: UITableViewCell {
    private let thumb = UIView()
    private let nameLabel = UILabel()
    private let sub = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        thumb.frame = CGRect(x: 16, y: 12, width: 64, height: 64)
        thumb.layer.cornerRadius = 12
        contentView.addSubview(thumb)
        nameLabel.frame = CGRect(x: 96, y: 20, width: 240, height: 22)
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        contentView.addSubview(nameLabel)
        sub.frame = CGRect(x: 96, y: 44, width: 260, height: 18)
        sub.font = .systemFont(ofSize: 12)
        sub.textColor = .secondaryLabel
        contentView.addSubview(sub)
    }
    required init?(coder: NSCoder) { fatalError() }

    func bind(_ s: Skin) {
        thumb.backgroundColor = s.tint
        nameLabel.text = s.name
        sub.text = "ID \(s.code) · 适配全机型"
    }
}
