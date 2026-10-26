// The installment provider's BIN and options, on the compiled ReScript: `npm run test:unit`.
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  cardBin,
  binToSend,
  cardBinEligibilityBody,
  shownOptions,
  optionsAfterAnswer,
  blocksConfirm,
} from "../../src/Utilities/InstallmentBin.bs.js";

const CARD = "4000015012345678";

// The calls a card typed, edited or cut back makes, as the SDK keeps the BIN last sent.
const sent = (numbers, enabled = true) => {
  let lastSent;
  const calls = [];
  for (const cardNumber of numbers) {
    const bin = binToSend(enabled, lastSent, cardNumber);
    if (bin !== undefined) calls.push(bin);
    lastSent = cardBin(cardNumber);
  }
  return calls;
};

const typed = (number) => [...number].map((_, i) => number.slice(0, i + 1));

test("the first 8 digits, once 8 are typed", () => {
  assert.equal(cardBin("4000015"), undefined);
  assert.equal(cardBin("40000150"), "40000150");
  assert.equal(cardBin(CARD), "40000150");
});

test("a typed card sends its BIN once, and again only when it changes", () => {
  assert.deepEqual(sent(typed(CARD)), ["40000150"]);
  // Digits after the 8th change nothing.
  assert.deepEqual(sent([CARD, "4000015099999999"]), ["40000150"]);
  // Another first 8 digits: sent again.
  assert.deepEqual(sent([CARD, "5100015012345678"]), ["40000150", "51000150"]);
  // Never on fewer than 8: cut back to 7, nothing is sent; typed again, the BIN is sent again.
  assert.deepEqual(sent([CARD, "4000015", "40000150"]), ["40000150", "40000150"]);
  assert.deepEqual(sent(typed("4000015")), []);
});

test("without the list's card_bin_eligibility, no BIN call: upstream's calls only", () => {
  assert.deepEqual(sent(typed(CARD), false), []);
  assert.deepEqual(sent([CARD, "5100015012345678"], false), []);
});

test("only the BIN call's answer sets the options, whatever lands last", () => {
  const provider = [{ payment_method: "card", available_plans: [{ number_of_installments: 3 }] }];
  const shown = optionsAfterAnswer(undefined, true, provider);
  assert.equal(shown, provider);
  // Upstream's full-number answer, without installment_options, lands after: the options stay.
  assert.equal(optionsAfterAnswer(shown, false, undefined), provider);
  // A later BIN's answer replaces them, and one without options clears them.
  assert.equal(optionsAfterAnswer(shown, true, undefined), undefined);
});

test("the body carries the 8 digits only, never the card number", () => {
  const body = Object.fromEntries(cardBinEligibilityBody("40000150"));
  assert.deepEqual(body, {
    payment_method_type: "card",
    payment_method_data: { card_bin: { card_bin: "40000150" } },
  });
  assert.ok(!JSON.stringify(body).includes("card_number"));
});

test("the provider's options are shown, otherwise the merchant's as upstream", () => {
  const merchant = [{ payment_method: "card", available_plans: [] }];
  const provider = [{ payment_method: "card", available_plans: [{ number_of_installments: 3 }] }];
  assert.equal(shownOptions(provider, merchant), provider);
  assert.equal(shownOptions(undefined, merchant), merchant);
  assert.equal(shownOptions([], merchant), merchant);
});

test("only a pending check holds confirm: another method or a short card confirms", () => {
  // A non-card method, or a card that never reaches 8 digits, has no check pending.
  assert.equal(blocksConfirm(true, false), false);
  assert.equal(blocksConfirm(true, true), true);
  assert.equal(blocksConfirm(false, true), false);
});
