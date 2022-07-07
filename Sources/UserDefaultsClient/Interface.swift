import ComposableArchitecture
import Foundation

public struct UserDefaultsClient {
  public var boolForKey: (String) -> Bool
  public var dataForKey: (String) -> Data?
  public var doubleForKey: (String) -> Double
  public var integerForKey: (String) -> Int
  public var remove: (String) -> Effect<Never, Never>
  public var removeAsync: @Sendable (String) async -> Void
  public var setBool: (Bool, String) -> Effect<Never, Never>
  public var setBoolAsync: @Sendable (Bool, String) async -> Void
  public var setData: (Data?, String) -> Effect<Never, Never>
  public var setDataAsync: @Sendable (Data?, String) async -> Void
  public var setDouble: (Double, String) -> Effect<Never, Never>
  public var setDoubleAsync: @Sendable (Double, String) async -> Void
  public var setInteger: (Int, String) -> Effect<Never, Never>
  public var setIntegerAsync: @Sendable (Int, String) async -> Void

  public var hasShownFirstLaunchOnboarding: Bool {
    self.boolForKey(hasShownFirstLaunchOnboardingKey)
  }

  public func setHasShownFirstLaunchOnboarding(_ bool: Bool) -> Effect<Never, Never> {
    self.setBool(bool, hasShownFirstLaunchOnboardingKey)
  }

  public var installationTime: Double {
    self.doubleForKey(installationTimeKey)
  }

  public func setInstallationTime(_ double: Double) -> Effect<Never, Never> {
    self.setDouble(double, installationTimeKey)
  }

  public func incrementMultiplayerOpensCount() -> Effect<Int, Never> {
    let incremented = self.integerForKey(multiplayerOpensCount) + 1
    return .concatenate(
      self.setInteger(incremented, multiplayerOpensCount).fireAndForget(),
      .init(value: incremented)
    )
  }
}

let hasShownFirstLaunchOnboardingKey = "hasShownFirstLaunchOnboardingKey"
let installationTimeKey = "installationTimeKey"
let multiplayerOpensCount = "multiplayerOpensCount"
