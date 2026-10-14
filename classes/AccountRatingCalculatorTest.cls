/**
 * @description Unit tests for AccountRatingCalculator.
 *              Validates all rating scenarios, edge cases, bulk operations,
 *              and the @InvocableMethod Flow integration entry point.
 *
 * @author      Copado Build Agent
 * @date        2026-10-14
 */
@isTest
private class AccountRatingCalculatorTest {

    // ─── Test Data Constants ──────────────────────────────────────────────────
    private static final String RATING_HOT  = 'Hot';
    private static final String RATING_WARM = 'Warm';
    private static final String RATING_COLD = 'Cold';

    // ─── Helper: build an Account without inserting ───────────────────────────
    private static Account buildAccount(String name, Decimal revenue, Integer employees) {
        return new Account(
            Name              = name,
            AnnualRevenue     = revenue,
            NumberOfEmployees = employees
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Rating: Hot
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description An account with high revenue (>=10M), many employees (>=1000),
     *              and 5+ opportunities should score 9 points and receive a Hot rating.
     */
    @isTest
    static void testHotRating_highRevenueHighEmployeesHighOpps() {
        Account acc = buildAccount('Hot Account', 15000000, 1500);
        insert acc;

        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 5; i++) {
            opps.add(new Opportunity(
                Name      = 'Opp ' + i,
                AccountId = acc.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            ));
        }
        insert opps;

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Account>{ acc });
        Test.stopTest();

        System.assertEquals(RATING_HOT, acc.Rating, 'Account with high revenue, employees, and 5 opps should be Hot.');
    }

    /**
     * @description An account scoring exactly 8 points should receive a Hot rating
     *              (boundary condition above the Hot threshold of 7).
     */
    @isTest
    static void testHotRating_exactThreshold() {
        // Revenue >= 10M (3pts) + Employees >= 1000 (3pts) + 2 opps (2pts) = 8 pts => Hot
        Account acc = buildAccount('Threshold Hot Account', 10000000, 1000);
        insert acc;

        List<Opportunity> opps = new List<Opportunity>{
            new Opportunity(Name = 'Opp A', AccountId = acc.Id, StageName = 'Prospecting', CloseDate = Date.today().addDays(10)),
            new Opportunity(Name = 'Opp B', AccountId = acc.Id, StageName = 'Prospecting', CloseDate = Date.today().addDays(10))
        };
        insert opps;

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Account>{ acc });
        Test.stopTest();

        System.assertEquals(RATING_HOT, acc.Rating, 'Account scoring 8 points should be Hot.');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Rating: Warm
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description An account with medium revenue (>=1M), medium employees (>=100),
     *              and no opportunities should score 5 points and receive a Warm rating.
     */
    @isTest
    static void testWarmRating_mediumRevenueMediumEmployeesNoOpps() {
        Account acc = buildAccount('Warm Account', 5000000, 200);
        insert acc;

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Account>{ acc });
        Test.stopTest();

        System.assertEquals(RATING_WARM, acc.Rating, 'Account with medium revenue and employees and no opps should be Warm.');
    }

    /**
     * @description An account scoring exactly 5 points should receive a Warm rating
     *              (boundary condition above the Warm threshold of 4).
     */
    @isTest
    static void testWarmRating_exactThreshold() {
        // Revenue < 1M (1pt) + Employees >= 1000 (3pts) + 0 opps (1pt) = 5 pts => Warm
        Account acc = buildAccount('Threshold Warm Account', 500000, 1000);
        insert acc;

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Account>{ acc });
        Test.stopTest();

        System.assertEquals(RATING_WARM, acc.Rating, 'Account scoring 5 points should be Warm.');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Rating: Cold
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description An account with low revenue, few employees, and no opportunities
     *              should score 3 points and receive a Cold rating.
     */
    @isTest
    static void testColdRating_lowRevenueLowEmployeesNoOpps() {
        Account acc = buildAccount('Cold Account', 50000, 10);
        insert acc;

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Account>{ acc });
        Test.stopTest();

        System.assertEquals(RATING_COLD, acc.Rating, 'Account with low revenue, employees, and no opps should be Cold.');
    }

    /**
     * @description An account with null revenue and null employees and no opportunities
     *              should score 3 points and receive a Cold rating.
     */
    @isTest
    static void testColdRating_nullRevenueNullEmployees() {
        Account acc = buildAccount('Null Fields Account', null, null);
        insert acc;

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Account>{ acc });
        Test.stopTest();

        System.assertEquals(RATING_COLD, acc.Rating, 'Account with null revenue and employees should be Cold.');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Edge Cases
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Passing an empty list should not throw an exception.
     */
    @isTest
    static void testEmptyList_noException() {
        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Account>());
        Test.stopTest();

        System.assert(true, 'Empty list should be handled gracefully without exception.');
    }

    /**
     * @description Passing a null list should not throw an exception.
     */
    @isTest
    static void testNullList_noException() {
        Test.startTest();
        AccountRatingCalculator.calculateRatings(null);
        Test.stopTest();

        System.assert(true, 'Null list should be handled gracefully without exception.');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Bulk Operations
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Validates that 200 accounts are rated correctly in a single
     *              bulk operation without hitting governor limits.
     */
    @isTest
    static void testBulkRating_200Accounts() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(buildAccount('Bulk Account ' + i, 15000000, 1500));
        }
        insert accounts;

        Test.startTest();
        AccountRatingCalculator.calculateRatings(accounts);
        Test.stopTest();

        for (Account acc : accounts) {
            System.assertEquals(RATING_HOT, acc.Rating, 'All bulk accounts with high revenue and employees should be Hot.');
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private Method Unit Tests (via @TestVisible)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Validates scoreRevenue returns correct points for each band.
     */
    @isTest
    static void testScoreRevenue_allBands() {
        System.assertEquals(3, AccountRatingCalculator.scoreRevenue(10000000), 'Revenue >= 10M should score 3.');
        System.assertEquals(2, AccountRatingCalculator.scoreRevenue(1000000),  'Revenue >= 1M should score 2.');
        System.assertEquals(1, AccountRatingCalculator.scoreRevenue(500000),   'Revenue < 1M should score 1.');
        System.assertEquals(1, AccountRatingCalculator.scoreRevenue(null),     'Null revenue should score 1.');
    }

    /**
     * @description Validates scoreEmployees returns correct points for each band.
     */
    @isTest
    static void testScoreEmployees_allBands() {
        System.assertEquals(3, AccountRatingCalculator.scoreEmployees(1000), 'Employees >= 1000 should score 3.');
        System.assertEquals(2, AccountRatingCalculator.scoreEmployees(100),  'Employees >= 100 should score 2.');
        System.assertEquals(1, AccountRatingCalculator.scoreEmployees(50),   'Employees < 100 should score 1.');
        System.assertEquals(1, AccountRatingCalculator.scoreEmployees(null), 'Null employees should score 1.');
    }

    /**
     * @description Validates scoreOpportunities returns correct points for each band.
     */
    @isTest
    static void testScoreOpportunities_allBands() {
        System.assertEquals(3, AccountRatingCalculator.scoreOpportunities(5),    'Opps >= 5 should score 3.');
        System.assertEquals(2, AccountRatingCalculator.scoreOpportunities(2),    'Opps >= 2 should score 2.');
        System.assertEquals(1, AccountRatingCalculator.scoreOpportunities(1),    'Opps = 1 should score 1.');
        System.assertEquals(1, AccountRatingCalculator.scoreOpportunities(0),    'Opps = 0 should score 1.');
        System.assertEquals(1, AccountRatingCalculator.scoreOpportunities(null), 'Null opps should score 1.');
    }

    /**
     * @description Validates deriveRating returns correct rating for each score band.
     */
    @isTest
    static void testDeriveRating_allBands() {
        System.assertEquals(RATING_HOT,  AccountRatingCalculator.deriveRating(9), 'Score 9 should be Hot.');
        System.assertEquals(RATING_HOT,  AccountRatingCalculator.deriveRating(7), 'Score 7 should be Hot.');
        System.assertEquals(RATING_WARM, AccountRatingCalculator.deriveRating(6), 'Score 6 should be Warm.');
        System.assertEquals(RATING_WARM, AccountRatingCalculator.deriveRating(4), 'Score 4 should be Warm.');
        System.assertEquals(RATING_COLD, AccountRatingCalculator.deriveRating(3), 'Score 3 should be Cold.');
        System.assertEquals(RATING_COLD, AccountRatingCalculator.deriveRating(0), 'Score 0 should be Cold.');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Flow Integration Test
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Validates the @InvocableMethod entry point used by the Flow.
     *              Inserts an account with high revenue and employees, then calls
     *              the invocable method directly to verify the rating is persisted.
     */
    @isTest
    static void testInvocableMethod_hotRating() {
        Account acc = buildAccount('Invocable Hot Account', 15000000, 1500);
        insert acc;

        Test.startTest();
        AccountRatingCalculator.calculateRatingsInvocable(new List<Id>{ acc.Id });
        Test.stopTest();

        Account updated = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals(RATING_HOT, updated.Rating, 'Invocable method should set Hot rating for qualifying account.');
    }

    /**
     * @description Validates the @InvocableMethod handles an empty Id list gracefully.
     */
    @isTest
    static void testInvocableMethod_emptyList_noException() {
        Test.startTest();
        AccountRatingCalculator.calculateRatingsInvocable(new List<Id>());
        Test.stopTest();

        System.assert(true, 'Empty Id list should be handled gracefully without exception.');
    }

    /**
     * @description Validates the @InvocableMethod handles a null Id list gracefully.
     */
    @isTest
    static void testInvocableMethod_nullList_noException() {
        Test.startTest();
        AccountRatingCalculator.calculateRatingsInvocable(null);
        Test.stopTest();

        System.assert(true, 'Null Id list should be handled gracefully without exception.');
    }
}