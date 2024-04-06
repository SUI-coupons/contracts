module digital_coupons::coupons {
    use std::vector::{Self};
    use std::string::String;
    
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer::{Self};
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use sui::transfer_policy::{Self, TransferPolicy, TransferRequest};
    use sui::package::{Self, Publisher};
    use sui::coin::{Self, Coin};
    use sui::sui::{SUI};
    use sui::kiosk::{Self, Kiosk};

    use digital_coupons::rule::{Self};

    const EAlreadyPublisher: u64 = 0;
    const ENotPublisher: u64 = 1;
    const ENotSeller: u64 = 2;
    const ENotInvalidSeller: u64 = 3;
    const ENotCouponOwner: u64 = 4;
    const EExpiredCoupon: u64 = 5;

    struct COUPONS has drop {} 

    struct Coupon has key, store {
        id: UID,
        itemDiscount: String, // fashion or household items
        discount: u8, // maximum 200
        expirationDate: u64, // unix timestamp
        publisher: address, // publisher address of the coupon
    }

    struct AdminCap has key, store {
        id: UID,
    }

    struct State has key, store {
        id: UID,
        publisherList: vector<address>,
        sellerList: Table<address, vector<address>>,
    }

    struct BurnRequest has key, store {
        id: UID,
        coupon: Coupon,
        owner: address,
        seller: address,
    }

    // =========================== Publisher ===========================

    public fun is_publisher(currentState: &State, publisher: &address): bool {
        vector::contains(&currentState.publisherList, publisher)
    }

    public fun register_publisher(_: &mut AdminCap, currentState: &mut State, publisher: address) {
        if (is_publisher(currentState, &publisher)) {
            abort EAlreadyPublisher
        };
        vector::push_back(&mut currentState.publisherList, publisher);
        table::add<address, vector<address>>(&mut currentState.sellerList, publisher, vector::singleton<address>(publisher));
    }

    public fun remove_publisher(_: &mut AdminCap, currentState: &mut State, publisher: address) {
        let publisherListMut = &mut currentState.publisherList;
        let (is_publisher, index) = vector::index_of(publisherListMut, &publisher);
        if (!is_publisher) {
            abort ENotPublisher
        };
        vector::remove(publisherListMut, index);
        table::remove<address, vector<address>>(&mut currentState.sellerList, publisher);
    }

    // =========================== Seller ===========================

    public fun is_seller(currentState: &State, seller: &address, publisher: &address): bool {
        let sellerList = table::borrow<address, vector<address>>(&currentState.sellerList, *publisher);
        vector::contains(sellerList, seller)
    }

    public fun register_seller(currentState: &mut State, seller: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        if (!is_publisher(currentState, &sender)) {
            abort ENotPublisher
        };
        let sellerListMut = &mut currentState.sellerList;
        let sellerList = table::borrow_mut<address, vector<address>>(sellerListMut, sender);
        vector::push_back(sellerList, seller);
    }

    public fun remove_seller(_: &mut AdminCap, currentState: &mut State, seller: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        if (!is_publisher(currentState, &sender)) {
            abort ENotPublisher
        };
        let sellerListMut = &mut currentState.sellerList;
        let sellerList = table::borrow_mut<address, vector<address>>(sellerListMut, sender);
        let (is_seller, index) = vector::index_of(sellerList, &seller);
        if (is_seller) {
            vector::remove(sellerList, index);
        } else {
            abort ENotSeller
        }
    }

    // =========================== Coupon ===========================

    fun create_shared_coupon(itemDiscount: String, discount: u8, expirationDate: u64, ctx: &mut TxContext) {
        let coupon = Coupon {
            id: object::new(ctx),
            itemDiscount: itemDiscount,
            discount: discount,
            expirationDate: expirationDate,
            publisher: tx_context::sender(ctx),
        };
        transfer::share_object(coupon);
    }

    public fun create_shared_coupons(currentState: &mut State, itemDiscount: String, discount: u8, expirationDate: u64, quantity: u64, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        if (!is_publisher(currentState, &sender)) {
            abort ENotPublisher
        };
        let i = 0;
        while (i < quantity) {
            create_shared_coupon(itemDiscount, discount, expirationDate, ctx);
            i = i + 1;
        }
    }

    fun create_private_coupon(itemDiscount: String, discount: u8, expirationDate: u64, ctx: &mut TxContext) {
        let coupon = Coupon {
            id: object::new(ctx),
            itemDiscount: itemDiscount,
            discount: discount,
            expirationDate: expirationDate,
            publisher: tx_context::sender(ctx),
        };
        transfer::transfer(coupon, tx_context::sender(ctx));
    }

    public fun create_private_coupons(currentState: &mut State, itemDiscount: String, discount: u8, expirationDate: u64, quantity: u64, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        if (!is_publisher(currentState, &sender)) {
            abort ENotPublisher
        };
        let i = 0;
        while (i < quantity) {
            create_private_coupon(itemDiscount, discount, expirationDate, ctx);
            i = i + 1;
        }
    }

    public fun claim_coupons(coupons: Coupon, ctx: &mut TxContext) {
        transfer::transfer(coupons, tx_context::sender(ctx));
    }

    public fun create_burn_request(currentState: &State, clock: &Clock, coupon: Coupon, seller: &address, ctx: &mut TxContext) {
        if (!is_seller(currentState, seller, &coupon.publisher)) {
            abort ENotSeller
        };
        if (coupon.expirationDate < clock::timestamp_ms(clock)) {
            abort EExpiredCoupon
        };
        let burnRequest = BurnRequest {
            id: object::new(ctx),
            coupon: coupon,
            owner: tx_context::sender(ctx),
            seller: *seller,
        };
        transfer::share_object(burnRequest);
    }

    public fun confirm_burn_request(burnRequest: BurnRequest, ctx: &mut TxContext) {
        let BurnRequest { id: burnRequestId, coupon, owner, seller } = burnRequest;
        if (tx_context::sender(ctx) != seller) {
            abort ENotInvalidSeller
        };
        let Coupon { id: couponID, itemDiscount, discount, expirationDate, publisher } = coupon;
        object::delete(couponID);
        object::delete(burnRequestId);
    }

    public fun cancel_burn_request(burnRequest: BurnRequest, ctx: &mut TxContext) {
        let BurnRequest { id: burnRequestId, coupon, owner, seller } = burnRequest;
        if (tx_context::sender(ctx) != owner) {
            abort ENotCouponOwner
        };
        object::delete(burnRequestId);
        transfer::transfer(coupon, owner);
    }

    // =========================== Transfer Policy ===========================

    public fun create_transfer_policy(pub: &Publisher, ctx: &mut TxContext) {
        let (policy, policy_cap) = transfer_policy::new<Coupon>(pub, ctx);
        transfer::public_share_object(policy);
        transfer::public_transfer(policy_cap, tx_context::sender(ctx));
    }

    public fun buy_coupon(kiosk: &mut Kiosk, id: ID, payment: Coin<SUI>): (Coupon, TransferRequest<Coupon>) {
        let (inner, request) = kiosk::purchase<Coupon>(kiosk, id, payment);
        (inner, request)        
    }

    public fun confirm_transfer_request(
        policy: &TransferPolicy<Coupon>, 
        request: TransferRequest<Coupon>, 
    ) {
        transfer_policy::confirm_request<Coupon>(policy, request);
    }


    // =========================== Init ===========================

    fun init(_: COUPONS, ctx: &mut TxContext) {
        let adminCap = AdminCap { id: object::new(ctx) };
        transfer::public_transfer(adminCap, tx_context::sender(ctx));

        let emptyVec = vector::empty<address>();
        let emptyTable = table::new<address, vector<address>>(ctx);
        let state = State {
            id: object::new(ctx),
            publisherList: emptyVec,
            sellerList: emptyTable,
        };
        transfer::share_object(state);

        let pub = package::claim(_, ctx);
        transfer::public_transfer(pub, tx_context::sender(ctx));
    }
}