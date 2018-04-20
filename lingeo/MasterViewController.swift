//
//  MasterViewController.swift
//  lingeo
//
//  Created by LD on 4/13/18.
//  Copyright © 2018 LD. All rights reserved.
//

import UIKit
import SQLite
import CoreData

class MasterViewController: UITableViewController {
    
    @IBOutlet var bookmarksItem:UIBarButtonItem!
    
    var detailViewController: DetailViewController!
    var db: Connection!
    let map: [String:String] = ["i": "ი","W": "ჭ","z": "ზ","h": "ჰ","y": "ყ","g": "გ","x": "ხ","C": "ჩ","f": "ფ","w": "წ","T": "თ","e": "ე","S": "შ","v": "ვ","d": "დ","R": "ღ","u": "უ","c": "ც","t": "ტ","b": "ბ","s": "ს","a": "ა","r": "რ","q": "ქ","p": "პ","o": "ო","n": "ნ","J": "ჟ","m": "მ","l": "ლ","Z": "ძ","k": "კ","G": "ჩ","j": "ჯ"]
    let searchController = UISearchController(searchResultsController: nil)
    var searchResult:[[String:String]] = []
    var searchQuery:String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
        
        do {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            db = try appDelegate.getDB()
        } catch {
            print(error)
        }        
        
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
        //        self.searchDB()
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
    
    private func searchDB() {
        DispatchQueue.global(qos: .utility).async {
            do {
                let query = "SELECT t1.id, t1.eng, t1.transcription, t2.geo, t4.name, t4.abbr FROM eng t1, geo t2, geo_eng t3, types t4 " +
                "WHERE t1.eng LIKE ? || \"%\" AND t3.eng_id=t1.id AND t2.id=t3.geo_id AND t4.id=t2.type " +
                "GROUP BY t1.id ORDER BY t1.id,t1.eng LIMIT 30"
                let currentSearch = self.searchQuery
                var rows = [[String:String]]()
                for rowJoined in try self.db.prepare(query, [currentSearch]) {
                    if(currentSearch != self.searchQuery) {
                        return
                    }
                    rows.append([
                        "id": String(rowJoined[0] as! Int64),
                        "eng": String(rowJoined[1] as! String),
                        "geo": self.convert(toKA: String(rowJoined[3] as! String))
                        ])
                }
                DispatchQueue.main.async {
                    self.searchResult = rows;
                    self.tableView.reloadData()
                    if(self.searchResult.count > 0) {
                        self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
                    }
                }
            } catch {
                print(error)
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        searchController.becomeFirstResponder()
        searchController.searchBar.becomeFirstResponder()
        super.viewDidAppear(animated)
    }
    
    // MARK: - Segues
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let controller = segue.destination as! DetailViewController
                let row = self.searchResult[indexPath.row]
                
                controller.detailItemID = row["id"]!                
            }
        }
    }
    
    // MARK: - Table View
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "showDetail", sender: nil)
        
        tableView.deselectRow(at: indexPath, animated: false)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResult.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        let row = searchResult[indexPath.row]
        
        cell.textLabel!.text = row["eng"]
        cell.detailTextLabel!.text = row["geo"]
        
        
        return cell
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
    
    func filterContentForSearchText(_ searchText: String) {
        searchQuery = searchText
        searchDB()
    }
    
    func searchBarIsEmpty() -> Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }
    
    func isFiltering() -> Bool {
        let searchBarScopeIsFiltering = searchController.searchBar.selectedScopeButtonIndex != 0
        return searchController.isActive && (!searchBarIsEmpty() || searchBarScopeIsFiltering)
    }
    
    
}

extension MasterViewController: UISearchBarDelegate {
    // MARK: - UISearchBar Delegate
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        filterContentForSearchText(searchBar.text!)
    }
    
}

extension MasterViewController: UISearchResultsUpdating {
    // MARK: - UISearchResultsUpdating Delegate
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchController.searchBar.text!)
    }
}

