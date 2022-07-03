import ComposableArchitecture

extension StoreKitClient {
  public static let noop = Self(
    addPayment: { _ in .none },
    addPaymentAsync: { _ in },
    appStoreReceiptURL: { nil },
    isAuthorizedForPayments: { false },
    fetchProducts: { _ in .none },
    fetchProductsAsync: { _ in try await Task.never() },
    finishTransaction: { _ in .none },
    finishTransactionAsync: { _ in },
    observer: .none,
    observerAsync: { AsyncStream { _ in } },
    requestReview: { .none },
    requestReviewAsync: {},
    restoreCompletedTransactions: { .none },
    restoreCompletedTransactionsAsync: {}
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension StoreKitClient {
    public static let failing = Self(
      addPayment: { _ in .failing("\(Self.self).addPayment is unimplemented") },
      addPaymentAsync: XCTUnimplemented("\(Self.self).addPaymentAsync"),
      appStoreReceiptURL: {
        XCTFail("\(Self.self).appStoreReceiptURL is unimplemented")
        return nil
      },
      isAuthorizedForPayments: {
        XCTFail("\(Self.self).isAuthorizedForPayments is unimplemented")
        return false
      },
      fetchProducts: { _ in .failing("\(Self.self).fetchProducts is unimplemented") },
      fetchProductsAsync: XCTUnimplemented("\(Self.self).fetchProductsAsync"),
      finishTransaction: { _ in .failing("\(Self.self).finishTransaction is unimplemented") },
      finishTransactionAsync: XCTUnimplemented("\(Self.self).finishTransactionAsync"),
      observer: .failing("\(Self.self).observer is unimplemented"),
      observerAsync: XCTUnimplemented("\(Self.self).observerAsync"),
      requestReview: { .failing("\(Self.self).requestReview is unimplemented") },
      requestReviewAsync: XCTUnimplemented("\(Self.self).requestReviewAsync"),
      restoreCompletedTransactions: { .failing("\(Self.self).fireAndForget is unimplemented") },
      restoreCompletedTransactionsAsync: XCTUnimplemented(
        "\(Self.self).restoreCompletedTransactionsAsync"
      )
    )
  }
#endif
