type eligibilityState = {
  cardEligibilityError: option<string>,
  updateCardEligibilityError: option<string> => unit,
  eligibilitySurchargeDetails: option<EligibilityHelpers.eligibilitySurchargeDetails>,
  eligibilityOfferDetails: option<EligibilityHelpers.eligibilityOfferDetails>,
  isEligibilityPending: bool,
  eligibilityInstallmentOptions: option<array<PaymentMethodsRecord.installmentOption>>,
  triggerOnCardNumberChange: (~cardNumber: string, ~isCardSupportedAndValid: bool) => unit,
  resetEligibilityState: unit => unit,
}

let useCardEligibility = (~logger, ~runEligibility=true): eligibilityState => {
  open JotaiAtoms

  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)
  let {clientSecret, publishableKey, sdkAuthorization} = Jotai.useAtomValue(keys)
  let customPodUri = Jotai.useAtomValue(customPodUri)
  let (cardEligibilityError, setCardEligibilityError) = React.useState(_ => None)
  let (eligibilitySurchargeDetails, setEligibilitySurchargeDetails) = React.useState(_ => None)
  let (eligibilityOfferDetails, setEligibilityOfferDetails) = React.useState(_ => None)
  let (isEligibilityPending, setIsEligibilityPending) = React.useState(_ => false)
  let eligibilityControllerRef = React.useRef(None)
  // An installment provider's options, asked with the card's first 8 digits only.
  let (eligibilityInstallmentOptions, setEligibilityInstallmentOptions) = React.useState(_ => None)
  let lastBinRef = React.useRef(None)
  let binControllerRef = React.useRef(None)
  let {
    startDebounce: startBinDebounce,
    cancelDebounce: cancelBinDebounce,
  } = CommonHooks.useDebounce(~delayMs=300)
  let {
    startDebounce: startEligibilityDebounce,
    cancelDebounce: cancelEligibilityDebounce,
  } = CommonHooks.useDebounce(~delayMs=300)
  let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)

  React.useEffect0(() => {
    Some(
      () => {
        eligibilityControllerRef.current->Option.forEach(c => Fetch.AbortController.abort(c))
        binControllerRef.current->Option.forEach(c => Fetch.AbortController.abort(c))
      },
    )
  })

  let checkInstallmentOptions = async (~bin) => {
    binControllerRef.current->Option.forEach(c => Fetch.AbortController.abort(c))
    let controller = Fetch.AbortController.make()
    binControllerRef.current = Some(controller)
    switch clientSecret {
    | Some(clientSecret) =>
      try {
        let json = await PaymentHelpers.fetchPaymentMethodEligibility(
          ~clientSecret,
          ~publishableKey,
          ~logger,
          ~customPodUri,
          ~bodyArr=InstallmentBin.cardBinEligibilityBody(bin),
          ~sdkAuthorization,
          ~endpoint,
          ~signal=Fetch.AbortController.signal(controller),
        )

        // Only the answer for the digits typed now.
        if lastBinRef.current == Some(bin) {
          setEligibilityInstallmentOptions(current =>
            InstallmentBin.optionsAfterAnswer(
              ~current,
              ~fromBinCall=true,
              ~answered=json->Utils.getDictFromJson->PaymentMethodsRecord.getInstallmentOptions,
            )
          )
        }
      } catch {
      | _ => ()
      }
    | None => ()
    }
  }

  let checkCardEligibility = async (~cardNumber) => {
    await EligibilityHelpers.startEligibilityCheck(
      ~controllerRef=eligibilityControllerRef,
      ~clientSecret,
      ~publishableKey,
      ~logger,
      ~customPodUri,
      ~bodyArr=PaymentBody.cardPaymentMethodEligibilityBody(~cardNumber),
      ~sdkAuthorization,
      ~endpoint,
      ~setIsEligibilityPending,
      ~setEligibilitySurchargeDetails,
      ~setEligibilityOfferDetails,
      ~setEligibilityError=Some(setCardEligibilityError),
      ~errorLogMessage="Card payment eligibility check failed",
      ~fetchEligibility={
        (
          ~clientSecret,
          ~publishableKey,
          ~logger,
          ~customPodUri,
          ~bodyArr,
          ~sdkAuthorization,
          ~endpoint,
          ~signal,
        ) =>
          PaymentHelpers.fetchPaymentMethodEligibility(
            ~clientSecret,
            ~publishableKey,
            ~logger,
            ~customPodUri,
            ~bodyArr,
            ~sdkAuthorization,
            ~endpoint,
            ~signal,
          )
      },
    )
  }

  let resetEligibilityState = () => {
    setCardEligibilityError(_ => None)
    setEligibilitySurchargeDetails(_ => None)
    setEligibilityOfferDetails(_ => None)
    setIsEligibilityPending(_ => false)
    setEligibilityInstallmentOptions(_ => None)
  }

  let triggerOnCardNumberChange = (~cardNumber, ~isCardSupportedAndValid) => {
    let shouldRunEligibility = paymentMethodListValue.sdk_next_action === Some("eligibility_check")
    if runEligibility && shouldRunEligibility {
      switch InstallmentBin.binToSend(
        ~enabled=paymentMethodListValue.card_bin_eligibility,
        ~lastSent=lastBinRef.current,
        ~cardNumber,
      ) {
      | Some(bin) =>
        setEligibilityInstallmentOptions(_ => None)
        startBinDebounce(() => checkInstallmentOptions(~bin)->ignore)
      | None =>
        if InstallmentBin.cardBin(cardNumber)->Option.isNone {
          cancelBinDebounce()
          setEligibilityInstallmentOptions(_ => None)
        }
      }
      lastBinRef.current = InstallmentBin.cardBin(cardNumber)
      cancelEligibilityDebounce()
      setCardEligibilityError(_ => None)
      setEligibilitySurchargeDetails(_ => None)
      setEligibilityOfferDetails(_ => None)
      if !isCardSupportedAndValid {
        eligibilityControllerRef.current->Option.forEach(c => Fetch.AbortController.abort(c))
        eligibilityControllerRef.current = None
        setIsEligibilityPending(_ => false)
      } else {
        startEligibilityDebounce(() => {
          checkCardEligibility(~cardNumber)->ignore
        })
      }
    }
  }

  {
    cardEligibilityError,
    updateCardEligibilityError: error => setCardEligibilityError(_ => error),
    eligibilitySurchargeDetails,
    eligibilityOfferDetails,
    isEligibilityPending,
    eligibilityInstallmentOptions,
    triggerOnCardNumberChange,
    resetEligibilityState,
  }
}
