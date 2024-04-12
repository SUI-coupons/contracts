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
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
    use sui::dynamic_object_field::{Self};

    const EAlreadyPublisher: u64 = 0;
    const ENotPublisher: u64 = 1;
    const ENotSeller: u64 = 2;
    const ENotInvalidSeller: u64 = 3;
    const ENotCouponOwner: u64 = 4;
    const EExpiredCoupon: u64 = 5;
    const EAlreadySeller: u64 = 6;
    const EDiscountInvalid: u64 = 7;
    const ECouponNotListed: u64 = 8;

    struct COUPONS has drop {} 

    struct Coupon has key, store {
        id: UID,
        brandName: String, // brand name
        itemDiscount: String, // fashion or household items
        discount: u8, // maximum 200
        expirationDate: u64, // unix timestamp
        publisher: address, // publisher address of the coupon
        imageURI: String, // image URI of the coupon
    }

    struct AdminCap has key, store {
        id: UID,
    }

    struct State has key {
        id: UID,
        publisherList: vector<address>,
        sellerList: Table<address, vector<address>>,
        availableCoupons: vector<address>,
        listedCoupons: vector<address>,
        listedPrice: vector<u64>,
        listedOwner: vector<address>,
        listedKiosk: vector<address>,
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
        if (is_seller(currentState, &seller, &sender)) {
            abort EAlreadySeller
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

    fun create_shared_coupon(currentState: &mut State, brandName: String, itemDiscount: String, discount: u8, expirationDate: u64, imageURI: String, ctx: &mut TxContext) {
        let coupon = Coupon {
            id: object::new(ctx),
            brandName: brandName,
            itemDiscount: itemDiscount,
            discount: discount,
            expirationDate: expirationDate,
            imageURI: imageURI,
            publisher: tx_context::sender(ctx),
        };
        let coupon_address = object::uid_to_address(&coupon.id);
        vector::push_back(&mut currentState.availableCoupons, coupon_address);
        transfer::share_object(coupon);
    }

    public fun create_shared_coupons(currentState: &mut State, brandName: String, itemDiscount: String, discount: u8, expirationDate: u64, imageURI: String, quantity: u64, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        if (!is_publisher(currentState, &sender)) {
            abort ENotPublisher
        };
        assert!(discount % 5 == 0, EDiscountInvalid);
        let i = 0;
        while (i < quantity) {
            create_shared_coupon(currentState, brandName, itemDiscount, discount, expirationDate, imageURI, ctx);
            i = i + 1;
        }
    }

    fun create_private_coupon(brandName: String, itemDiscount: String, discount: u8, expirationDate: u64, imageURI: String, ctx: &mut TxContext) {
        let coupon = Coupon {
            id: object::new(ctx),
            brandName,
            itemDiscount: itemDiscount,
            discount: discount,
            expirationDate: expirationDate,
            imageURI: imageURI,
            publisher: tx_context::sender(ctx),
        };
        transfer::transfer(coupon, tx_context::sender(ctx));
    }

    public fun create_private_coupons(currentState: &mut State, brandName: String, itemDiscount: String, discount: u8, expirationDate: u64, imageURI: String, quantity: u64, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        if (!is_publisher(currentState, &sender)) {
            abort ENotPublisher
        };
        assert!(discount % 5 == 0, EDiscountInvalid);
        let i = 0;
        while (i < quantity) {
            create_private_coupon(brandName, itemDiscount, discount, expirationDate, imageURI, ctx);
            i = i + 1;
        }
    }

    public fun claim_coupon(coupon: Coupon, currentState: &mut State, ctx: &mut TxContext) {
        let Coupon { id, brandName, itemDiscount, discount, expirationDate, publisher, imageURI } = coupon;
        let availableCoupons = &mut currentState.availableCoupons;
        let (is_coupon, index) = vector::index_of(availableCoupons, &object::uid_to_address(&id));
        assert!(is_coupon == true, EExpiredCoupon);
        vector::remove(availableCoupons, index);
        object::delete(id);
        let newCoupon = Coupon {
            id: object::new(ctx),
            brandName: brandName,
            itemDiscount: itemDiscount,
            discount: discount,
            expirationDate: expirationDate,
            publisher: publisher,
            imageURI: imageURI,
        };
        transfer::transfer(newCoupon, tx_context::sender(ctx));
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
        let Coupon { id: couponID, brandName, itemDiscount, discount, expirationDate, publisher, imageURI } = coupon;
        object::delete(couponID);
        object::delete(burnRequestId);
    }

    public fun cancel_burn_request(burnRequest: BurnRequest, ctx: &mut TxContext) {
        let BurnRequest { id: burnRequestId, coupon, owner, seller } = burnRequest;
        if (tx_context::sender(ctx) != owner) {
            abort ENotCouponOwner
        };
        object::delete(burnRequestId);
        transfer::transfer(coupon, tx_context::sender(ctx));
    }

    public fun place_and_list_coupon(
        currentState: &mut State,
        kiosk: &mut Kiosk, 
        cap: &KioskOwnerCap, 
        coupon: Coupon,
        price: u64,
        ctx: &mut TxContext
    ) {
        let coupon_address = object::uid_to_address(&coupon.id);
        vector::push_back(&mut currentState.listedCoupons, coupon_address);
        vector::push_back(&mut currentState.listedPrice, price);
        vector::push_back(&mut currentState.listedOwner, tx_context::sender(ctx));
        vector::push_back(&mut currentState.listedKiosk, object::id_address(kiosk));
        kiosk::place_and_list<Coupon>(kiosk, cap, coupon, price);
    }

    // do not call it from outside of package
    public fun remove_state_coupon(currentState: &mut State, id: &ID) {
        let coupon_address = object::id_to_address(id);
        let (is_coupon, index) = vector::index_of(&currentState.listedCoupons, &coupon_address);
        if (!is_coupon) {
            abort ECouponNotListed
        };
        vector::remove(&mut currentState.listedCoupons, index);
        vector::remove(&mut currentState.listedPrice, index);
        vector::remove(&mut currentState.listedOwner, index);
        vector::remove(&mut currentState.listedKiosk, index);
    }

    public fun delist_and_take_coupon(
        currentState: &mut State,
        kiosk: &mut Kiosk, 
        cap: &KioskOwnerCap, 
        id: ID,
        ctx: &mut TxContext
    ) {
        remove_state_coupon(currentState, &id);
        kiosk::delist<Coupon>(kiosk, cap, id);
        let coupon = kiosk::take<Coupon>(kiosk, cap, id);
        transfer::transfer(coupon, tx_context::sender(ctx));
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
            availableCoupons: vector::empty<address>(),
            listedCoupons: vector::empty<address>(),
            listedPrice: vector::empty<u64>(),
            listedOwner: vector::empty<address>(),
            listedKiosk: vector::empty<address>()
        };
        transfer::share_object(state);

        let pub = package::claim(_, ctx);
        transfer::public_transfer(pub, tx_context::sender(ctx));
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(COUPONS {}, ctx);
    }
}