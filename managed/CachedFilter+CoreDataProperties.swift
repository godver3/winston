//
//  CachedFilter+CoreDataProperties.swift
//  winston
//
//  Created by Igor Marcossi on 25/01/24.
//
//

import Foundation
import CoreData


struct ShallowCachedFilter: Equatable, Identifiable, Hashable {
  var id: String { self.text + self.subID }
  private(set) var bgColor: String?
  private(set) var subID: String
  private(set) var text: String
  private(set) var textColor: String?
  private(set) var new: Bool = false
  fileprivate var rawType: String
  var type: CachedFilter.FilterType {
    get { CachedFilter.FilterType(rawValue: self.rawType) ?? .flair }
  }
  
  func updateText(_ newText: String) -> ShallowCachedFilter {
    return CachedFilter.getShallow(bgColor: bgColor, subID: subID, text: newText)
  }
  
  func updateBG(_ newBG: String) -> ShallowCachedFilter {
    return CachedFilter.getShallow(bgColor: newBG, subID: subID, text: text)
  }
  
  func toString() -> String {
    return "\(bgColor ?? "FFFFFF"),\(subID),\(text)"
  }
}

extension CachedFilter {
  
  @nonobjc public class func fetchRequest() -> NSFetchRequest<CachedFilter> {
    return NSFetchRequest<CachedFilter>(entityName: "CachedFilter")
  }
  
  @NSManaged public var bgColor: String?
  @NSManaged public var subID: String
  @NSManaged public var text: String
  @NSManaged public var textColor: String?
  @NSManaged fileprivate var rawType: String
  
  convenience init(context: NSManagedObjectContext, subID: String, _ flair: Flair) {
    self.init(context: context)
    self.update(flair, subID: subID)
  }
  
  static func fromString(_ str: String) -> ShallowCachedFilter {
    let components = str.components(separatedBy: ",")
    let bg = components.count > 0 ? components[0] : "FFFFFF"
    let sub = components.count > 1 ? components[1] : ""
    let txt = components.count > 2 ? components[2] : ""
    
    return ShallowCachedFilter(bgColor: bg, subID: sub, text: txt, textColor: "FFFFFF", rawType: "custom")
  }
  
  static func getShallow(bgColor: String?, subID: String, text: String) -> ShallowCachedFilter {
    ShallowCachedFilter(bgColor: bgColor, subID: subID, text: text, textColor: "FFFFFF", rawType: "custom")
  }
  
  static func getNewShallow(subredditId: String) -> ShallowCachedFilter {
    ShallowCachedFilter(bgColor: "FFFFFF", subID: subredditId, text: "", textColor: "FFFFFF", new: true, rawType: "custom")
  }
  
  static func getDefaultsString(_ filters: [ShallowCachedFilter]) -> String {
    return filters.map { $0.toString() }.joined(separator: "|")
  }
  
  static func filtersFromDefaultsString(_ filtersStr: String?) -> [ShallowCachedFilter] {
    return filtersStr == nil || filtersStr == "" ? [] :
      filtersStr!.components(separatedBy: "|").map{ CachedFilter.fromString($0) }
  }
  
  func getShallow() -> ShallowCachedFilter {
    ShallowCachedFilter(bgColor: bgColor, subID: subID, text: text, textColor: textColor, rawType: rawType)
  }
  
  var type: FilterType {
    get { self.managedObjectContext?.performAndWait {
      FilterType(rawValue: self.rawType) ?? .flair
    } ?? .flair }
    set { self.managedObjectContext?.performAndWait { self.rawType = newValue.rawValue } }
  }
  
  enum FilterType: String {
    case flair, modFlair, custom
  }
  
  func update(_ flair: Flair, subID: String? = nil) {
    self.bgColor = flair.background_color
    self.text = flair.text
    if let subID { self.subID = subID }
    self.type = (flair.mod_only ?? false) ? .modFlair : .flair
    self.textColor = flair.text_color
  }
  
}

extension CachedFilter : Identifiable {
  public var id: String { self.text + self.subID }
}
