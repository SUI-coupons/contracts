module digital_coupons::coupons {
    use std::vector;

    use sui::object::{Self, ID, UID};
    use std::string::String;
    use sui::tx_context::{Self, TxContext};
    use sui::transfer::{Self, public_transfer};
    use sui::dynamic_object_field as ofield;  
    use sui::dynamic_field as dfield; 
    use sui::clock::{Self, Clock};

    struct COUPONS has drop {} 

    struct Coupon has key, store {
        id: UID,
        itemDiscount: String, // fashion or household items
        discount: u8, // maximum 200
        expirationDate: u64, // unix timestamp
    }

    struct CouponName has copy, drop, store {}

    struct ComsumerName has copy, drop, store {}

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
        consumers: vector<address>
    }

    struct BurnRequest has key {
        id: UID,
        coupon: Coupon,
        owner: address,
        consumer_address: address,
    }

    // ========== create, mint ==========

    public fun register_publisher(_: &mut AdminCap, ctx: &mut TxContext) {
        let id = object::new(ctx);
        transfer::transfer(PublisherCap { id, consumers: vector::empty() }, tx_context::sender(ctx));
    }

    public fun register_consumer(publisher: &mut PublisherCap, consumer_address: address, ctx: &mut TxContext) {
        vector::push_back(&mut publisher.consumers, consumer_address);
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
        expirationDate: u64,
        quantity: u16,
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

    // ========== consume coupons ==========

    public fun create_burn_request(
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

    public fun accept_burn_request(
        burnRequest: BurnRequest,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let BurnRequest {
            id,
            coupon,
            owner,
            consumer_address,
        }  = burnRequest;
        let sender = tx_context::sender(ctx);
        assert!(consumer_address == sender, 1);
        assert!(clock::timestamp_ms(clock) < coupon.expirationDate, 1);
        object::delete(id);
        let Coupon {
            id,
            itemDiscount,
            discount,
            expirationDate,
        } = coupon;
        object::delete(id);
    }

    public fun cancel_burn_request(
        burnRequest: BurnRequest,
        ctx: &mut TxContext,
    ) {
        let BurnRequest { id, coupon, owner, consumer_address } = burnRequest;
        let sender = tx_context::sender(ctx);
        assert!(owner == sender, 1);
        object::delete(id);
        transfer::public_transfer(coupon, owner);
    }

    fun init(_witness: COUPONS, ctx: &mut TxContext) {
        let id = object::new(ctx);
        let adminCap = AdminCap { id };
        transfer::public_transfer(adminCap, tx_context::sender(ctx));
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(COUPONS {}, ctx);
    }
}