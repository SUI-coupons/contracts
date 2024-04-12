module digital_coupons::rule {
    use std::vector::{Self};

    use sui::transfer_policy::{Self, TransferPolicy, TransferRequest, TransferPolicyCap};
    use sui::coin::{Self, Coin};
    use sui::sui::{SUI};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer::{Self};
    use sui::kiosk::{Self, Kiosk};
    use sui::package::{Self, Publisher};
    use sui::object::{Self, ID};

    use digital_coupons::coupons::{Self, Coupon, State};

    const EInsufficientAmount: u64 = 0;

    struct Rule has drop {}

    struct Config has store, drop { amount_bp: u16 }

    public fun create_transfer_policy(pub: &Publisher, fee: u16, ctx: &mut TxContext) {
        let (policy, policy_cap) = transfer_policy::new<Coupon>(pub, ctx);
        add(&mut policy, &policy_cap, fee);
        transfer::public_share_object(policy);
        transfer::public_transfer(policy_cap, tx_context::sender(ctx));
    }

    public fun buy_coupon(kiosk: &mut Kiosk, currentState: &mut State, policy: &mut TransferPolicy<Coupon>, id: ID, payment: Coin<SUI>, fee: Coin<SUI>, ctx: &mut TxContext) {
        coupons::remove_state_coupon(currentState, &id);
        let (inner, request) = kiosk::purchase<Coupon>(kiosk, id, payment);
        payFee(policy, &mut request, &mut fee, ctx);
        transfer::public_transfer(inner, tx_context::sender(ctx));
        transfer::public_transfer(fee, tx_context::sender(ctx));
        confirm_transfer_request(policy, request);
    }

    public fun confirm_transfer_request(
        policy: &TransferPolicy<Coupon>, 
        request: TransferRequest<Coupon>, 
    ) {
        transfer_policy::confirm_request<Coupon>(policy, request);
    }

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
