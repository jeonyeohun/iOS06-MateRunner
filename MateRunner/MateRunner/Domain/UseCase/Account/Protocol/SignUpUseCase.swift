//
//  SignUpUseCase.swift
//  MateRunner
//
//  Created by 이정원 on 2021/11/15.
//

import Foundation

import RxSwift

protocol SignUpUseCase {
    var validText: PublishSubject<String?> { get set }
    var height: BehaviorSubject<Double?> { get set }
    var weight: BehaviorSubject<Double?> { get set }
    var canSignUp: PublishSubject<Bool> { get set }
    var signUpResult: PublishSubject<Bool> { get set }
    func validate(text: String)
    func checkDuplicate(of nickname: String?)
    func signUp(nickname: String?)
    func saveFCMToken(of nickname: String?)
    func saveLoginInfo(nickname: String?)
}
