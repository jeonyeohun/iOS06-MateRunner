//
//  SingleRunningViewModel.swift
//  MateRunner
//
//  Created by 이유진 on 2021/11/05.
//

import Foundation

import RxRelay
import RxSwift

final class SingleRunningViewModel {
    weak var coordinator: RunningCoordinator?
    private let runningUseCase: RunningUseCase
    
    struct Input {
        let viewDidLoadEvent: Observable<Void>
        let finishButtonLongPressDidBeginEvent: Observable<Void>
        let finishButtonLongPressDidCancelEvent: Observable<Void>
        let finishButtonDidTapEvent: Observable<Void>
    }
    struct Output {
        var distance = BehaviorRelay<String>(value: "0.00")
        var progress = BehaviorRelay<Double>(value: 0)
        var calorie = PublishRelay<String>()
        var timeSpent = PublishRelay<String>()
        var cancelTimeLeft = PublishRelay<String>()
        var popUpShouldShow = PublishRelay<Bool>()
    }
    
    init(coordinator: RunningCoordinator, runningUseCase: RunningUseCase) {
        self.coordinator = coordinator
        self.runningUseCase = runningUseCase
    }
    
    func transform(from input: Input, disposeBag: DisposeBag) -> Output {
        self.configureInput(input, disposeBag: disposeBag)
        return createOutput(from: input, disposeBag: disposeBag)
    }
    
    private func configureInput(_ input: Input, disposeBag: DisposeBag) {
        input.viewDidLoadEvent
            .subscribe(onNext: { [weak self] in
                self?.runningUseCase.executePedometer()
                self?.runningUseCase.executeActivity()
                self?.runningUseCase.executeTimer()
            })
            .disposed(by: disposeBag)
        
        input.finishButtonLongPressDidBeginEvent
            .subscribe(onNext: { [weak self] in
                self?.runningUseCase.executeCancelTimer()
            })
            .disposed(by: disposeBag)
        
        input.finishButtonLongPressDidCancelEvent
            .subscribe(onNext: { [weak self] in
                self?.runningUseCase.invalidateCancelTimer()
            })
            .disposed(by: disposeBag)
        
        input.finishButtonDidTapEvent
            .subscribe(onNext: { [weak self] in
                self?.runningUseCase.executePopUpTimer()
            })
            .disposed(by: disposeBag)
    }
    
    private func createOutput(from input: Input, disposeBag: DisposeBag) -> Output {
        let output = Output()
        self.runningUseCase.cancelTimeLeft
            .map({ $0 >= 3 ? "종료" : "\($0)" })
            .bind(to: output.cancelTimeLeft)
            .disposed(by: disposeBag)
        
        self.runningUseCase.runningData
            .map { [weak self] data in
                self?.convertToTimeFormat(from: data.myElapsedTime) ?? ""
            }
            .bind(to: output.timeSpent)
            .disposed(by: disposeBag)
        
        self.runningUseCase.runningData
            .map { [weak self] data in
                guard let self = self else { return "오류"}
                return String(self.convertToKilometer(from: data.myElapsedDistance))
            }
            .bind(to: output.distance)
            .disposed(by: disposeBag)
        
        self.runningUseCase.runningData
            .map { String(Int($0.calorie)) }
            .bind(to: output.calorie)
            .disposed(by: disposeBag)
        
        self.runningUseCase.shouldShowPopUp
            .bind(to: output.popUpShouldShow)
            .disposed(by: disposeBag)
        
        self.runningUseCase.progress
            .bind(to: output.progress)
            .disposed(by: disposeBag)
        
        Observable.combineLatest(
            self.runningUseCase.isFinished,
            self.runningUseCase.isCanceled,
            resultSelector: { ($0, $1) })
            .filter({ $0 || $1 })
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (_, isCanceled) in
                self?.coordinator?.pushRunningResultViewController(
                    with: self?.runningUseCase.createRunningResult(isCanceled: isCanceled)
                )
            })
            .disposed(by: disposeBag)
        
        return output
    }
    
    private func convertToKilometer(from value: Double) -> Double {
        return round(value / 10) / 100
    }
    
    private func convertToTimeFormat(from seconds: Int) -> String {
        func padZeros(to text: String) -> String {
            if text.count < 2 { return "0" + text }
            return text
        }
        let hrs = padZeros(to: String(seconds / 3600))
        let mins = padZeros(to: String(seconds % 3600 / 60))
        let sec = padZeros(to: String(seconds % 3600 % 60))
        
        return "\(hrs):\(mins):\(sec)"
    }
}
