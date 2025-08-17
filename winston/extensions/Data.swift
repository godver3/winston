//
//  Data.swift
//  winston
//
//  Created by Assistant on 2024.
//

import Foundation

extension Data {
  var prettyPrintedJSONString: String {
    guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
          let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
          let prettyPrintedString = String(data: data, encoding: .utf8) else {
      return String(data: self, encoding: .utf8) ?? "Unable to convert data to string"
    }
    return prettyPrintedString
  }
}
