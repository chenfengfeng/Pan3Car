//
//  ChargeTaskRecord.swift
//  Pan3
//
//  Created by Mac on 2025/10/10.
//

import GRDB

struct ChargeTaskRecord: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?  // 可选类型，新记录时为nil，插入后自动分配
    var startTime: Date
    var endTime: Date?
    var startSoc: Int
    var endSoc: Int?
    var startKm: Int
    var endKm: Int?
    
    // GPS相关字段
    var lat: Double?      // 纬度
    var lon: Double?      // 经度
    var address: String?  // 地址

    // 定义表名
    static var databaseTableName = "chargeTask"
    
    // 便利初始化方法，用于创建新记录（ID由数据库自动分配）
    init(startTime: Date, 
         endTime: Date? = nil,
         startSoc: Int,
         endSoc: Int? = nil,
         startKm: Int,
         endKm: Int? = nil,
         lat: Double? = nil,
         lon: Double? = nil,
         address: String? = nil) {
        self.id = nil  // 新记录ID为nil，插入时数据库自动分配
        self.startTime = startTime
        self.endTime = endTime
        self.startSoc = startSoc
        self.endSoc = endSoc
        self.startKm = startKm
        self.endKm = endKm
        self.lat = lat
        self.lon = lon
        self.address = address
    }
    
    // GRDB要求：插入成功后更新自增ID
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
