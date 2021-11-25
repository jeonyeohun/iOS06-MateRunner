//
//  ProfileEditCoordinator.swift
//  MateRunner
//
//  Created by 김민지 on 2021/11/24.
//

import Foundation

protocol ProfileEditCoordinator: Coordinator {
    func pushProfileEditViewController(with nickname: String)
}
