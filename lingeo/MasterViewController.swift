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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
            sql: "SELECT t1.id, t1.eng, t1.transcription, t2.geo, t4.name, t4.abbr FROM eng t1, geo t2, geo_eng t3, types t4 " +
                "WHERE t1.eng LIKE ? || \"%\" AND t3.eng_id=t1.id AND t2.id=t3.geo_id AND t4.id=t2.type " +
            "GROUP BY t1.id ORDER BY t1.id,t1.eng LIMIT 15",
            arguments: [self.searchQuery])
        
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
                    //                    self.tableView.moveRow(at: indexPath, to: newIndexPath)
                    self.tableView.deleteRows(at: [indexPath], with: .none)
                    self.tableView.insertRows(at: [newIndexPath], with: .none)
                    if let cell = cell {
                        self.configure(cell, at: newIndexPath)
                    }
                    
                    // A quieter animation:
                    // self.tableView.deleteRows(at: [indexPath], with: .fade)
                    // self.tableView.insertRows(at: [newIndexPath], with: .fade)
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
        
    }
    
    private func bookmarksIsEmpty() -> Bool
    {
        
        let appDel:AppDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDel.persistentContainer.viewContext
        
        let request:NSFetchRequest<Bookmarks> = Bookmarks.fetchRequest()
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
                let word = fetchController.record(at: indexPath)
                controller.detailItemID = String(word.id)
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
        
        DispatchQueue.global(qos: .userInitiated).async {
            try! self.fetchController.setRequest(sql: "SELECT t1.id, t1.eng, t1.transcription, t2.geo, t4.name, t4.abbr FROM eng t1, geo t2, geo_eng t3, types t4 " +
                "WHERE t1.eng LIKE ? || \"%\" AND t3.eng_id=t1.id AND t2.id=t3.geo_id AND t4.id=t2.type " +
                "GROUP BY t1.id ORDER BY t1.id,t1.eng LIMIT 20",
                                                 arguments: [self.searchQuery], adapter: nil)
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
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchController.sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchController.sections[section].numberOfRecords
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        configure(cell, at: indexPath)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "showDetail", sender: nil)
        
        tableView.deselectRow(at: indexPath, animated: false)
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

