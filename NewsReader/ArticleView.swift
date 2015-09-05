//
//  ArticleView.swift
//  NewsReader
//
//  Created by Florent Bruneau on 04/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Cocoa
import Lib
import News

class UnscrollableScrollView : NSScrollView {
    override func scrollWheel(theEvent: NSEvent) {
        self.superview?.scrollWheel(theEvent)
    }
}

class ArticleViewItem : NSCollectionViewItem {
    private weak var articlePromise : Promise<NNTPPayload>?

    override dynamic var representedObject : AnyObject? {
        willSet {
            self.articlePromise?.cancel()
            self.articlePromise = nil
        }

        didSet {
            self.articlePromise = self.article?.load()
            self.articlePromise?.then {
                (_) in

                self.articlePromise = nil
                guard let _ = self.collectionView.indexPathForItem(self) else {
                    return
                }

                self.collectionView.reloadData()
                //self.collectionView.reloadItemsAtIndexPaths([indexPath])
                if !self.view.hidden {
                    self.article?.isRead = true
                }
            }
        }
    }
    var article : Article? {
        return self.representedObject as? Article
    }

    override func viewDidAppear() {
        if self.article?.body != nil {
            self.article?.isRead = true
        }
    }
}

class ArticleViewController : NSViewController {
    private var articleView : NSCollectionView {
        return self.view as! NSCollectionView
    }

    private var currentThread : Article? {
        return self.representedObject as? Article
    }

    override var representedObject : AnyObject? {
        didSet {
            self.articleView.reloadData()

            guard let thread = self.currentThread else {
                return
            }

            self.scrollArticleToVisible(thread)
        }
    }

    private func scrollArticleToVisible(article: Article) -> Bool {
        guard let indexPath = self.indexPathForArticle(article) else {
            return false
        }
        
        guard let rect = self.articleView.layoutAttributesForItemAtIndexPath(indexPath)?.frame else {
            return false
        }

        self.articleView.superview?.scrollRectToVisible(rect)
        return true
    }

    @IBAction func scrollFirstUnreadArticleToVisible(sender: AnyObject?) {
        guard let unread = self.currentThread?.threadFirstUnread else {
            return
        }

        self.scrollArticleToVisible(unread)
    }

    private func articleForIndexPath(indexPath: NSIndexPath) -> Article? {
        guard indexPath.section == 0 else {
            return nil
        }

        guard let thread = self.currentThread?.thread else {
            return nil
        }

        return thread[indexPath.item]
    }

    private func indexPathForArticle(article: Article) -> NSIndexPath? {
        guard let idx = self.currentThread?.thread.indexOf(article) else {
            return nil
        }

        return NSIndexPath(forItem: idx, inSection: 0)
    }
}

extension ArticleViewController : NSCollectionViewDataSource {
    func collectionView(collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let thread = self.currentThread?.thread else {
            return 0
        }

        return thread.count
    }

    func collectionView(collectionView: NSCollectionView, itemForRepresentedObjectAtIndexPath indexPath: NSIndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItemWithIdentifier("Article", forIndexPath: indexPath)

        item.representedObject = self.articleForIndexPath(indexPath)
        return item
    }
}

extension ArticleViewController : NSCollectionViewDelegateFlowLayout {
    func collectionView(collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> NSSize {
        let size = collectionView.superview!.superview!.frame.size

        guard let article = self.articleForIndexPath(indexPath) else {
            return NSSize(width: 0, height: 0)
        }

        let height = 140 + article.lines * 14

        if article.inReplyTo != nil || article.replies.count != 0 {
            return NSSize(width: size.width - 30, height: CGFloat(height))
        } else {
            return NSSize(width: size.width, height: max(size.height, CGFloat(height)))
        }
    }
}