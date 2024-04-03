module digital_coupons::test_coupons {

    use digital_coupons::coupons;
    use sui::test_scenario;
    use sui::tx_context;

    #[test]
    fun test_register_publisher() {
        let admin = @0xBABE;
        let publisher = @0x1234;
        let scenario = test_scenario::begin(admin);
        let scenario_mut = &mut scenario;  

        coupons::init_for_testing(test_scenario::ctx(scenario_mut));

        test_scenario::next_tx(scenario_mut, admin);
        let adminCap = test_scenario::take_from_sender<coupons::AdminCap>(scenario_mut);

        test_scenario::next_tx(scenario_mut, publisher);
        coupons::register_publisher(adminCap, test_scenario::ctx(scenario_mut));

        test_scenario::next_tx(scenario_mut, publisher);
        let publisherCap = test_scenario::take_from_sender<coupons::PublisherCap>(scenario_mut);

        test_scenario::return_to_sender()
        test_scenario::return_to_sender(scenario_mut, adminCap);
        test_scenario::end(scenario);
    }
}