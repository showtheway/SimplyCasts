//
//  FeedParser.swift
//  SimplyCasts
//
//  Created by felix on 8/26/16.
//  Copyright © 2016 Felix Chen. All rights reserved.
//

import Foundation
import CoreData

import Fuzi
import SwiftyJSON


class FeedHelper {
    
    static func parserFeedInfoFromURL(urlString: String) -> FeedInfo? {
        guard let URL = NSURL(string: urlString) else {
            return nil
        }
        
        do {
            
            guard let data = NSData(contentsOfURL: URL) else {
                return nil
            }
            
            let document = try XMLDocument(data: data)
            
            var feedInfo = FeedInfo()
            
            feedInfo.feedURL = urlString
            
            /* get information about feed */
            
            // get title
            feedInfo.title = getTextFromElement(document.firstChild(xpath: RSSPath.RSSChannelTitle))
            
            // get owner name
            feedInfo.ownerName = getTextFromElement(document.firstChild(xpath: RSSPath.RSSiTunesOwnerName))
            
            // get category
            feedInfo.category = getTextFromElement(document.firstChild(xpath: RSSPath.RSSiTunesCategory))
            
            // get image url
            feedInfo.iTunesImageURL = getTextFromElement(document.firstChild(xpath: RSSPath.RSSiTunesImage))
            
            // get items in the feed
            let items = document.xpath(RSSPath.RSSChannelItem)
            
            // get pubDate
            let formatter = NSDateFormatter()
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
            if let pubDate = document.firstChild(xpath: RSSPath.RSSChannelPubDate) {
                if let dateString = getTextFromElement(pubDate) {
                    feedInfo.pubDate = formatter.dateFromString(dateString)
                }
            } else { // no pudDate, then try to get pubDate of the first item
                if items.count > 0 {
                    if let item = items[0] {
                        if let pubDateString = getTextFromElement(item.firstChild(xpath: RSSPath.RSSChannelItemPubDate)) {
                            feedInfo.pubDate = formatter.dateFromString(pubDateString)
                        }
                    }
                }
            }
            
            feedInfo.items = [FeedItemInfo]()
            for item in items {
                var feedItemInfo = FeedItemInfo()
                
                feedItemInfo.title = getTextFromElement(item.firstChild(xpath: RSSPath.RSSChannelItemTitle))
                feedItemInfo.itemDescription = getTextFromElement(item.firstChild(xpath: RSSPath.RSSChannelItemDescription))
                feedItemInfo.author = getTextFromElement(item.firstChild(xpath: RSSPath.RSSChannelItemAuthor))
                feedItemInfo.enclosureURL = getTextFromElement(item.firstChild(xpath: RSSPath.RSSChannelItemEnclosure))
                
                if let dateString = getTextFromElement(item.firstChild(xpath: RSSPath.RSSChannelItemPubDate)) {
                    feedItemInfo.pubDate = formatter.dateFromString(dateString)
                }
                
                feedInfo.items?.append(feedItemInfo)
            }
            
            return feedInfo
            
        } catch let error as XMLError {
            Logger.log.error(error)
            return nil
        } catch {
            Logger.log.error(error)
            return nil
        }

    }
    
    static func addFeed(context: NSManagedObjectContext, urlString: String, completionHandler: ((feed:Feed?, info: String, success: Bool) -> Void)? ) {
        
        guard let URL = NSURL(string: urlString) else {
            completionHandler?(feed: nil, info: "Could not convert the URL string to a NSURL.", success: false)
            return
        }
        
        do {
            
            guard let data = NSData(contentsOfURL: URL) else {
                completionHandler?(feed: nil, info: "Could not get the data from the URL.", success: false)
                return
            }
            
            let document = try XMLDocument(data: data)
            
            parserFeed(context, urlString: urlString, document: document, completionHandler: completionHandler)
            
        } catch let error as XMLError {
            Logger.log.error(error)
            if let completionHandler = completionHandler {
                completionHandler(feed: nil, info: "A XML error occured.", success: false)
            }
        } catch {
            Logger.log.error(error)
            completionHandler?(feed: nil, info: "A non-XML error occured.", success: false)
        }
    }
    
    static private func parserFeed(context: NSManagedObjectContext, urlString: String, document: XMLDocument, completionHandler: ((feed:Feed?, info: String, success: Bool) -> Void)? ) {
        
        let channels = document.xpath(RSSPath.RSSChannel)
        guard channels.count > 0 else {
            completionHandler?(feed: nil, info: "There is no channel in the feed.", success: false)
            return
        }
        
        let newFeed = Feed(context: context)
        
        /* get information about feed */
        
        newFeed.feedURL = urlString
        
        // get title
        newFeed.title = getTextFromElement(document.firstChild(xpath: RSSPath.RSSChannelTitle))
        
        // get title
        newFeed.author = getTextFromElement(document.firstChild(xpath: RSSPath.RSSChannelAuthor))
        
        // get link
        newFeed.link = getTextFromElement(document.firstChild(xpath: RSSPath.RSSChannelLink))
        
        // get language
        newFeed.language = getTextFromElement(document.firstChild(xpath: RSSPath.RSSChannelLanguage))

        // get description
        newFeed.feedDescription = getTextFromElement(document.firstChild(xpath: RSSPath.RSSChannelDescription))
        
        // get image url
        newFeed.iTunesImageURL = getAttributeValue(document.firstChild(xpath: RSSPath.RSSiTunesImage), attributeName: "href")
        
        // get owner info
        newFeed.iTunesOwnerName = getTextFromElement(document.firstChild(xpath: RSSPath.RSSiTunesOwnerName))
        newFeed.iTunesOwnerEmail = getTextFromElement(document.firstChild(xpath: RSSPath.RSSiTunesOwnerEmail))
        
        // get category
        newFeed.category = getTextFromElement(document.firstChild(xpath: RSSPath.RSSChannelCategory))
        
        // get pubDate
        let formatter = NSDateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        
        if let pubDate = document.firstChild(xpath: RSSPath.RSSChannelPubDate) {
            if let dateString = getTextFromElement(pubDate) {
                newFeed.publishDate = formatter.dateFromString(dateString)
            }
        }
        
        // get items in the feed
        let items = document.xpath(RSSPath.RSSChannelItem)
        for item in items {
            let feedItem = FeedItem(context: context)
            
            feedItem.title = getTextFromElement(item.firstChild(xpath: RSSPath.RSSChannelItemTitle))
            feedItem.itemDescription = getTextFromElement(item.firstChild(xpath: RSSPath.RSSChannelItemDescription))
            feedItem.guid = getTextFromElement(item.firstChild(xpath: RSSPath.RSSChannelItemGUID))
            feedItem.link = getTextFromElement(item.firstChild(xpath: RSSPath.RSSChannelItemLink))
            feedItem.author = getTextFromElement(item.firstChild(xpath: RSSPath.RSSChannelItemAuthor))
            if feedItem.author == nil{
                feedItem.author = getTextFromElement(item.firstChild(xpath: RSSPath.RSSChannelItemItunesAuthor))
            }
            let duration = getTextFromElement(item.firstChild(xpath: RSSPath.RSSChannelItemDuration))
            if let duration = duration {
                if duration.lowercaseString.rangeOfString(":") != nil {
                    feedItem.duration = parseDuration(duration)
                } else {
                    feedItem.duration = Int(duration)
                }
            }
            
            feedItem.enclosureURL = getAttributeValue(item.firstChild(xpath: RSSPath.RSSChannelItemEnclosure), attributeName: "url")
            
            if let dateString = getTextFromElement(item.firstChild(xpath: RSSPath.RSSChannelItemPubDate)) {
                feedItem.pubDate = formatter.dateFromString(dateString)
            }
            
            feedItem.feed = newFeed
            newFeed.addFeedItem(feedItem)
        }
        
        completionHandler?(feed: newFeed, info: "Feed is parsered.", success: true)
    }
    
    static private func getTextFromElement(element: XMLElement?) -> String?{
        if let nodes = element?.childNodes(ofTypes: [.Text, .CDataSection]) {
            // only get the first node
            if nodes.count > 0 {
                let node = nodes[0]
                return node.stringValue
            }
        }
        return nil
    }
    
    static private func getAttributeValue(element: XMLElement?, attributeName: String) -> String? {
        return element?[attributeName]
    }
    
    static func refreshFeed(feed: Feed, context: NSManagedObjectContext) {
        if let feedURL = feed.feedURL {
            let feedInfo = parserFeedInfoFromURL(feedURL)
            var newPubDate = feedInfo?.pubDate
            if newPubDate == nil {
                newPubDate = feedInfo?.items?.first?.pubDate
            }
            guard newPubDate != nil else {
                Logger.log.error("refreshFeed: there is no publish date in the feed geting from url.")
                return
            }
            
            var oldPubDate = feed.publishDate
            if oldPubDate == nil {
                oldPubDate = (feed.items?.firstObject as? FeedItem)?.pubDate
            }
            
            guard oldPubDate != nil else {
                Logger.log.error("refreshFeed: there is no publish date in the exisiting feed.")
                return
            }
            
            // need to be refreshed
            if oldPubDate!.compare(newPubDate!) == .OrderedAscending {
                feedInfo?.items
            }
            
            var index = 1
            while oldPubDate!.compare(newPubDate!) == .OrderedAscending {
                let feedItem = FeedItem(context: context)
                
                feedItem
                feedInfo?.items?[index]
                
                index += 1
                if index == (feedInfo?.items?.count)! {
                    break
                }
                newPubDate = feedInfo?.items?[index].pubDate
                if newPubDate == nil {
                    break
                }
            }
            
            
        }
    }
    
    static func needUpdateFeed(feed: Feed) -> Bool{
        if let link = feed.link {
            if let feedInfo = parserFeedInfoFromURL(link) {
                if let pubDate = feedInfo.pubDate {
                    if feed.publishDate?.compare(pubDate) == .OrderedAscending {
                        Logger.log.debug("Old publish date is \(feed.publishDate), new publish date is \(feedInfo.pubDate).")
                        return true
                    }
                }
            }
        }
        return false
    }
    
    static func searchFeed(term:String, completionHandler: ((info: String, results: [FeedInfo]?, success: Bool) -> Void)?) {
        var parameters = [String:AnyObject!] ()
        parameters["entity"] = "podcast"
        parameters["limit"] = 20
        parameters["term"] = term
        
        var feeds = [FeedInfo]()
        
        HTTPHelper.HTTPRequest(Constants.ApiSecureScheme,
                               host: Constants.ApiHost,
                               path: Constants.ApiPath,
                               parameters: parameters ) { (data, statusCode, error) in
                                
                                guard error == nil else {
                                    completionHandler?(info: "There was an error with your request.", results: nil, success: false)
                                    return
                                }
                                
                                guard statusCode == 200 else {
                                    completionHandler?(info: "Your request returned a status code other than 2xx!", results: nil, success: false)
                                    return
                                }
                                
                                if let data = data {
                                    let json = JSON(data: data)
                                    
                                    if let feedresults:Array<JSON> = json["results"].arrayValue {
                                        for feed in feedresults {
                                            var feedinfo = FeedInfo()
                                            feedinfo.feedURL = feed["feedUrl"].stringValue
                                            feedinfo.iTunesImageURL = feed["artworkUrl60"].stringValue
                                            feedinfo.title = feed["collectionName"].stringValue
                                            feedinfo.ownerName = feed["artistName"].stringValue
                                            
                                            feeds.append(feedinfo)
                                        }
                                    }
                                }
                                
                                completionHandler?(info: "Get search results!", results: feeds, success: true)
        }
    }
    
    
    static private func parseDuration(timeString:String) -> NSTimeInterval {
        guard !timeString.isEmpty else {
            return 0
        }
        
        var interval:Double = 0
        
        let parts = timeString.componentsSeparatedByString(":")
        for (index, part) in parts.reverse().enumerate() {
            interval += (Double(part) ?? 0) * pow(Double(60), Double(index))
        }
        
        return interval
    }
    
}