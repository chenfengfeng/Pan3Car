//
//  ChargeTaskRecord.swift
//  Pan3
//
//  Created by Mac on 2025/10/10.
//

import GRDB

struct ChargeTaskRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var vin: String
    var monitoringMode: String
    var targetValue: String
    var autoStopCharge: Bool
    var finalStatus: String
    var finalMessage: String?
    var startTime: Date
    var endTime: Date?
    var startSoc: Int?
    var endSoc: Int?
    var startRange: Int?
    var endRange: Int?

    // 定义表名
    static var databaseTableName = "chargeTask"
}
