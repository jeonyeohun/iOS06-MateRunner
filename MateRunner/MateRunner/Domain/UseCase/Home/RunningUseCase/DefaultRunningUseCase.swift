//
//  DefaultRunningUseCase.swift
//  MateRunner
//
//  Created by 이유진 on 2021/11/05.
//

import CoreLocation
import Foundation

import RxSwift

final class DefaultRunningUseCase: RunningUseCase {
    private var points: [Point]
    private var currentMETs: Double
    private var disposeBag: DisposeBag
    
    private let cancelTimer: RxTimerService
    private let popUpTimer: RxTimerService
    private let runningTimer: RxTimerService
    private let coreMotionService: CoreMotionService
    private let runningRepository: RunningRepository
    private let userRepository: UserRepository
    private let firestoreRepository: FirestoreRepository
    
    var runningSetting: RunningSetting
    var runningData: BehaviorSubject<RunningData>
    var isCanceled: BehaviorSubject<Bool>
    var isCancelledByMate: BehaviorSubject<Bool>
    var isFinished: BehaviorSubject<Bool>
    var shouldShowPopUp: BehaviorSubject<Bool>
    var myProgress: BehaviorSubject<Double>
    var mateProgress: BehaviorSubject<Double>
    var totalProgress: BehaviorSubject<Double>
    var cancelTimeLeft: PublishSubject<Int>
    var popUpTimeLeft: PublishSubject<Int>
    var selfImageURL = PublishSubject<String>()
    var selfWeight = BehaviorSubject<Double>(value: 65)
    var mateImageURL = PublishSubject<String>()
    
    init(
        runningSetting: RunningSetting,
        cancelTimer: RxTimerService,
        runningTimer: RxTimerService,
        popUpTimer: RxTimerService,
        coreMotionService: CoreMotionService,
        runningRepository: RunningRepository,
        userRepository: UserRepository,
        firestoreRepository: FirestoreRepository
    ) {
        self.points = []
        self.currentMETs = 0.0
        self.disposeBag = DisposeBag()
        
        self.runningSetting = runningSetting
        self.cancelTimer = cancelTimer
        self.runningTimer = runningTimer
        self.popUpTimer = popUpTimer
        self.coreMotionService = coreMotionService
        self.runningRepository = runningRepository
        self.userRepository = userRepository
        self.firestoreRepository = firestoreRepository
        
        self.runningData = BehaviorSubject(value: RunningData())
        self.isCanceled  = BehaviorSubject(value: false)
        self.isCancelledByMate  = BehaviorSubject(value: false)
        self.isFinished = BehaviorSubject(value: false)
        self.shouldShowPopUp = BehaviorSubject<Bool>(value: false)
        self.myProgress = BehaviorSubject(value: 0.0)
        self.mateProgress = BehaviorSubject(value: 0.0)
        self.totalProgress = BehaviorSubject(value: 0.0)
        self.cancelTimeLeft = PublishSubject<Int>()
        self.popUpTimeLeft = PublishSubject<Int>()
    }
    
    func loadUserInfo() {
        guard let selfNickname = self.userNickname() else { return }
        self.firestoreRepository.fetchUserData(of: selfNickname)
            .compactMap { $0 }
            .subscribe(onNext: { [weak self] userData in
                self?.selfImageURL.onNext(userData.image)
                self?.selfWeight.onNext(userData.weight)
            })
            .disposed(by: self.disposeBag)
    }
    
    func loadMateInfo() {
        guard let mateNickname = self.runningSetting.mateNickname else { return }
        self.firestoreRepository.fetchUserData(of: mateNickname)
            .compactMap { $0 }
            .subscribe(onNext: { [weak self] userData in
                self?.mateImageURL.onNext(userData.image)
            })
            .disposed(by: self.disposeBag)
    }
    
    func updateRunningStatus() {
        guard let userNickname = self.userNickname() else { return }
        self.runningRepository.saveRunningStatus(of: userNickname, isRunning: true)
            .publish()
            .connect()
            .disposed(by: self.disposeBag)
    }
    
    func cancelRunningStatus() {
        guard let userNickname = self.userNickname() else { return }
        self.runningRepository.saveRunningStatus(of: userNickname, isRunning: false)
            .publish()
            .connect()
            .disposed(by: self.disposeBag)
    }
    
    func executePedometer() {
        self.coreMotionService.startPedometer()
            .subscribe(onNext: { [weak self] distance in
                guard let self = self else { return }
                self.updateProgress(self.myProgress, value: distance)
                self.updateMyDistance(with: distance)
                self.checkRunningShouldFinish(value: distance)
            })
            .disposed(by: self.disposeBag)
    }
    
    func executeActivity() {
        self.coreMotionService.startActivity()
            .subscribe(onNext: { [weak self] mets in
                self?.currentMETs = mets
            })
            .disposed(by: self.disposeBag)
    }
    
    func executeTimer() {
        self.runningTimer.start()
            .subscribe(onNext: { [weak self] time in
                guard let self = self,
                        let selfWeight = try? self.selfWeight.value() else { return }
                self.updateTime(with: time)
                self.updateCalorie(weight: selfWeight)
                if self.runningSetting.mode != .single {
                    self.saveMyRunningRealTimeData()
                }
            })
            .disposed(by: self.runningTimer.disposeBag)
    }
    
    func executeCancelTimer() {
        self.shouldShowPopUp.onNext(true)
        self.cancelTimeLeft.onNext(2)
        self.cancelTimer.start()
            .subscribe(onNext: { [weak self] newTime in
                self?.shouldShowPopUp.onNext(true)
                self?.checkTimeOver(from: newTime, with: 2, emitter: self?.cancelTimeLeft) {
                    self?.cancelRunning()
                }
            })
            .disposed(by: self.cancelTimer.disposeBag)
    }
    
    private func cancelRunning() {
        self.runningRepository.cancelSession(of: self.runningSetting)
            .publish()
            .connect()
            .disposed(by: self.disposeBag)
        self.isCanceled.onNext(true)
        self.clearServices()
    }
    
    func executePopUpTimer() {
        self.shouldShowPopUp.onNext(true)
        self.popUpTimer.start()
            .subscribe(onNext: { [weak self] newTime in
                self?.shouldShowPopUp.onNext(true)
                self?.checkTimeOver(from: newTime, with: 1, emitter: self?.popUpTimeLeft) {
                    self?.shouldShowPopUp.onNext(false)
                    self?.popUpTimer.stop()
                }
            })
            .disposed(by: self.popUpTimer.disposeBag)
    }
    
    func invalidateCancelTimer() {
        self.shouldShowPopUp.onNext(false)
        self.cancelTimeLeft.onNext(3)
        self.cancelTimer.stop()
    }
    
    private func listenIsCancelled(of sessionId: String) {
        self.runningRepository.listenIsCancelled(of: sessionId)
            .subscribe { [weak self] isCancelled in
            guard let self = self,
                  let isCancelled = isCancelled.element,
                  let isCancelledByMate = try? self.isCancelledByMate.value() else { return }
            
            if isCancelled && !isCancelledByMate {
                self.isCancelledByMate.onNext(isCancelled)
                self.stopListeningMate()
            }
        }.disposed(by: self.disposeBag)
    }
    
    private func listenMateRunningData(of mate: String, in sessionId: String) {
        self.runningRepository.listen(sessionId: sessionId, mate: mate)
            .subscribe(onNext: { [weak self] mateRunningRealTimeData in
                guard let self = self,
                      let currentData = try? self.runningData.value() else { return }
                
                self.runningData.onNext(
                    currentData.makeCopy(mateRunningRealTimeData: mateRunningRealTimeData)
                )
                
                guard let updatedRunningData = try? self.runningData.value() else { return }
                
                self.updateProgress(
                    self.mateProgress,
                    value: updatedRunningData.mateElapsedDistance
                )
                self.updateProgress(
                    self.totalProgress,
                    value: updatedRunningData.totalElapsedDistance
                )
                self.checkRunningShouldFinish(value: currentData.myElapsedDistance)
            })
            .disposed(by: self.disposeBag)
    }
    
    func listenRunningSession() {
        guard let sessionId = self.runningSetting.sessionId,
              let mateNickname = self.runningSetting.mateNickname else { return }
        
        self.listenIsCancelled(of: sessionId)
        self.listenMateRunningData(of: mateNickname, in: sessionId)
    }
    
    private func stopListeningMate() {
        guard let sessionId = self.runningSetting.sessionId,
              let mateNickname = self.runningSetting.mateNickname else { return }
        self.runningRepository.stopListen(sessionId: sessionId, mate: mateNickname)
    }
    
    private func userNickname() -> String? {
        return self.userRepository.fetchUserNickname()
    }
    
    private func checkRunningShouldFinish(value: Double) {
        guard let targetDistance = self.runningSetting.targetDistance,
              let mode = self.runningSetting.mode,
              let runningData = try? self.runningData.value() else { return }
        
        guard self.checkDistanceSatisfy(
            targetDistance: targetDistance,
            with: mode == .team
            ? runningData.totalElapsedDistance
            : runningData.myElapsedDistance
        ) else { return }
        
        self.clearServices()
        self.saveMyRunningRealTimeData()
        self.isFinished.onNext(true)
    }
    
    private func clearServices() {
        self.coreMotionService.stopAcitivity()
        self.coreMotionService.stopPedometer()
        self.cancelTimer.stop()
        self.runningTimer.stop()
        self.popUpTimer.stop()
        self.stopListeningMate()
        self.disposeBag = DisposeBag()
    }
    
    private func checkDistanceSatisfy(
        targetDistance: Double,
        with distance: Double
    ) -> Bool {
        return distance >= targetDistance
    }
    
    private func updateProgress(_ progress: BehaviorSubject<Double>, value: Double) {
        guard let targetDistance = self.runningSetting.targetDistance else { return }
        progress.onNext(value / targetDistance.meter)
    }
    
    private func updateCalorie(weight: Double) {
        guard let currentData = try? self.runningData.value() else { return }
        let updatedCalorie = calculateCalorie(of: weight)
        self.runningData.onNext(currentData.makeCopy(calorie: currentData.calorie + updatedCalorie))
    }
    
    private func updateMyDistance(with newDistance: Double) {
        guard let currentData = try? self.runningData.value() else { return }
        self.runningData.onNext(currentData.makeCopy(myElapsedDistance: newDistance.kilometer))
    }
    
    private func saveMyRunningRealTimeData() {
        guard let myRunningRealTimeData = try? self.runningData.value().myRunningRealTimeData,
              let userNickname = self.userNickname(),
              let sessionId = self.runningSetting.sessionId else { return }
        
        self.runningRepository.saveRunningRealTimeData(
            myRunningRealTimeData,
            sessionId: sessionId,
            user: userNickname
        )
            .publish()
            .connect()
            .disposed(by: self.disposeBag)
    }
    
    private func updateTime(with newTime: Int) {
        guard let currentData = try? self.runningData.value() else { return }
        self.runningData.onNext(currentData.makeCopy(myElapsedTime: newTime))
    }
    
    private func checkTimeOver(
        from time: Int,
        with limitTime: Int,
        emitter: PublishSubject<Int>?,
        actionAtLimit: () -> Void
    ) {
        guard let emitTarget = emitter else { return }
        emitTarget.onNext(limitTime - time)
        if time >= limitTime {
            actionAtLimit()
        }
    }
    
    private func calculateCalorie(of weight: Double) -> Double {
        return 1.08 * self.currentMETs * weight * (1 / 3600)
    }
    
    func createRunningResult(isCanceled: Bool) -> RunningResult {
        guard let runningData = try? self.runningData.value(),
              let mode = self.runningSetting.mode,
              let userNickname = self.userNickname() else {
                  return RunningResult(runningSetting: self.runningSetting, userNickname: "error")
              }
        let factory = RunningResultFactory(
            userNickname: userNickname,
            runningSetting: self.runningSetting,
            runningData: runningData,
            points: self.points,
            isCanceled: isCanceled
        )
        return factory.createResult(of: mode)
    }
}

extension DefaultRunningUseCase: LocationDidUpdateDelegate {
    func locationDidUpdate(_ location: CLLocation) {
        self.points.append(
            Point(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        )
    }
}
