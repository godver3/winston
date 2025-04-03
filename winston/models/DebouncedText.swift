//
//  debouncedText.swift
//  winston
//
//  Created by Igor Marcossi on 27/07/23.
//

import Foundation

@Observable
class Debouncer<V> {
  private var timer = TimerHolder()
  private var delay: Double
  var value: V {
    didSet {
      timer.fireIn(delay) {
        self.debounced = self.value
      }
    }
  }
  private(set) var debounced: V
  
  init(_ val: V, delay: Double = 0.4) {
    value = val
    debounced = val
    self.delay = delay
  }
}


@Observable
class AtMostEveryNDebouncer<V> {
  private var timer: Timer? = nil
  private var delay: Double
  private var lastSetDate: Date = .distantPast
  var value: V {
    didSet {
      let diff = (-1 * lastSetDate.timeIntervalSinceNow) - delay

      if diff > 0 {
        lastSetDate = .now
        debounced = value
        
        timer?.invalidate()
        timer = nil
        
        return
      }
      
      if timer != nil { return }
      
      timer = Timer.scheduledTimer(withTimeInterval: diff, repeats: false) { timer in
        self.lastSetDate = .now
        self.debounced = self.value
        
        timer.invalidate()
        self.timer = nil
      }
    }
  }
  private(set) var debounced: V
  
  init(_ val: V, delay: Double = 0.4) {
    value = val
    debounced = val
    self.delay = delay
  }
}
