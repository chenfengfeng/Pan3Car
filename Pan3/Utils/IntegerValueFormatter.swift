//
//  IntegerValueFormatter.swift
//  Pan3
//
//  Created by AI Assistant on 2025-11-12
//

import Foundation
import DGCharts

/// 自定义整数值格式化器，用于DGCharts图表显示整数值（无小数点）
class IntegerValueFormatter: NSObject, ValueFormatter {
    func stringForValue(_ value: Double, entry: ChartDataEntry, dataSetIndex: Int, viewPortHandler: ViewPortHandler?) -> String {
        return String(format: "%.0f", value)
    }
}
