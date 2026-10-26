// An installment provider's options for the card being typed: its first 8 digits go to the
// eligibility call, never more and never fewer.

// The card's first 8 digits, once 8 are typed.
let cardBin = (_cardNumber: string): option<string> => None

// The BIN to send now: only when the first 8 digits differ from those last sent.
let binToSend = (~lastSent as _: option<string>, ~cardNumber as _: string): option<string> => None

// The eligibility call's body for a BIN.
let cardBinEligibilityBody = (_bin: string): array<(string, JSON.t)> => []

// The options to show: the eligibility answer's when it has any, otherwise the merchant's.
let shownOptions = (~eligibility as _: option<array<'a>>, ~merchant: array<'a>) => merchant

// Whether a pending eligibility check holds confirm.
let blocksConfirm = (~shouldBlockConfirm, ~isEligibilityPending as _) => shouldBlockConfirm
