import UIKit
import RealmSwift
import Alamofire        // 追加
import AlamofireImage   // 追加
import SafariServices


class ApiViewController: UIViewController, UITableViewDelegate, UITableViewDataSource,UISearchBarDelegate {
    // UITableViewDelegate, UITableViewDataSource追加
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchText: UISearchBar!
    @IBOutlet weak var statusLabel: UILabel!
    
    var isLoading = false
    var isLastLoaded = false
    
    let realm = try! Realm()    // 追加
    
    var shopArray: [ApiResponse.Result.Shop] = []   // 追加
    var apiKey: String = ""                         // 追加
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // ここから
        tableView.delegate = self
        tableView.dataSource = self
        searchText.delegate = self
        
        // APIキー読み込み
        let filePath = Bundle.main.path(forResource: "ApiKey", ofType:"plist" )
        let plist = NSDictionary(contentsOfFile: filePath!)!
        apiKey = plist["key"] as! String
        
        // shopArray読み込み
        updateShopArray()
        // ここまで追加
        
        // ここから
        // RefreshControlの設定
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
        // ここまで追加
    }
    
    // ここから
    @objc func refresh() {
        // shopArray再読み込み
        updateShopArray()
    }
    // ここまで追加
    
    
    func updateShopArray(appendLoad: Bool = false) {
        // 検索キーワードの決定
        let currentSearchText = searchText.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // 検索バーのテキストが空の場合は、元のコードに合わせて「ランチ」をデフォルトとして使用
        let keyword = currentSearchText.isEmpty ? "ランチ" : currentSearchText
        
        // 現在読み込み中なら読み込みを開始しない
        if isLoading {
            return
        }
        // 最後まで読み込んでいるなら、追加読み込みしない
        if appendLoad && isLastLoaded {
            return
        }
        // 読み込み開始位置を設定
        let startIndex: Int
        if appendLoad {
            startIndex = shopArray.count + 1
        } else {
            startIndex = 1
        }
        // 読み込み中状態開始
        isLoading = true
        // ここまで追加
        
        let parameters: [String: Any] = [
            "key": apiKey,
            "start": startIndex,    // 開始位置の指定を変更
            "count": 20,
            "keyword": keyword,
            "format": "json"
        ]
        print("APIリクエスト 開始位置: \(parameters["start"]!) 読み込み店舗数: \(parameters["count"]!)")    // 追加
        AF.request("https://webservice.recruit.co.jp/hotpepper/gourmet/v1/", method: .get, parameters: parameters).responseDecodable(of: ApiResponse.self) { response in
            // 読み込み中状態終了
            self.isLoading = false  // 追加
            // リフレッシュ表示動作停止
            if self.tableView.refreshControl!.isRefreshing {
                self.tableView.refreshControl!.endRefreshing()
            }
            switch response.result {
            case .success(let apiResponse):
                // ここから
                // print("受信データ: \(apiResponse)")
                print("受信店舗数: \(apiResponse.results.shop.count)")
                if appendLoad {
                    // 追加読み込みの場合は、現在のshopArrayに追加
                    self.shopArray += apiResponse.results.shop
                } else {
                    // 追加読み込みでない場合はそのまま代入し、isLastLoadedをリセット
                    self.shopArray = apiResponse.results.shop
                    self.isLastLoaded = false
                }
                // 読み込み数が0なら最後まで読み込まれたと判断
                if apiResponse.results.shop.count == 0 {
                    self.isLastLoaded = true
                }
                // ここまで変更
                self.statusLabel.text = ""
            case .failure(let error):
                print(error)
                self.shopArray = []
                self.isLastLoaded = true    // 追加
                self.statusLabel.text = "データの取得が失敗しました"
            }
            self.tableView.reloadData()
        }
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return shopArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ShopCell
        let shop = shopArray[indexPath.row]
        let url = URL(string: shop.logo_image)!
        cell.logoImageView.af.setImage(withURL: url)
        cell.shopNameLabel.text = shop.name
        
        // ここから
        let starImageName = shop.isFavorite ? "star.fill" : "star"
        let starImage = UIImage(systemName: starImageName)?.withRenderingMode(.alwaysOriginal)
        cell.favoriteButton.setImage(starImage, for: .normal)
        // ここまで追加

        
        return cell
    }
    // ここまで追加
    
    @IBAction func tapFavoriteButton(_ sender: UIButton) {
        // ここから
        let point = sender.convert(CGPoint.zero, to: tableView)
        let indexPath = tableView.indexPathForRow(at: point)!
        let shop = shopArray[indexPath.row]
        
        if shop.isFavorite {
            print("「\(shop.name)」をお気に入りから削除します")
            try! realm.write {
                let favoriteShop = realm.object(ofType: FavoriteShop.self, forPrimaryKey: shop.id)!
                realm.delete(favoriteShop)
            }
        } else {
            print("「\(shop.name)」をお気に入りに追加します")
            try! realm.write {
                let favoriteShop = FavoriteShop()
                favoriteShop.id = shop.id
                favoriteShop.name = shop.name
                favoriteShop.logoImageURL = shop.logo_image
                if shop.coupon_urls.sp == "" {
                    favoriteShop.couponURL = shop.coupon_urls.pc
                } else {
                    favoriteShop.couponURL = shop.coupon_urls.sp
                }
                realm.add(favoriteShop)
            }
        }
        tableView.reloadData()
        // ここまで追加
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let shop = shopArray[indexPath.row]
        let urlString: String
        if shop.coupon_urls.sp == "" {
            urlString = shop.coupon_urls.pc
        } else {
            urlString = shop.coupon_urls.sp
        }
        let url = URL(string: urlString)!
        let safariViewController = SFSafariViewController(url: url)
        safariViewController.modalPresentationStyle = .pageSheet
        present(safariViewController, animated: true)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // 現在の検索結果をクリア
        self.shopArray = []
        // テーブルビューをリロード
        self.tableView.reloadData()
        // 新しいキーワードで検索を実行
        updateShopArray()
    }
}
