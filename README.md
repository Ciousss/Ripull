## Ripull (Clarity)

Framework for periodic STX pulls where subscribers authorize a provider and the provider collects within a time window.

### Storage

- `providers` map: `{ provider: principal } -> { active: bool, registered-at: uint }`
- `subscriptions` map: `{ subscriber: principal, provider: principal } -> { max-amount: uint, interval: uint, grace: uint, last-payment: uint, paused: bool }`

### Read-only functions

- `get-provider(provider)` -> provider entry or `none`
- `is-provider-active(provider)` -> `bool`
- `get-subscription(subscriber, provider)` -> subscription entry or `none`

### Public functions

- `set-provider(provider, active)`  
  Only `contract-owner` can add or toggle a provider. Emits `provider-update`.
- `subscribe(provider, max-amount, interval, grace)`  
  Creates or overwrites a subscription for `tx-sender` with the given limits and timing. Emits `subscribe`.
- `update-subscription(provider, max-amount, interval, grace)`  
  Updates an existing subscription owned by `tx-sender`. Emits `update-subscription`.
- `pause-subscription(provider)` / `resume-subscription(provider)`  
  Pauses or resumes a subscription. `resume-subscription` also resets `last-payment` to `burn-block-height`. Emits `pause` or `resume`.
- `cancel-subscription(provider)`  
  Deletes the subscription for `tx-sender`. Emits `cancel`.
- `collect-payment(user, amount)`  
  Provider pulls `amount` (must be `> 0` and `<= max-amount`) if the interval has elapsed and the subscription is active. If `grace > 0`, collection must happen on or before `last-payment + interval + grace`. Emits `collect`.

### Events

The contract uses `print` for simple event logs:

- `provider-update`, `subscribe`, `update-subscription`, `pause`, `resume`, `cancel`, `collect`

Each event includes at least `event`, involved principals, and `height`; `collect` also includes `amount`.

### Errors

Error constants returned via `(err ...)`:

- `err-invalid-amount (u400)`
- `err-too-early (u401)`
- `err-too-late (u402)`
- `err-paused (u403)`
- `err-not-found (u404)`
- `err-max-exceeded (u405)`
- `err-provider-inactive (u406)`
- `err-unauthorized (u407)`
- `err-invalid-interval (u408)`
