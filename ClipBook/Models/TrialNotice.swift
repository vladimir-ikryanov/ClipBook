import Foundation

/// The terms of the trial reminders and of the discount offered after the trial.
enum TrialOffer {
  /// The notice at the top of the history shows up this close to the end of
  /// the trial.
  static let daysLeftToShowNotice = 2
  static let moneyBackGuaranteeDays = 14
  static let discountCode = "CLPB20"
  static let discountPercent = 20
  /// The discount is offered to those who still open the history this long
  /// after the trial ended.
  static let delayBeforeDiscount: TimeInterval = 7 * 24 * 60 * 60
  static let discountDuration: TimeInterval = 48 * 60 * 60
}

/// The notice shown above the history list, outside of the list itself.
enum TrialNotice: Equatable {
  case endingSoon(daysLeft: Int)
  case ended
  case discount(endsAt: Date)

  /// Only the reminder before the end of the trial can be closed. Once the
  /// trial is over the history is read-only, and the notice says why.
  var isDismissible: Bool {
    if case .endingSoon = self {
      return true
    }

    return false
  }
}
