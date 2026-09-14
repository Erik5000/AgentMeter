//
//  TestError.swift
//  AgentMeterTests
//
//  Created by Edd on 2026-01-09.
//

import Foundation

struct TestError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
