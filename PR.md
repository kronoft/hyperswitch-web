# feat(installments): an installment provider's options as the card number is typed

From branch `s6b-installments`. It goes with the router's pull request that adds the installment
provider, and does nothing until a router answers `card_bin_eligibility: true`.

## What

- When the payment method list says `card_bin_eligibility: true` and asks for an eligibility
  check, the card form sends the card's first 8 digits, and only those, to
  `POST /payments/{payment_id}/eligibility`:

  ```json
  {"payment_method_type": "card", "payment_method_data": {"card_bin": {"card_bin": "40000150"}}}
  ```

  It sends once 8 digits are typed, debounced as the existing eligibility call is, and again only
  when those 8 digits change. It never sends on fewer.
- `InstallmentOptions` shows the answer's `installment_options`, each plan with its total, when
  present. A plan chosen from earlier options is cleared when new ones arrive. The choice goes in
  `installment_data` on confirm, as today.
- Only that BIN call's answer sets or clears the options. The existing full-number eligibility
  call keeps its own effects (surcharge, offers, blocking) and never touches them, so the order the
  two answers land in does not matter.

## Why

The router can ask an installment provider for the counts a card may take and what each costs.
The customer should see them while typing the card number, before confirming.

## Off by default

Without `card_bin_eligibility` in the list, the SDK makes exactly the calls it makes today, and
`InstallmentOptions` shows the merchant's options exactly as today. Saved cards are unchanged.

The confirm check is unchanged: it holds only while an eligibility check is pending. The BIN call
never marks one pending, and a non-card method or a card that never reaches 8 digits makes no
call, so both confirm as before.

## Tests

`npm run test:unit` (Node's built-in test runner on the compiled ReScript; no new dependency):

- the first 8 digits, once 8 are typed;
- a typed card sends its BIN once, and again only when it changes, never on fewer than 8;
- without the list's `card_bin_eligibility`, no BIN call;
- only the BIN call's answer sets the options, whatever lands last;
- the body carries the 8 digits only, never the card number;
- the provider's options are shown, otherwise the merchant's;
- only a pending check holds confirm.

The new logic sits in `src/Utilities/InstallmentBin.res`, which depends only on ReScript Core, so
the tests import it directly. Rendering is not unit-tested: that would need a DOM library. The
existing parser and plan components render the totals unchanged. CI's ReScript build, webpack
build and eslint pass. All test data is synthetic.
