/**
 * @description Comprehensive test coverage for AccountRatingCalculator.
 *              Covers all rating scenarios, edge cases, bulk operations,
 *              and Flow invocable integration.
 */
@IsTest
private class AccountRatingCalculatorTest {

    // -------------------------------------------------------------------------
    // Test data setup
    // -------------------------------------------------------------------------

    /**
     * @description Creates a basic Account with the given revenue and employee count.
     * @param name Account name.
     * @param revenue AnnualRevenue.
     * @param employees NumberOfEmployees.
     * @return Inserted Account record.
     */
    private static Account createAccount(String name, Decimal revenue, Integer employees) {
        Account acc = new Account(
            Name = name,
            AnnualRevenue = revenue,
            NumberOfEmployees = employees
        );
        insert acc;
        return acc;
    }

    /**
     * @description Creates a Closed Won opportunity linked to the given Account.
     * @param accountId Parent Account Id.
     */
    private static void createClosedWonOpp(Id accountId) {
        insert new Opportunity(
            Name = 'Test Opp',
            AccountId = accountId,
            StageName = 'Closed Won',
            CloseDate = Date.today()
        );
    }

    // -------------------------------------------------------------------------
    // Rating scenario tests
    // -------------------------------------------------------------------------

    @IsTest
    static void testHotRating_highRevenueHighEmployees() {
        // Revenue >= 1,000,000 (4 pts) + Employees >= 1,000 (3 pts) = 7 => Hot
        Account acc = createAccount('Hot Account', 1500000, 1200);

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Hot', result.Rating, 'Account with high revenue and high employees should be rated Hot.');
    }

    @IsTest
    static void testHotRating_withOpportunities() {
        // Revenue >= 500,000 (2 pts) + Employees >= 200 (2 pts) + 3 opps (3 pts) = 7 => Hot
        Account acc = createAccount('Hot Opp Account', 600000, 250);
        createClosedWonOpp(acc.Id);
        createClosedWonOpp(acc.Id);
        createClosedWonOpp(acc.Id);

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Hot', result.Rating, 'Account with medium revenue, medium employees, and 3+ opps should be rated Hot.');
    }

    @IsTest
    static void testWarmRating_mediumRevenueMediumEmployees() {
        // Revenue >= 500,000 (2 pts) + Employees >= 200 (2 pts) = 4 => Warm
        Account acc = createAccount('Warm Account', 600000, 250);

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Warm', result.Rating, 'Account with medium revenue and medium employees should be rated Warm.');
    }

    @IsTest
    static void testWarmRating_lowRevenueWithOpportunity() {
        // Revenue >= 100,000 (1 pt) + Employees >= 1,000 (3 pts) = 4 => Warm
        Account acc = createAccount('Warm Opp Account', 150000, 1100);

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Warm', result.Rating, 'Account with low revenue and high employees should be rated Warm.');
    }

    @IsTest
    static void testColdRating_lowRevenueNoEmployees() {
        // Revenue >= 100,000 (1 pt) + no employees (0 pts) = 1 => Cold
        Account acc = createAccount('Cold Account', 150000, null);

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Cold', result.Rating, 'Account with low revenue and no employees should be rated Cold.');
    }

    @IsTest
    static void testColdRating_noRevenueNoEmployees() {
        // 0 pts => Cold
        Account acc = createAccount('Zero Account', null, null);

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Cold', result.Rating, 'Account with no revenue and no employees should be rated Cold.');
    }

    // -------------------------------------------------------------------------
    // Edge case tests
    // -------------------------------------------------------------------------

    @IsTest
    static void testNullAccountIdList() {
        // Should complete without exception
        Test.startTest();
        AccountRatingCalculator.calculateRatings(null);
        Test.stopTest();

        System.assert(true, 'Null input should not throw an exception.');
    }

    @IsTest
    static void testEmptyAccountIdList() {
        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Id>());
        Test.stopTest();

        System.assert(true, 'Empty list input should not throw an exception.');
    }

    @IsTest
    static void testNoRatingUpdateWhenUnchanged() {
        // Pre-set rating to Cold, then call with data that also yields Cold
        Account acc = new Account(Name = 'No Change Account', AnnualRevenue = 50000, NumberOfEmployees = 10, Rating = 'Cold');
        insert acc;

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Cold', result.Rating, 'Rating should remain Cold when score does not change.');
    }

    @IsTest
    static void testExactBoundaryHot() {
        // Exactly 7 points: Revenue >= 1,000,000 (4 pts) + Employees >= 200 (2 pts) + 1 opp (1 pt) = 7 => Hot
        Account acc = createAccount('Boundary Hot', 1000000, 200);
        createClosedWonOpp(acc.Id);

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Hot', result.Rating, 'Account at exactly 7 points should be rated Hot.');
    }

    @IsTest
    static void testExactBoundaryWarm() {
        // Exactly 4 points: Revenue >= 500,000 (2 pts) + Employees >= 50 (1 pt) + 1 opp (1 pt) = 4 => Warm
        Account acc = createAccount('Boundary Warm', 500000, 75);
        createClosedWonOpp(acc.Id);

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Warm', result.Rating, 'Account at exactly 4 points should be rated Warm.');
    }

    // -------------------------------------------------------------------------
    // Bulk operation test
    // -------------------------------------------------------------------------

    @IsTest
    static void testBulkRatingCalculation() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(
                Name = 'Bulk Account ' + i,
                AnnualRevenue = (Math.mod(i, 3) == 0) ? 1500000 : (Math.mod(i, 3) == 1 ? 600000 : 50000),
                NumberOfEmployees = (Math.mod(i, 3) == 0) ? 1200 : (Math.mod(i, 3) == 1 ? 250 : 10)
            ));
        }
        insert accounts;

        List<Id> accountIds = new List<Id>();
        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }

        Test.startTest();
        AccountRatingCalculator.calculateRatings(accountIds);
        Test.stopTest();

        List<Account> results = [SELECT Rating FROM Account WHERE Id IN :accountIds];
        System.assertEquals(200, results.size(), 'All 200 accounts should be processed.');
        for (Account result : results) {
            System.assertNotEquals(null, result.Rating, 'Every account should have a rating assigned after bulk processing.');
        }
    }

    // -------------------------------------------------------------------------
    // Flow invocable integration test
    // -------------------------------------------------------------------------

    @IsTest
    static void testInvocableMethodIntegration() {
        // Revenue >= 1,000,000 (4 pts) + Employees >= 1,000 (3 pts) = 7 => Hot
        Account acc = createAccount('Flow Integration Account', 1200000, 1500);

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Hot', result.Rating, 'Flow invocable integration should correctly assign Hot rating.');
    }

    // -------------------------------------------------------------------------
    // computeRating unit tests (via @TestVisible)
    // -------------------------------------------------------------------------

    @IsTest
    static void testComputeRating_directHot() {
        Account acc = new Account(AnnualRevenue = 2000000, NumberOfEmployees = 1500);
        String rating = AccountRatingCalculator.computeRating(acc, 5);
        System.assertEquals('Hot', rating, 'computeRating should return Hot for high revenue, high employees, and 5 opps.');
    }

    @IsTest
    static void testComputeRating_directWarm() {
        Account acc = new Account(AnnualRevenue = 600000, NumberOfEmployees = 250);
        String rating = AccountRatingCalculator.computeRating(acc, 0);
        System.assertEquals('Warm', rating, 'computeRating should return Warm for medium revenue and medium employees.');
    }

    @IsTest
    static void testComputeRating_directCold() {
        Account acc = new Account(AnnualRevenue = null, NumberOfEmployees = null);
        String rating = AccountRatingCalculator.computeRating(acc, 0);
        System.assertEquals('Cold', rating, 'computeRating should return Cold for null revenue and null employees.');
    }
}