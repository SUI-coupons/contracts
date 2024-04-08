#[test_only]
module digital_coupons::test_coupons {
    use sui::test_scenario::{Self};
    use digital_coupons::coupons::{Self, AdminCap, State, Coupon};
    use sui::clock::{Self, Clock};
    use sui::object::{Self};

    #[test]
    fun test_register() {
        let alice = @0xabc;
        let bob = @0xdef;
        let charlie = @0x123;

        let scenario = test_scenario::begin(alice);
        let scenario_mut = &mut scenario;
        coupons::init_for_testing(test_scenario::ctx(scenario_mut));

        test_scenario::next_tx(scenario_mut, alice);

        let adminCap = test_scenario::take_from_address<AdminCap>(scenario_mut, alice);
        let currentState = test_scenario::take_shared<State>(scenario_mut);

        assert!(coupons::is_publisher(&currentState, &alice) == false, 0);
        coupons::register_publisher(&mut adminCap, &mut currentState, alice);
        assert!(coupons::is_publisher(&currentState, &alice) == true, 0);
        
        assert!(coupons::is_publisher(&currentState, &bob) == false, 0);
        coupons::register_publisher(&mut adminCap, &mut currentState, bob);
        assert!(coupons::is_publisher(&currentState, &bob) == true, 0);

        test_scenario::return_to_address<AdminCap>(alice, adminCap);
        test_scenario::return_shared<State>(currentState);
        test_scenario::end(scenario);
    }  

    #[test]
    fun test_burn() {
        let alice = @0xabc;
        let bob = @0xdef;
        let charlie = @0x123;

        let scenario = test_scenario::begin(alice);
        let scenario_mut = &mut scenario;
        coupons::init_for_testing(test_scenario::ctx(scenario_mut));

        test_scenario::next_tx(scenario_mut, alice);
        let adminCap = test_scenario::take_from_address<AdminCap>(scenario_mut, alice);
        let currentState = test_scenario::take_shared<State>(scenario_mut);
        coupons::register_publisher(&mut adminCap, &mut currentState, alice);
        coupons::register_publisher(&mut adminCap, &mut currentState, bob);

        // test_scenario::next_tx(scenario_mut, alice);
        // coupons::create_shared_coupons(
        //     &mut currentState, 
        //     b"household", 
        //     5,
        //     4141499349343,
        //     1, 
        //     test_scenario::ctx(scenario_mut));    

        // test_scenario::next_tx(scenario_mut, charlie);
        // let coupon = test_scenario::take_shared<Coupon>(scenario_mut);
        // coupons::claim_coupons(coupon,test_scenario::ctx(scenario_mut));
        // let clock = test_scenario::take_shared_by_id<Clock>(scenario_mut, object::clock());


        test_scenario::return_to_address<AdminCap>(alice, adminCap);
        test_scenario::return_shared<State>(currentState);
        test_scenario::end(scenario);
    } 
}