//
//  FeedDetailViewController.swift
//  SimplyCasts
//
//  Created by felix on 9/8/16.
//  Copyright © 2016 Felix Chen. All rights reserved.
//

import UIKit
import CoreData

class FeedDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MiniPlayerToolbarDelegate {
    @IBOutlet weak var feedImageView: UIImageView!
    @IBOutlet weak var feedDescription: UITextView!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var miniPlayerToolbar: MiniPlayerToolbar!
    var subscribedFeedItemManager: SubscribedFeedItemManager?
    
    var fetchedResultsController: NSFetchedResultsController?
    
    var stack: CoreDataStack!
    
    var currentItemsCountInTableView: Int = 0
    
    weak var feed: Feed? {
        didSet {
            if let feed = feed {
                subscribedFeedItemManager = SubscribedFeedItemManager(feed: feed)
            }
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentItemsCountInTableView
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let feed = feed {
            let storyboard = UIStoryboard (name: "Main", bundle: nil)
            let resultVC = storyboard.instantiateViewControllerWithIdentifier("AudioPlayViewController") as! AudioPlayViewController

            FeedItemAudioPlayer.sharedAudioPlayer.initDataAndStartToPlay(feed, startIndex: indexPath.row)
            
            self.navigationController?.pushViewController(resultVC, animated: true)
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("feedItemDetailTableCell", forIndexPath: indexPath)
    
        if let subscribedFeedItemManager = subscribedFeedItemManager {
            if let item = subscribedFeedItemManager.getObjectAtIndex(indexPath) as? FeedItem {
                cell.textLabel?.text = item.title
                
                cell.detailTextLabel?.attributedText = item.itemDescription?.utf8Data?.attributedString
            }
        }
        
        if indexPath.row == currentItemsCountInTableView - 1{
            Logger.log.debug("Load more data from core data. Data count before loading is \(self.currentItemsCountInTableView)")
            currentItemsCountInTableView += Constants.RowCountToLoadForTable
            tableView.reloadData()
        }
        
        cell.layer.cornerRadius = 4.0
        cell.layer.masksToBounds = true
        cell.layer.borderWidth = 2.0
        cell.layer.borderColor = tableView.backgroundColor?.CGColor
        return cell
    }
    
    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        
    }
    
    func miniPlayerToolbar(miniPlayerToolbar: MiniPlayerToolbar, tappedImageView: UIImageView) {
        let storyboard = UIStoryboard (name: "Main", bundle: nil)
        let resultVC = storyboard.instantiateViewControllerWithIdentifier("AudioPlayViewController") as! AudioPlayViewController
        
        self.navigationController?.pushViewController(resultVC, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        if let data = feed?.iTunesImage {
            feedImageView.image = UIImage(data: data)
        }
        
        if let itemDescription = feed?.feedDescription{
            if let attributedString = itemDescription.utf8Data?.attributedString {
                let newAttributedString = NSMutableAttributedString(attributedString: attributedString)
                
                let range = NSMakeRange(0, newAttributedString.length)
                
                newAttributedString.addAttribute(NSForegroundColorAttributeName, value: UIColor.blackColor(), range: range)
                newAttributedString.addAttribute(NSFontAttributeName, value: UIFont.systemFontOfSize(20), range: range)                
                feedDescription.attributedText = newAttributedString
            }
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if let subscribedFeedItemManager = subscribedFeedItemManager {
            subscribedFeedItemManager.executeSearch()
            
            if subscribedFeedItemManager.fetchedObjectsCount() <= Constants.RowCountToLoadForTable {
                currentItemsCountInTableView = subscribedFeedItemManager.fetchedObjectsCount()
            } else {
                currentItemsCountInTableView = Constants.RowCountToLoadForTable
            }
            
            tableView.reloadData()
        } else {
            currentItemsCountInTableView = 0
        }
        miniPlayerToolbar.setupMiniPlayer()
        miniPlayerToolbar.delegate = self
    }
}
