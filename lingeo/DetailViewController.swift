//
//  DetailViewController.swift
//  lingeo
//
//  Created by LD on 4/13/18.
//  Copyright © 2018 LD. All rights reserved.
//

import UIKit
import GRDB
import CoreData

class DetailsTableViewCell: UITableViewCell {
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var type: UILabel!
    @IBOutlet weak var geo: UILabel!
    @IBOutlet weak var speak: UIButton!
}

class DetailViewController: UITableViewController, PTeSpeakDelegate {
    @IBOutlet weak var detailDescriptionLabel: UILabel!
    
    var managedObjectContext: NSManagedObjectContext? = nil
    var db: DatabasePool!
    var count:Int = 0
    var id:String! = ""
    var eng:String! = ""
    var trans:String! = ""
    var abbrs:[String]! = []
    var geos:[String]! = []
    var types:[String]! = []
    let map: [String:String] = ["i": "ი","W": "ჭ","z": "ზ","h": "ჰ","y": "ყ","g": "გ","x": "ხ","C": "ჩ","f": "ფ","w": "წ","T": "თ","e": "ე","S": "შ","v": "ვ","d": "დ","R": "ღ","u": "უ","c": "ც","t": "ტ","b": "ბ","s": "ს","a": "ა","r": "რ","q": "ქ","p": "პ","o": "ო","n": "ნ","J": "ჟ","m": "მ","l": "ლ","Z": "ძ","k": "კ","G": "ჩ","j": "ჯ"]
    var ptSpeak:PTeSpeak!
    var speakingButton:UIButton?
    
    func configureView() {
        if(detailItemID == nil) {
            return
        }
        count = 1
        do {
            let query = "SELECT t1.id, t1.eng, t1.transcription, t2.geo, t4.name, t4.abbr FROM eng t1, geo t2, geo_eng t3, types t4 " +
            "WHERE t1.id = ? AND t3.eng_id=t1.id AND t2.id=t3.geo_id AND t4.id=t2.type group by t2.id"
            
            try self.getDB()!.read { db in
                do {
                    let rows = try Row.fetchAll(db, query, arguments: [detailItemID], adapter: nil)
                    for rowJoined in rows {
                        id = String(rowJoined[0] as! Int64)
                        eng = String(rowJoined[1] as! String)
                        trans = String(rowJoined[2] == nil ? "" : rowJoined[2] as! String)
                        geos.append(convert(toKA: String(rowJoined[3] as! String)))
                        types.append(String(rowJoined[4] as! String))
                        abbrs.append(String(rowJoined[5] as! String))
                        
                        count = count + 1
                    }
                } catch {
                    print(error)
                }
                
            }
            
            self.navigationItem.backBarButtonItem?.title = "LinGEO"
            self.title = eng
        } catch {
            print(error)
        }
        
        ptSpeak = PTeSpeak.shared()
        ptSpeak.delegate = self
        ptSpeak.setup(withVoice: "ka", volume: 100, rate: 150, pitch: 40)
        
        self.managedObjectContext = CoreDataStack.managedObjectContext
        
        loadRightButton()
    }
    
    func loadRightButton() {
        if(someEntityExists(id: Int(id)!)) {
            let addButton = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(deleteBookmark(_:)))
            navigationItem.rightBarButtonItem = addButton
        } else {
            let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(saveBookmark(_:)))
            navigationItem.rightBarButtonItem = addButton
        }
    }
    
    func someEntityExists(id: Int) -> Bool {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Bookmarks")
        fetchRequest.includesSubentities = false
        fetchRequest.predicate = NSPredicate(format: "eng_id == %d", Int64(id))
        
        var entitiesCount = 0
        
        do {
            entitiesCount = try managedObjectContext!.fetch(fetchRequest).count
        }
        catch {
            print("error executing fetch request: \(error)")
        }
        
        return entitiesCount > 0
    }
    
    @objc
    func saveBookmark(_ sender: Any) {
        let context = self.fetchedResultsController.managedObjectContext
        var newBookmark:Bookmarks!
        
        if #available(iOS 10.0, *) {
            newBookmark = Bookmarks(context: context)
        } else {
            let entityDesc = NSEntityDescription.entity(forEntityName: "Bookmarks", in: CoreDataStack.managedObjectContext)
            newBookmark = Bookmarks(entity: entityDesc!, insertInto: CoreDataStack.managedObjectContext)
        }
        
        newBookmark.eng_id = Int64(id)!;
        newBookmark.eng = eng
        newBookmark.geo = geos.joined(separator: ",")
        newBookmark.date = Date()
        
        // Save the context.
        do {
            try context.save()
        } catch {
            print(error)
        }
        
        loadRightButton()
    }
    
    @objc
    func deleteBookmark(_ sender: Any) {
        let context = self.fetchedResultsController.managedObjectContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Bookmarks")
        fetchRequest.includesSubentities = false
        fetchRequest.predicate = NSPredicate(format: "eng_id == %d", Int64(id)!)
        
        // Save the context.
        do {
            if let result = try? context.fetch(fetchRequest) {
                for object in result {
                    context.delete(object as! Bookmarks)
                }
            }
            
            try context.save()
        } catch {
            print(error)
        }
        
        loadRightButton()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureView()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell:UITableViewCell
        if(indexPath.row == 0) {
            cell = tableView.dequeueReusableCell(withIdentifier: "title-row", for: indexPath)
            
            cell.textLabel!.text = eng
            cell.detailTextLabel!.text = trans
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "detail-row", for: indexPath)
            
            (cell as! DetailsTableViewCell).countLabel.text = String(indexPath.row).trimmingCharacters(in: .whitespacesAndNewlines) + "."
            (cell as! DetailsTableViewCell).type.text = types[indexPath.row].trimmingCharacters(in: .whitespacesAndNewlines)
            (cell as! DetailsTableViewCell).geo.text = geos[indexPath.row].trimmingCharacters(in: .whitespacesAndNewlines)
            (cell as! DetailsTableViewCell).speak.addTarget(self, action: #selector(speakGEO), for: UIControlEvents.touchUpInside)
            (cell as! DetailsTableViewCell).speak.setTitle(geos[indexPath.row], for: .normal)
            (cell as! DetailsTableViewCell).speak.setImage(UIImage.init(named: "Play"), for: .normal)
        }
        
        return cell
    }
    
    func speakDidStart(_ espeak: PTeSpeak!) {
        speakingButton?.setImage(UIImage.init(named: "Stop"), for: .normal)
        speakingButton?.addTarget(self, action: #selector(stopSpeak), for: UIControlEvents.touchUpInside)
    }
    
    func speakDidEnd(_ espeak: PTeSpeak!) {
        speakingButton?.setImage(UIImage.init(named: "Play"), for: .normal)
        speakingButton?.addTarget(self, action: #selector(speakGEO), for: UIControlEvents.touchUpInside)
    }
    
    func speakWithError(_ espeak: PTeSpeak!, error: OSStatus) {
        speakingButton?.setImage(UIImage.init(named: "Play"), for: .normal)
        speakingButton?.addTarget(self, action: #selector(speakGEO), for: UIControlEvents.touchUpInside)
    }
    
    @objc func speakGEO(sender: UIButton!) {
        speakingButton = sender
        ptSpeak.speak(convert(toKA: (sender.titleLabel?.text)!))
    }
    
    @objc func stopSpeak(sender: UIButton!) {
        if(ptSpeak.isSpeak()) {
            ptSpeak.stop()
        }
    }
    
    private func getDB() -> DatabasePool? {
        if(db != nil) {
            return db
        }
        
        do {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            db = try appDelegate.getDB()
            
            return db
        } catch {
            print(error)
        }
        
        
        return nil
    }
    
    var detailItemID: String? {
        didSet {
            // Update the view.
            configureView()
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
    
    var fetchedResultsController: NSFetchedResultsController<Bookmarks> {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        
        let fetchRequest: NSFetchRequest<Bookmarks> = Bookmarks.fetchRequest()
        
        // Set the batch size to a suitable number.
        fetchRequest.fetchBatchSize = 20
        
        // Edit the sort key as appropriate.
        let sortDescriptor = NSSortDescriptor(key: "eng_id", ascending: false)
        
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext!, sectionNameKeyPath: nil, cacheName: nil)
        _fetchedResultsController = aFetchedResultsController
        
        return _fetchedResultsController!
    }
    var _fetchedResultsController: NSFetchedResultsController<Bookmarks>? = nil
    
}

