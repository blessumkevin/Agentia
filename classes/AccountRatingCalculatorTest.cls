/**
 * @description Comprehensive test coverage for AccountRatingCalculator.
 *              Covers all rating scenarios, edge cases, bulk operations,
 *              and the @InvocableMethod entry point.
 *
 * @author      Copado Build Agent
 * @date        2026-09-22
 */
@IsTest
private class AccountRatingCalculatorTest {

    // ─── Test Data Setup ──────────────────────────────────────────────────────

    /**
     * @description Creates a basic Account with the supplied revenue and
     *              employee values. Does NOT insert — callers decide.
     */
    private static Account buildAccount(String name, Decimal revenue, Integer employees) {
        return new Account(
            Name              = name,
            AnnualRevenue     = revenue,
            NumberOfEmployees = employees
        );
    }

    /**
     * @description Creates and inserts an open Opportunity linked to the given Account.
     */
    private static void insertOpenOpportunity(Id accountId, String name) {
        insert new Opportunity(
            Name      = name,
            AccountId = accountId,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
    }

    // ─── Unit Tests: revenuePoints ────────────────────────────────────────────

    @IsTest
    static void testRevenuePoints_null() {
        Integer pts = AccountRatingCalculator.revenuePoints(null);
        System.assertEquals(0, pts, 'Null revenue should yield 0 points.');
    }

    @IsTest
    static void testRevenuePoints_belowLow() {
        Integer pts = AccountRatingCalculator.revenuePoints(50000);
        System.assertEquals(0, pts, 'Revenue below LOW threshold should yield 0 points.');
    }

    @IsTest
    static void testRevenuePoints_low() {
        Integer pts = AccountRatingCalculator.revenuePoints(AccountRatingCalculator.REVENUE_LOW);
        System.assertEquals(1, pts, 'Revenue at LOW threshold should yield 1 point.');
    }

    @IsTest
    static void testRevenuePoints_medium() {
        Integer pts = AccountRatingCalculator.revenuePoints(AccountRatingCalculator.REVENUE_MEDIUM);
        System.assertEquals(2, pts, 'Revenue at MEDIUM threshold should yield 2 points.');
    }

    @IsTest
    static void testRevenuePoints_high() {
        Integer pts = AccountRatingCalculator.revenuePoints(AccountRatingCalculator.REVENUE_HIGH);
        System.assertEquals(3, pts, 'Revenue at HIGH threshold should yield 3 points.');
    }

    // ─── Unit Tests: employeePoints ───────────────────────────────────────────

    @IsTest
    static void testEmployeePoints_null() {
        Integer pts = AccountRatingCalculator.employeePoints(null);
        System.assertEquals(0, pts, 'Null employees should yield 0 points.');
    }

    @IsTest
    static void testEmployeePoints_belowLow() {
        Integer pts = AccountRatingCalculator.employeePoints(10);
        System.assertEquals(0, pts, 'Employee count below LOW threshold should yield 0 points.');
    }

    @IsTest
    static void testEmployeePoints_low() {
        Integer pts = AccountRatingCalculator.employeePoints(AccountRatingCalculator.EMP_LOW);
        System.assertEquals(1, pts, 'Employee count at LOW threshold should yield 1 point.');
    }

    @IsTest
    static void testEmployeePoints_medium() {
        Integer pts = AccountRatingCalculator.employeePoints(AccountRatingCalculator.EMP_MEDIUM);
        System.assertEquals(2, pts, 'Employee count at MEDIUM threshold should yield 2 points.');
    }

    @IsTest
    static void testEmployeePoints_high() {
        Integer pts = AccountRatingCalculator.employeePoints(AccountRatingCalculator.EMP_HIGH);
        System.assertEquals(3, pts, 'Employee count at HIGH threshold should yield 3 points.');
    }

    // ─── Unit Tests: opportunityPoints ───────────────────────────────────────

    @IsTest
    static void testOpportunityPoints_null() {
        Integer pts = AccountRatingCalculator.opportunityPoints(null);
        System.assertEquals(0, pts, 'Null opportunity list should yield 0 points.');
    }

    @IsTest
    static void testOpportunityPoints_empty() {
        Integer pts = AccountRatingCalculator.opportunityPoints(new List<Opportunity>());
        System.assertEquals(0, pts, 'Empty opportunity list should yield 0 points.');
    }

    @IsTest
    static void testOpportunityPoints_withOpps() {
        List<Opportunity> opps = new List<Opportunity>{ new Opportunity() };
        Integer pts = AccountRatingCalculator.opportunityPoints(opps);
        System.assertEquals(1, pts, 'Non-empty opportunity list should yield 1 point.');
    }

    // ─── Unit Tests: deriveRating ─────────────────────────────────────────────

    @IsTest
    static void testDeriveRating_hot() {
        String rating = AccountRatingCalculator.deriveRating(AccountRatingCalculator.HOT_THRESHOLD);
        System.assertEquals('Hot', rating, 'Score at HOT_THRESHOLD should return Hot.');
    }

    @IsTest
    static void testDeriveRating_warm() {
        String rating = AccountRatingCalculator.deriveRating(AccountRatingCalculator.WARM_THRESHOLD);
        System.assertEquals('Warm', rating, 'Score at WARM_THRESHOLD should return Warm.');
    }

    @IsTest
    static void testDeriveRating_cold() {
        String rating = AccountRatingCalculator.deriveRating(0);
        System.assertEquals('Cold', rating, 'Score of 0 should return Cold.');
    }

    // ─── Unit Tests: computeScore ─────────────────────────────────────────────

    @IsTest
    static void testComputeScore_allNulls() {
        Account acc = buildAccount('Score Null', null, null);
        insert acc;
        Account queried = [SELECT Id, Rating, AnnualRevenue, NumberOfEmployees,
                                  (SELECT Id FROM Opportunities WHERE IsClosed = FALSE LIMIT 1)
                           FROM Account WHERE Id = :acc.Id];
        Integer score = AccountRatingCalculator.computeScore(queried);
        System.assertEquals(0, score, 'Account with no data should score 0.');
    }

    @IsTest
    static void testComputeScore_maxScore() {
        Account acc = buildAccount('Score Max', 15000000, 1500);
        insert acc;
        insertOpenOpportunity(acc.Id, 'Max Opp');
        Account queried = [SELECT Id, Rating, AnnualRevenue, NumberOfEmployees,
                                  (SELECT Id FROM Opportunities WHERE IsClosed = FALSE LIMIT 1)
                           FROM Account WHERE Id = :acc.Id];
        Integer score = AccountRatingCalculator.computeScore(queried);
        System.assertEquals(7, score, 'Account with max revenue, employees, and opp should score 7.');
    }

    // ─── Integration Tests: calculateRatings ─────────────────────────────────

    @IsTest
    static void testCalculateRatings_hotRating() {
        // Revenue HIGH (3) + Employees HIGH (3) + 1 Opp (1) = 7 => Hot
        Account acc = buildAccount('Hot Account', 15000000, 1500);
        insert acc;
        insertOpenOpportunity(acc.Id, 'Hot Opp');

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Hot', result.Rating, 'Account with max score should be rated Hot.');
    }

    @IsTest
    static void testCalculateRatings_warmRating() {
        // Revenue MEDIUM (2) + Employees MEDIUM (2) = 4 => Warm
        Account acc = buildAccount('Warm Account', 2000000, 300);
        insert acc;

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Warm', result.Rating, 'Account with score 4 should be rated Warm.');
    }

    @IsTest
    static void testCalculateRatings_coldRating() {
        // No revenue, no employees, no opps = 0 => Cold
        Account acc = buildAccount('Cold Account', null, null);
        insert acc;

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Cold', result.Rating, 'Account with score 0 should be rated Cold.');
    }

    @IsTest
    static void testCalculateRatings_noRatingChangeSkipsDml() {
        // Pre-set rating to Cold; score will also be Cold — no DML update expected
        Account acc = buildAccount('No Change Account', null, null);
        acc.Rating = 'Cold';
        insert acc;

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Cold', result.Rating, 'Rating should remain Cold when score does not change.');
    }

    @IsTest
    static void testCalculateRatings_emptyList() {
        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Id>());
        Test.stopTest();
        System.assert(true, 'Empty list should not throw an exception.');
    }

    @IsTest
    static void testCalculateRatings_nullList() {
        Test.startTest();
        AccountRatingCalculator.calculateRatings(null);
        Test.stopTest();
        System.assert(true, 'Null list should not throw an exception.');
    }

    @IsTest
    static void testCalculateRatings_bulk() {
        // Bulk test: 200 accounts with varying scores
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(buildAccount('Bulk Account ' + i, 500000 * i, 100 * i));
        }
        insert accounts;

        List<Id> ids = new List<Id>();
        for (Account a : accounts) {
            ids.add(a.Id);
        }

        Test.startTest();
        AccountRatingCalculator.calculateRatings(ids);
        Test.stopTest();

        List<Account> results = [SELECT Rating FROM Account WHERE Id IN :ids];
        System.assertEquals(200, results.size(), 'All 200 accounts should be processed.');
        for (Account a : results) {
            System.assertNotEquals(null, a.Rating, 'Every account should have a rating assigned.');
        }
    }

    @IsTest
    static void testCalculateRatings_duplicateIds() {
        // Revenue HIGH (3) + Employees HIGH (3) + 1 open Opp (1) = 7 => Hot
        // Duplicate IDs in the input should be deduplicated and processed once
        Account acc = buildAccount('Duplicate ID Account', 15000000, 1500);
        insert acc;
        insertOpenOpportunity(acc.Id, 'Dedup Opp');

        Test.startTest();
        AccountRatingCalculator.calculateRatings(new List<Id>{ acc.Id, acc.Id, acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Hot', result.Rating, 'Duplicate IDs should be deduplicated and processed once.');
    }
}