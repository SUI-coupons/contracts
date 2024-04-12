module digital_coupons::rule {
    use sui::transfer_policy::{Self, TransferPolicy, TransferRequest, TransferPolicyCap};
    use sui::coin::{Self, Coin};
    use sui::sui::{SUI};
    use sui::tx_context::{TxContext};
    use sui::transfer::{Self};

    use digital_coupons::coupons::{Self, Coupon};

    const EInsufficientAmount: u64 = 0;

    struct Rule has drop {}

    struct Config has store, drop { amount_bp: u16 }

    public fun add<T>(
        policy: &mut TransferPolicy<T>,
        cap: &TransferPolicyCap<T>,
        amount_bp: u16
    ) {
        assert!(amount_bp <= 10_000, 0);
        transfer_policy::add_rule(Rule {}, policy, cap, Config { amount_bp })
    }

    public fun payFee (
        policy: &mut TransferPolicy<Coupon>,
        request: &mut TransferRequest<Coupon>,
        payment: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let paid = transfer_policy::paid(request);
        let config: &Config = transfer_policy::get_rule(Rule {}, policy);
        let fee_amount = (((paid as u128) * (config.amount_bp as u128) / 10_000) as u64);
        assert!(coin::value(payment) >= fee_amount, EInsufficientAmount);

        let fee = coin::split(payment, fee_amount, ctx);
        transfer_policy::add_to_balance(Rule {}, policy, fee);
        transfer_policy::add_receipt(Rule {}, request);
    }
}
