import UIKit

/// 分享扩展：从其他 App 分享链接，直接添加到 Alist 离线下载
class ShareViewController: UIViewController {

    // MARK: - UI
    private let urlLabel: UILabel = {
        let l = UILabel()
        l.numberOfLines = 3
        l.font = .systemFont(ofSize: 14, weight: .medium)
        l.textColor = .label
        l.text = "正在读取链接..."
        return l
    }()

    private let pathField: UITextField = {
        let f = UITextField()
        f.placeholder = "目标路径（默认 /）"
        f.text = "/"
        f.borderStyle = .roundedRect
        f.autocorrectionType = .no
        f.autocapitalizationType = .none
        f.spellCheckingType = .no
        f.returnKeyType = .done
        return f
    }()

    private let toolField: UITextField = {
        let f = UITextField()
        f.placeholder = "下载工具（默认 aria2）"
        f.text = "aria2"
        f.borderStyle = .roundedRect
        f.autocorrectionType = .no
        f.autocapitalizationType = .none
        f.spellCheckingType = .no
        return f
    }()

    private let statusLabel: UILabel = {
        let l = UILabel()
        l.numberOfLines = 0
        l.font = .systemFont(ofSize: 13)
        l.textColor = .secondaryLabel
        l.text = "登录主 App 后，即可把链接发送到 Alist 离线下载。"
        return l
    }()

    private lazy var addButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "添加离线下载"
        config.cornerStyle = .medium
        let b = UIButton(configuration: config)
        b.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        b.isEnabled = false
        return b
    }()

    private lazy var cancelButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "取消"
        let b = UIButton(configuration: config)
        b.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        return b
    }()

    // MARK: - 状态
    private var sharedURLString: String?
    private var isSubmitting = false

    // MARK: - App Group 共享配置
    private var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.s1mon09.alist")
    }

    private var baseURL: String {
        (appGroupDefaults?.string(forKey: "shared_server_url") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var token: String {
        appGroupDefaults?.string(forKey: "shared_token") ?? ""
    }

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        restoreSettings()
        extractSharedURL()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        let title = UILabel()
        title.text = "添加到 Alist 离线下载"
        title.font = .systemFont(ofSize: 17, weight: .semibold)

        let pathTitle = UILabel()
        pathTitle.text = "保存到目录"
        pathTitle.font = .systemFont(ofSize: 13)
        pathTitle.textColor = .secondaryLabel

        let toolTitle = UILabel()
        toolTitle.text = "下载工具"
        toolTitle.font = .systemFont(ofSize: 13)
        toolTitle.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [
            title, urlLabel,
            pathTitle, pathField,
            toolTitle, toolField,
            statusLabel, addButton, cancelButton
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(4, after: pathTitle)
        stack.setCustomSpacing(4, after: toolTitle)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])

        pathField.delegate = self
    }

    /// 恢复上次使用的路径与工具
    private func restoreSettings() {
        if let path = appGroupDefaults?.string(forKey: "shared_offline_path"), !path.isEmpty {
            pathField.text = path
        }
        if let tool = appGroupDefaults?.string(forKey: "shared_offline_tool"), !tool.isEmpty {
            toolField.text = tool
        }
    }

    // MARK: - 提取分享的链接
    private func extractSharedURL() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            showNoURL()
            return
        }
        let providers = items.flatMap { $0.attachments ?? [] }

        // 优先 public.url
        for provider in providers where provider.hasItemConformingToTypeIdentifier("public.url") {
            provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] item, _ in
                DispatchQueue.main.async {
                    if let url = item as? URL {
                        self?.handleURL(url.absoluteString)
                    } else if let str = item as? String, let url = URL(string: str) {
                        self?.handleURL(url.absoluteString)
                    } else {
                        self?.showNoURL()
                    }
                }
            }
            return
        }

        // 其次纯文本中提取 URL
        for provider in providers where provider.hasItemConformingToTypeIdentifier("public.plain-text") {
            provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] item, _ in
                DispatchQueue.main.async {
                    if let text = item as? String,
                       let range = text.range(of: #"https?://\S+"#, options: .regularExpression),
                       let url = URL(string: String(text[range])) {
                        self?.handleURL(url.absoluteString)
                    } else {
                        self?.showNoURL()
                    }
                }
            }
            return
        }
        showNoURL()
    }

    private func handleURL(_ urlString: String) {
        sharedURLString = urlString
        urlLabel.text = urlString
        urlLabel.textColor = .label

        if baseURL.isEmpty || token.isEmpty {
            statusLabel.text = "请先在主 App 中登录服务器后再使用分享扩展。"
            statusLabel.textColor = .systemOrange
        } else {
            addButton.isEnabled = true
        }
    }

    private func showNoURL() {
        urlLabel.text = "未识别到链接"
        urlLabel.textColor = .systemOrange
        statusLabel.text = "只支持分享网页链接（http/https）。"
    }

    // MARK: - 提交离线下载
    @objc private func addTapped() {
        guard !isSubmitting,
              let urlString = sharedURLString,
              !baseURL.isEmpty, !token.isEmpty else { return }
        isSubmitting = true
        addButton.isEnabled = false
        statusLabel.text = "正在提交..."
        statusLabel.textColor = .secondaryLabel

        var path = pathField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if path.isEmpty { path = "/" }
        var tool = toolField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "aria2"
        if tool.isEmpty { tool = "aria2" }

        // 记住本次设置
        appGroupDefaults?.set(path, forKey: "shared_offline_path")
        appGroupDefaults?.set(tool, forKey: "shared_offline_tool")

        submitOfflineDownload(url: urlString, path: path, tool: tool)
    }

    private func submitOfflineDownload(url urlString: String, path: String, tool: String) {
        guard let url = URL(string: "\(baseURL)/api/fs/add_offline_download") else {
            finish(with: "服务器地址无效", success: false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("Alist-iOS-Share", forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "urls": [urlString],
            "path": path,
            "tool": tool,
            "delete_files": false
        ])

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error = error {
                    self.finish(with: "提交失败: \(error.localizedDescription)", success: false)
                    return
                }
                if let data,
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let code = obj["code"] as? Int {
                    if code == 200 {
                        self.finish(with: "已添加到离线下载（\(path)）", success: true)
                    } else {
                        let msg = obj["message"] as? String ?? "未知错误"
                        self.finish(with: "失败（\(code)）: \(msg)", success: false)
                    }
                } else {
                    self.finish(with: "服务器响应异常", success: false)
                }
            }
        }.resume()
    }

    private func finish(with message: String, success: Bool) {
        statusLabel.text = message
        statusLabel.textColor = success ? .systemGreen : .systemRed
        addButton.isEnabled = false
        addButton.configuration?.title = success ? "完成" : "重试"
        addButton.isEnabled = !success
        if success {
            addButton.removeTarget(self, action: #selector(addTapped), for: .touchUpInside)
            addButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        } else {
            isSubmitting = false
        }
    }

    @objc private func doneTapped() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    @objc private func cancelTapped() {
        extensionContext?.cancelRequest(withError: NSError(domain: "AlistShare", code: NSUserCancelledError))
    }
}

// MARK: - UITextFieldDelegate
extension ShareViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
