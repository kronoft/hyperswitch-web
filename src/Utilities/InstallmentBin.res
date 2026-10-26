// An installment provider's options for the card being typed: its first 8 digits go to the
// eligibility call, never more and never fewer.

let binLength = 8

// The card's first 8 digits, once 8 are typed.
let cardBin = (cardNumber: string): option<string> => {
  let bin = cardNumber->String.slice(~start=0, ~end=binLength)
  bin->String.length == binLength && /^\d+$/->RegExp.test(bin) ? Some(bin) : None
}

// The BIN to send now: only when the list turns the call on and the first 8 digits differ from
// those last sent.
let binToSend = (~enabled: bool, ~lastSent: option<string>, ~cardNumber: string): option<string> =>
  switch cardBin(cardNumber) {
  | Some(bin) if enabled && lastSent != Some(bin) => Some(bin)
  | _ => None
  }

// The eligibility call's body for a BIN.
let cardBinEligibilityBody = (bin: string): array<(string, JSON.t)> => [
  ("payment_method_type", "card"->JSON.Encode.string),
  (
    "payment_method_data",
    [("card_bin", [("card_bin", bin->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object)]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

// The options to show: the eligibility answer's when it has any, otherwise the merchant's.
let shownOptions = (~eligibility: option<array<'a>>, ~merchant: array<'a>) =>
  switch eligibility {
  | Some(options) if options->Array.length > 0 => options
  | _ => merchant
  }

// The installment options once an eligibility answer lands.
// Only the BIN call's answer sets them: upstream's full-number answer never does, whatever lands
// last.
let optionsAfterAnswer = (~current: option<'a>, ~fromBinCall: bool, ~answered: option<'a>) =>
  fromBinCall ? answered : current

// Whether a pending eligibility check holds confirm.
let blocksConfirm = (~shouldBlockConfirm, ~isEligibilityPending) =>
  shouldBlockConfirm && isEligibilityPending
