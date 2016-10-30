//
//  QuranPagesDataSource.swift
//  Quran
//
//  Created by Mohamed Afifi on 4/22/16.
//  Copyright © 2016 Quran.com. All rights reserved.
//

import Foundation
import GenericDataSources

class QuranPagesDataSource: BasicDataSource<QuranPage, QuranPageCollectionViewCell> {

    let imageService: QuranImageService
    let ayahInfoRetriever: AyahInfoRetriever
    let bookmarkPersistence: BookmarksPersistence

    let numberFormatter = NumberFormatter()

    var highlightedAyat: Set<AyahNumber> = Set()

    weak var pageCellDelegate: QuranPageCollectionCellDelegate?

    init(reuseIdentifier: String, imageService: QuranImageService, ayahInfoRetriever: AyahInfoRetriever, bookmarkPersistence: BookmarksPersistence) {
        self.imageService = imageService
        self.ayahInfoRetriever = ayahInfoRetriever
        self.bookmarkPersistence = bookmarkPersistence
        super.init(reuseIdentifier: reuseIdentifier)

        NotificationCenter.default.addObserver(self,
                                                         selector: #selector(applicationBecomeActive),
                                                         name: NSNotification.Name.UIApplicationDidBecomeActive,
                                                         object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func ds_collectionView(_ collectionView: GeneralCollectionView,
                                    configure cell: QuranPageCollectionViewCell,
                                    with item: QuranPage,
                                    at indexPath: IndexPath) {

        let size = ds_collectionView(collectionView, sizeForItemAt: indexPath)

        cell.highlightingView.bookmarkPersistence = bookmarkPersistence
        cell.page = item
        cell.pageLabel.text = numberFormatter.format(NSNumber(value: item.pageNumber))
        cell.suraLabel.text = Quran.nameForSura(item.startAyah.sura)
        cell.juzLabel.text = String(format: NSLocalizedString("juz2_description", tableName: "Android", comment: ""), item.juzNumber)

        cell.mainImageView.image = nil
        cell.highlightAyat(highlightedAyat)
        cell.cellDelegate = self.pageCellDelegate

        imageService.getImageOfPage(item.pageNumber, forSize: size) { (image) in
            guard cell.page == item else { return }
            cell.mainImageView.image = image
        }

        ayahInfoRetriever.retrieveAyahsAtPage(item.pageNumber) { (data) in
            guard cell.page == item else { return }
            cell.setAyahInfo(data.value)
        }
        Queue.bookmarks.async(self.bookmarkPersistence.retrieve(inPage: item.pageNumber)) { _, ayahBookmarks in
            guard cell.page == item else { return }
            cell.highlightingView.highlights[.bookmark] = Set(ayahBookmarks.map { $0.ayah })
        }
    }

    func removeHighlighting() {
        highlightedAyat.removeAll(keepingCapacity: true)
        for cell in ds_reusableViewDelegate?.ds_visibleCells() as? [QuranPageCollectionViewCell] ?? [] {
            cell.highlightAyat(highlightedAyat)
        }
    }

    func highlightAyaht(_ ayat: Set<AyahNumber>) {
        highlightedAyat = ayat

        guard let ayah = ayat.first else {
            removeHighlighting()
            return
        }

        scrollToHighlightedAya(ayah, ayaht: ayat)
    }

    func applicationBecomeActive() {
        if let ayah = highlightedAyat.first {
            scrollToHighlightedAya(ayah, ayaht: highlightedAyat)
        }
    }

    fileprivate func scrollToHighlightedAya(_ ayah: AyahNumber, ayaht: Set<AyahNumber>) {
        Queue.background.async {
            let page = ayah.getStartPage()

            Queue.main.async {
                let index = IndexPath(item: page - 1, section: 0)
                // if the cell is there, highlight the ayah.
                if let cell = self.ds_reusableViewDelegate?.ds_cellForItem(at: index) as? QuranPageCollectionViewCell {
                    cell.highlightAyat(ayaht)
                } else {
                    // scroll to the cell
                    self.ds_reusableViewDelegate?.ds_scrollView.endEditing(false)
                    self.ds_reusableViewDelegate?.ds_scrollToItem(at: index, at: .centeredHorizontally, animated: true)
                }
            }
        }
    }
}
