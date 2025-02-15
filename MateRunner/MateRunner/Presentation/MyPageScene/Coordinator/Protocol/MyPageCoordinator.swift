//
//  MyPageCoordinator.swift
//  MateRunner
//
//  Created by 김민지 on 2021/11/23.
//

import Foundation

protocol MyPageCoordinator: Coordinator {
    func showNotificationFlow()
    func showProfileEditFlow(with nickname: String)
    func showLicenseFlow()
}
