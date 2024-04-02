module digital_coupons::coupons {
    use sui::object::{Self, ID, UID};
    use std::string::String;
    use sui::tx_context::{Self, TxContext};
    use sui::transfer::{Self, public_transfer};
    use sui::dynamic_object_field as ofield;   

    struct COUPONS has drop {} 

    struct Coupon has key, store {
        id: UID,
        itemDiscount: String, // fashion or household items
        discount: u8, // maximum 200
        expirationDate: u256, // unix timestamp
    }

    struct CouponName has copy, drop, store {}

    struct Campain has key, store {
        id: UID,
        description: String, // campain description
        publisher: address // publisher address of the campain
    }

    struct AdminCap has key, store {
        id: UID,
    }

    struct PublisherCap has key {
        id: UID,
    }

    struct BurnRequest has key {
        id: UID,
        coupon: Coupon,
        owner: address,
        consumer_address: address,
    }

    public fun register_publisher(_: &mut AdminCap, ctx: &mut TxContext) {
        let id = object::new(ctx);
        transfer::transfer(PublisherCap { id }, tx_context::sender(ctx));
    }

    public fun create_new_campain(
        _: &mut PublisherCap,
        description: String,
        ctx: &mut TxContext,
    ) {
        let id = object::new(ctx);
        let campain = Campain {
            id,
            description,
            publisher: tx_context::sender(ctx),
        };
        transfer::public_transfer(campain, tx_context::sender(ctx));
    }

    public fun create_new_coupons(
        campaign: &mut Campain,
        itemDiscount: String,
        discount: u8,
        expirationDate: u256,
        quantity: u256,
        ctx: &mut TxContext,
    ) {
        let i = 0;
        loop {
            if (i == quantity) break;
            let id = object::new(ctx);
            let coupon = Coupon {
                id,
                itemDiscount,
                discount,
                expirationDate,
            };
            ofield::add(&mut campaign.id, CouponName {}, coupon);
        };
    }


    // consume nft

    fun create_burn_request(
        coupon: Coupon,
        consumer_address: address,
        ctx: &mut TxContext,
    ) {
        let id = object::new(ctx);
        let burnRequest = BurnRequest {
            id,
            coupon,
            owner: tx_context::sender(ctx),
            consumer_address,
        };
        transfer::share_object(burnRequest);
    }

    fun accept_burn_request(
        burnRequest: &mut BurnRequest,
        ctx: &mut TxContext,
    ) {
        let coupon = burnRequest.coupon;
        let owner = burnRequest.owner;
        let consumer_address = burnRequest.consumer_address;
        assert!(consumer_address, tx_context::sender(ctx));
        transfer::transfer(coupon, consumer_address);
    }


    fun init(witness: COUPONS, ctx: &mut TxContext) {
        let id = object::new(ctx);
        let adminCap = AdminCap { id };
        transfer::public_transfer(adminCap, tx_context::sender(ctx));
    }
}