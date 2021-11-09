//
//  DefaultRunningUseCase.swift
//  MateRunner
//
//  Created by 이유진 on 2021/11/05.
//

import Foundation

import RxSwift

final class DefaultRunningUseCase: RunningUseCase {
    private let coreMotionManager = CoreMotionManager()
    private var currentMETs = 0.0
	var runningTimeSpent: BehaviorSubject<Int> = BehaviorSubject(value: 0)
	var cancelTimeLeft: BehaviorSubject<Int> = BehaviorSubject(value: 3)
	var popUpTimeLeft: BehaviorSubject<Int> = BehaviorSubject(value: 2)
	var inCancelled: BehaviorSubject<Bool> = BehaviorSubject(value: false)
	var shouldShowPopUp: BehaviorSubject<Bool> = BehaviorSubject(value: false)
    var distance = BehaviorSubject(value: 0.0)
    var progress = BehaviorSubject(value: 0.0)
    var calories = BehaviorSubject(value: 0.0)
    var finishRunning = BehaviorSubject(value: false)
	private var runningTimeDisposeBag = DisposeBag()
	private var cancelTimeDisposeBag = DisposeBag()
	private var popUpTimeDisposeBag = DisposeBag()
	private let disposeBag = DisposeBag()

    func executePedometer() {
        self.coreMotionManager.startPedometer()
            .subscribe(onNext: { [weak self] distance in
                self?.checkDistance(value: distance)
                self?.updateProgress(value: distance)
                self?.distance.onNext(distance)
            })
            .disposed(by: self.disposeBag)
    }
    
    func executeActivity() {
        self.coreMotionManager.startActivity()
            .subscribe(onNext: { [weak self] mets in
                self?.currentMETs = mets
            })
            .disposed(by: self.disposeBag)
    }
	
	func executeTimer() {
		self.generateTimer()
			.bind(to: self.runningTimeSpent)
			.disposed(by: self.runningTimeDisposeBag)
	}
	
	func executeCancelTimer() {
		self.generateTimer()
			.subscribe(onNext: { [weak self] newTime in
				self?.shouldShowPopUp.onNext(true)
				self?.checkTimeOver(from: newTime, with: 3, emitTarget: self?.cancelTimeLeft) {
					self?.inCancelled.onNext(true)
					self?.cancelTimeDisposeBag = DisposeBag()
				}
			})
			.disposed(by: self.cancelTimeDisposeBag)
	}
	
	func executePopUpTimer() {
		self.generateTimer()
			.subscribe(onNext: { [weak self] newTime in
				self?.shouldShowPopUp.onNext(true)
				self?.checkTimeOver(from: newTime, with: 2, emitTarget: self?.popUpTimeLeft) {
					self?.shouldShowPopUp.onNext(false)
					self?.popUpTimeDisposeBag = DisposeBag()
				}
			})
			.disposed(by: self.popUpTimeDisposeBag)
	}
	
	func invalidateCancelTimer() {
		self.cancelTimeDisposeBag = DisposeBag()
		self.shouldShowPopUp.onNext(false)
		self.cancelTimeLeft.onNext(3)
	}
  
  private func convertToMeter(value: Double) -> Double {
        return value * 1000
  }
    
    private func checkDistance(value: Double) {
        // *Fix : 0.05 고정 값 데이터 받으면 변경해야함
        if value >= self.convertToMeter(value: 0.05) {
            self.finishRunning.onNext(true)
            self.coreMotionManager.stopPedometer()
        }
    }
    
    private func updateProgress(value: Double) {
        // *Fix : 0.05 고정 값 데이터 받으면 변경해야함
        self.progress.onNext(value / self.convertToMeter(value: 0.05))
    }
    
    private func updateCalorie(weight: Double) {
        // 1초마다 실행되어야 함
        // 1초마다 칼로리 증가량 : 1.08 * METs * 몸무게(kg) * (1/3600)(hr)
        // walking : 3.8METs , running : 10.0METs
        // *Fix : 몸무게 고정 값 나중에 변경해야함
        let updateValue = (1.08 * self.currentMETs * weight * (1 / 3600))
        guard let calorie = try? self.calories.value() + updateValue else { return }
        self.calories.onNext(calorie)
    }
	
	private func checkTimeOver(
		from time: Int,
		with limitTime: Int,
		emitTarget: BehaviorSubject<Int>?,
		actionAtLimit: () -> Void
	) {
		guard let emitTarget = emitTarget else { return }
		emitTarget.onNext(limitTime - time)
		if time >= limitTime {
			actionAtLimit()
		}
	}
	
	private func generateTimer() -> Observable<Int> {
		return Observable<Int>
			.interval(
				RxTimeInterval.seconds(1),
				scheduler: MainScheduler.instance
			)
			.map { $0 + 1 }
	}
}
