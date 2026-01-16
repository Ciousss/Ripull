
(define-constant contract-owner tx-sender)

(define-constant err-invalid-amount u400)
(define-constant err-too-early u401)
(define-constant err-too-late u402)
(define-constant err-paused u403)
(define-constant err-not-found u404)
(define-constant err-max-exceeded u405)
(define-constant err-provider-inactive u406)
(define-constant err-unauthorized u407)
(define-constant err-invalid-interval u408)

(define-map providers
    { provider: principal }
    { active: bool, registered-at: uint }
)

(define-map subscriptions 
    { subscriber: principal, provider: principal } 
    { max-amount: uint, interval: uint, grace: uint, last-payment: uint, paused: bool }
)

(define-read-only (get-provider (provider principal))
    (map-get? providers { provider: provider })
)

(define-read-only (is-provider-active (provider principal))
    (match (map-get? providers { provider: provider })
        entry (get active entry)
        false
    )
)

(define-read-only (get-subscription (subscriber principal) (provider principal))
    (map-get? subscriptions { subscriber: subscriber, provider: provider })
)

(define-public (set-provider (provider principal) (active bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err err-unauthorized))
        (let ((current (map-get? providers { provider: provider })))
            (if (is-some current)
                (map-set providers { provider: provider } (merge (unwrap-panic current) { active: active }))
                (map-set providers { provider: provider } { active: active, registered-at: burn-block-height })
            )
        )
        (print { event: "provider-update", provider: provider, active: active, height: burn-block-height })
        (ok true)
    )
)

(define-public (subscribe (provider principal) (max-amount uint) (interval uint) (grace uint))
    (begin
        (asserts! (is-provider-active provider) (err err-provider-inactive))
        (asserts! (> max-amount u0) (err err-invalid-amount))
        (asserts! (> interval u0) (err err-invalid-interval))
        (map-set subscriptions 
            { subscriber: tx-sender, provider: provider }
            { max-amount: max-amount, interval: interval, grace: grace, last-payment: burn-block-height, paused: false }
        )
        (print { event: "subscribe", subscriber: tx-sender, provider: provider, max-amount: max-amount, interval: interval, grace: grace, height: burn-block-height })
        (ok true)
    )
)

(define-public (update-subscription (provider principal) (max-amount uint) (interval uint) (grace uint))
    (let ((sub (unwrap! (map-get? subscriptions { subscriber: tx-sender, provider: provider }) (err err-not-found))))
        (begin
            (asserts! (> max-amount u0) (err err-invalid-amount))
            (asserts! (> interval u0) (err err-invalid-interval))
            (map-set subscriptions 
                { subscriber: tx-sender, provider: provider }
                (merge sub { max-amount: max-amount, interval: interval, grace: grace })
            )
            (print { event: "update-subscription", subscriber: tx-sender, provider: provider, max-amount: max-amount, interval: interval, grace: grace, height: burn-block-height })
            (ok true)
        )
    )
)

(define-public (pause-subscription (provider principal))
    (let ((sub (unwrap! (map-get? subscriptions { subscriber: tx-sender, provider: provider }) (err err-not-found))))
        (begin
            (map-set subscriptions 
                { subscriber: tx-sender, provider: provider }
                (merge sub { paused: true })
            )
            (print { event: "pause", subscriber: tx-sender, provider: provider, height: burn-block-height })
            (ok true)
        )
    )
)

(define-public (resume-subscription (provider principal))
    (let ((sub (unwrap! (map-get? subscriptions { subscriber: tx-sender, provider: provider }) (err err-not-found))))
        (begin
            (map-set subscriptions 
                { subscriber: tx-sender, provider: provider }
                (merge sub { paused: false, last-payment: burn-block-height })
            )
            (print { event: "resume", subscriber: tx-sender, provider: provider, height: burn-block-height })
            (ok true)
        )
    )
)

(define-public (cancel-subscription (provider principal))
    (begin
        (asserts! (is-some (map-get? subscriptions { subscriber: tx-sender, provider: provider })) (err err-not-found))
        (map-delete subscriptions { subscriber: tx-sender, provider: provider })
        (print { event: "cancel", subscriber: tx-sender, provider: provider, height: burn-block-height })
        (ok true)
    )
)

(define-public (collect-payment (user principal) (amount uint))
    (let ((sub (unwrap! (map-get? subscriptions { subscriber: user, provider: tx-sender }) (err err-not-found))))
        (let ((due (+ (get last-payment sub) (get interval sub)))
              (latest (+ (get last-payment sub) (get interval sub) (get grace sub)))
              (grace (get grace sub)))
            (begin
                (asserts! (is-provider-active tx-sender) (err err-provider-inactive))
                (asserts! (not (get paused sub)) (err err-paused))
                (asserts! (> amount u0) (err err-invalid-amount))
                (asserts! (<= amount (get max-amount sub)) (err err-max-exceeded))
                (asserts! (>= burn-block-height due) (err err-too-early))
                (if (> grace u0)
                    (asserts! (<= burn-block-height latest) (err err-too-late))
                    true
                )
                (try! (stx-transfer? amount user tx-sender))
                (map-set subscriptions { subscriber: user, provider: tx-sender } (merge sub { last-payment: burn-block-height }))
                (print { event: "collect", subscriber: user, provider: tx-sender, amount: amount, height: burn-block-height })
                (ok true)
            )
        )
    )
)
