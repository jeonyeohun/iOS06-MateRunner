//
//  DefaultMateUseCase.swift
//  MateRunner
//
//  Created by 이유진 on 2021/11/09.
//

import Foundation

import RxSwift

final class DefaultMateUseCase: MateUseCase {
    private let repository: MateRepository
    private let disposeBag = DisposeBag()
    var mate: PublishSubject<[String: String]> = PublishSubject()
    
    init(repository: MateRepository) {
        self.repository = repository
    }
    
    func fetchMateInfo() {
        self.repository.fetchMateNickname()
            .subscribe(onNext: { [weak self] mate in
                self?.fetchMateImage(mate: mate)
            })
            .disposed(by: self.disposeBag)
    }
    
    func fetchMateImage(mate: [String]) {
        var mateList: [String: String] = [:]
        Observable.zip( mate.map { nickname in
            self.repository.fetchMateProfileImage(from: nickname)
                .map({ url in
                    mateList[nickname] = url
                })
        })
            .subscribe { [weak self] _ in
                self?.mate.onNext(mateList)
            }
            .disposed(by: self.disposeBag)
    }
}
