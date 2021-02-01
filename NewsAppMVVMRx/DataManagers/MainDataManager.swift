//
//  DataManager.swift
//  NewsAppMVVMRx
//
//  Created by Alexander Milgunov on 30.07.2020.
//  Copyright © 2020 Alexander Milgunov. All rights reserved.
//

import Foundation
import CoreData
import RxSwift

protocol DataManagerType {
    
    var fetchNewDataTrigger: PublishSubject<Int> { get }
    var dataObservable: PublishSubject<[NewsEntity]> { get }
    var errorsObservable: PublishSubject<Error> { get }
}

class MainDataManager: DataManagerType {
    
    private let networkManager: NetworkManagerType
    private let coreDataManager: CoreDataManager
    
    private(set) var fetchNewDataTrigger = PublishSubject<Int>()
    private(set) var dataObservable = PublishSubject<[NewsEntity]>()
    private(set) var errorsObservable = PublishSubject<Error>()
    
    private let disposeBag = DisposeBag()
    
    private func bindTrigger() {
        
        fetchNewDataTrigger
            .subscribe(onNext: { page in
                self.fetchNewData(page: page)
            })
            .disposed(by: disposeBag)
        
        coreDataManager.coreDataObservable
            .bind(to: dataObservable)
            .disposed(by: disposeBag)
        
        coreDataManager.errorsObservable
            .bind(to: errorsObservable)
            .disposed(by: disposeBag)
    }

    public func fetchNewData(page: Int) {
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
        networkManager.getNews(page: page)
            .observeOn(scheduler)
            .catchError({ error -> Observable<[News]> in
                if error.localizedDescription != "Response status code was unacceptable: 426." {
                    self.errorsObservable.onNext(error)
                }
                self.coreDataManager.syncData(dataNews: [News](), erase: false)
                return Observable.empty()
            })
            .subscribe(onNext: { data in
                self.coreDataManager.syncData(dataNews: data, erase: page == 1)
            })
            .disposed(by: self.disposeBag)
    }
    
     init(coreDataManager: CoreDataManager, networkManager: NetworkManagerType) {

        self.coreDataManager = coreDataManager
        self.networkManager = networkManager

        bindTrigger()
    }
}
