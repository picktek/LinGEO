//
//  MasterViewController.swift
//  lingeo
//
//  Created by LD on 4/13/18.
//  Copyright © 2018 LD. All rights reserved.
//

import UIKit
import GRDB
import CoreData

class Word : Record {
    var id: Int64
    var eng: String
    var geo: String
    
    required init(row: Row) {
        id = row["id"]
        eng = row["eng"]
        geo = row["geo"]
        super.init(row: row)
    }
    
    override class var databaseTableName: String {
        return "eng"
    }
}


class MasterViewController: UITableViewController {
    
    @IBOutlet var bookmarksItem:UIBarButtonItem!
    
    var dbPool: DatabasePool!
    let map: [String:String] = ["i": "ი","W": "ჭ","z": "ზ","h": "ჰ","y": "ყ","g": "გ","x": "ხ","C": "ჩ","f": "ფ","w": "წ","T": "თ","e": "ე","S": "შ","v": "ვ","d": "დ","R": "ღ","u": "უ","c": "ც","t": "ტ","b": "ბ","s": "ს","a": "ა","r": "რ","q": "ქ","p": "პ","o": "ო","n": "ნ","J": "ჟ","m": "მ","l": "ლ","Z": "ძ","k": "კ","G": "ჩ","j": "ჯ"]
    let searchController = UISearchController(searchResultsController: nil)
    var searchResult:[[String:String]] = []
    var searchQuery:String = ""
    var fetchController:FetchedRecordsController<Word>!
    var searchSqlRaw:String = "SELECT t1.id, t1.eng, t1.transcription, t2.geo, t4.name, t4.abbr FROM eng t1, geo t2, geo_eng t3, types t4 " +
        "WHERE t1.eng LIKE ? || \"%\" AND t3.eng_id=t1.id AND t2.id=t3.geo_id AND t4.id=t2.type " +
    "GROUP BY t1.id ORDER BY t1.id,t1.eng"
    var searchSqlRawCount:String = "SELECT count(*) as total FROM eng"
    var searchSql:String = "SELECT t1.id, t1.eng, t1.transcription, t2.geo, t4.name, t4.abbr FROM eng t1, geo t2, geo_eng t3, types t4 " +
        "WHERE t1.eng LIKE ? || \"%\" AND t3.eng_id=t1.id AND t2.id=t3.geo_id AND t4.id=t2.type " +
    "GROUP BY t1.id ORDER BY t1.id,t1.eng LIMIT "
    var limit:Int = 20
    var dict:[String:[[String:String]]] = [:]
    var letters:[String] = []
    var exploreModeState = false
    var stopExploreMode = false
    var proggressView:UIProgressView!
    var alertView:UIAlertController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchSql = searchSqlRaw + " LIMIT ?"
        if(UIDevice.current.userInterfaceIdiom == .pad) {
            limit = 30
        }
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        dbPool = try! appDelegate.getDB()
        
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false        
        searchController.searchBar.placeholder = "Type Here…"
        searchController.searchBar.delegate = self
        
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = true
        } else {
            navigationItem.titleView = searchController.searchBar
        }
        definesPresentationContext = true
        
        fetchController = try! FetchedRecordsController<Word>(
            dbPool,
            sql: searchSql,
            arguments: [self.searchQuery, self.limit])
        
        fetchController.trackChanges(
            willChange: { [unowned self] _ in
                self.tableView.beginUpdates()
            },
            onChange: { [unowned self] (controller, record, change) in
                switch change {
                case .insertion(let indexPath):
                    self.tableView.insertRows(at: [indexPath], with: .none)
                    
                case .deletion(let indexPath):
                    self.tableView.deleteRows(at: [indexPath], with: .none)
                    
                case .update(let indexPath, _):
                    if let cell = self.tableView.cellForRow(at: indexPath) {
                        self.configure(cell, at: indexPath)
                    }
                    
                case .move(let indexPath, let newIndexPath, _):
                    // Actually move cells around for more demo effect :-)
                    let cell = self.tableView.cellForRow(at: indexPath)
                    self.tableView.deleteRows(at: [indexPath], with: .none)
                    self.tableView.insertRows(at: [newIndexPath], with: .none)
                    if let cell = cell {
                        self.configure(cell, at: newIndexPath)
                    }
                }
            },
            didChange: { [unowned self] _ in
                self.tableView.endUpdates()
        })
        
        try! self.fetchController.performFetch()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        
        if(bookmarksIsEmpty()) {
            navigationItem.rightBarButtonItem = nil
        } else {
            navigationItem.rightBarButtonItem = bookmarksItem
        }
        
        if(self.exploreModeState == false) {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Explore", style: .plain, target: self, action: #selector(exploreMode))
        }
    }
    
    @objc func exploreMode() {
        self.stopExploreMode = false
        DispatchQueue.main.async {
            self.alertView = UIAlertController(title: "Loading…", message: nil, preferredStyle: .alert)
            self.alertView.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                
                self.proggressView.removeFromSuperview()
                self.stopExploreMode = true
            }))
            let rect = CGRect(x: 10, y: 50, width: 250, height: 0)
            self.proggressView = UIProgressView(frame: rect)
            self.proggressView.progress = 0.0
            self.proggressView.tintColor = UIColor.blue
            self.proggressView.progress = Float(0)
            self.alertView.view.addSubview(self.proggressView)
            self.present(self.alertView, animated: true, completion: nil)
        }
        DispatchQueue.global(qos: .userInteractive).async {
            try! self.dbPool.read { db in
                let count = try! Row.fetchOne(db, self.searchSqlRawCount)
                let total = Float(exactly: count!["total"] as! Int64)!
                
                var wordIndex = Float(0.0)
                let words = try! Row.fetchCursor(db, self.searchSqlRaw, arguments: [""], adapter: nil)
                while let word = try words.next() {
                    if(self.stopExploreMode) {
                        self.letters.removeAll()
                        self.dict.removeAll()
                        break;
                    }
                    let letter = String((word["eng"] as String).first!)
                    if(self.dict[letter] == nil) {
                        self.dict[letter] = [[String:String]]()
                    }
                    self.dict[letter]!.append([
                        "id": String(word["id"] as Int64),
                        "eng": word["eng"] as String,
                        "geo": self.convert(toKA: word["geo"] as String)
                        ])
                    wordIndex = wordIndex + 1
                    DispatchQueue.main.async {
                        self.proggressView.setProgress(wordIndex / total, animated: true)
                    }
                }
                
                if(self.stopExploreMode == false) {
                    self.letters = Array(self.dict.keys)
                    self.letters = self.letters.sorted {a, b in
                        let aIsLower = a.lowercased() == a
                        let bIsLower = b.lowercased() == b
                        if(aIsLower && !bIsLower) {
                            return true
                        } else if(!aIsLower && bIsLower) {
                            return false
                        }
                        return a.caseInsensitiveCompare(b) == .orderedAscending
                    }
                    self.exploreModeState = true
                    DispatchQueue.main.async {
                        self.proggressView.removeFromSuperview()
                        self.alertView.dismiss(animated: true, completion: nil)
                        self.tableView.reloadData()
                        self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
                        self.navigationItem.leftBarButtonItem = nil
                    }
                }
            }
        }
    }
    
    private func bookmarksIsEmpty() -> Bool
    {
        let request:NSFetchRequest<Bookmarks> = Bookmarks.fetchRequest()
        let appDel:AppDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDel.persistentContainer.viewContext
        
        do {
            try context.execute(request)
            let count = try context.count(for: request)
            return count == 0
        } catch {
            print(error)
        }
        
        return true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.searchController.becomeFirstResponder()
        self.searchController.searchBar.becomeFirstResponder()
        super.viewDidAppear(animated)
    }
    
    // MARK: - Segues
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let controller = segue.destination as! DetailViewController
                
                if(exploreModeState) {
                    let row = searchResult.count > 0 ? searchResult[indexPath.row] : dict[letters[indexPath.section]]![indexPath.row]
                    controller.detailItemID = row["id"]
                } else {
                    let word = fetchController.record(at: indexPath)
                    controller.detailItemID = String(word.id)
                }
            }
        }
    }
    
    func convert(toKA str: String) -> String {
        var ret = String()
        
        for i in 0..<str.count {
            let index = str.index(str.startIndex, offsetBy: i)
            let chr = str[index]
            let tmp = map[String(chr)]
            
            if tmp != nil {
                ret.append(tmp!)
            } else {
                ret.append(chr)
            }
        }
        
        return ret
    }
    
    func lingeWordSearch(_ searchText: String) {
        searchQuery = searchText
        if(exploreModeState) {
            searchResult.removeAll()
            if(searchText.count == 0) {
                self.tableView.reloadData()
                return
            }
            
            let letter = String(searchText.first!)
            let section = dict[letter]!
            for row in section {
                let word = row["eng"]! as String
                if(word.starts(with: searchText)) {
                    searchResult.append(row)
                }
            }
            self.tableView.reloadData()
            self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
            
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                try! self.fetchController.setRequest(sql: self.searchSql, arguments: [self.searchQuery, self.limit], adapter: nil)
                DispatchQueue.main.async {
                    self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
                }
            }
        }
    }
    
    func searchBarIsEmpty() -> Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }
    
    func isFiltering() -> Bool {
        let searchBarScopeIsFiltering = searchController.searchBar.selectedScopeButtonIndex != 0
        return searchController.isActive && (!searchBarIsEmpty() || searchBarScopeIsFiltering)
    }
    
    
}

// MARK: - UITableViewDataSource

extension MasterViewController {
    func configure(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let word = fetchController.record(at: indexPath)
        cell.textLabel?.text = word.eng
        cell.detailTextLabel?.text = convert(toKA: word.geo)
    }
    
    func configureExplore(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let row = searchResult.count > 0 ? searchResult[indexPath.row] : dict[letters[indexPath.section]]![indexPath.row]
        cell.textLabel?.text = row["eng"]
        cell.detailTextLabel?.text = row["geo"]
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if(exploreModeState) {
            if(searchResult.count > 0) {
                return 1
            }
            return letters.count
        }
        return fetchController.sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(exploreModeState) {
            return searchResult.count > 0 ? searchResult.count : dict[letters[section]]!.count
        }
        return fetchController.sections[section].numberOfRecords
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        if(exploreModeState) {
            configureExplore(cell, at: indexPath)
        } else {
            configure(cell, at: indexPath)
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "showDetail", sender: nil)
        
        tableView.deselectRow(at: indexPath, animated: false)
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        if(exploreModeState == false || searchResult.count > 0) {
            return []
        }
        
        return letters
    }
    
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return letters.index(of: title)!
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if(exploreModeState == false || searchResult.count > 0) {
            return ""
        }
        return letters[section]
    }
}


extension MasterViewController: UISearchBarDelegate {
    // MARK: - UISearchBar Delegate
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        lingeWordSearch(searchBar.text!)
    }
    
}

extension MasterViewController: UISearchResultsUpdating {
    // MARK: - UISearchResultsUpdating Delegate
    func updateSearchResults(for searchController: UISearchController) {
        lingeWordSearch(searchController.searchBar.text!)
    }
}

