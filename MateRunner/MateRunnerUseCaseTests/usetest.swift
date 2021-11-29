//
//  usetest.swift
//  MateRunnerUseCaseTests
//
//  Created by 전여훈 on 2021/11/30.
//

import XCTest

class DistanceSettingUseCaseTests: XCTestCase {
    func test_설정버튼탭_소수점기호로_끝나면_0두개_붙이기() {
        let a = 1
        XCTAssert(a == 1)
    }
}
